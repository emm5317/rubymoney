class RecurringDetector
  FREQUENCY_RANGES = {
    weekly:    { min: 5, max: 9, target: 7 },
    biweekly:  { min: 12, max: 16, target: 14 },
    monthly:   { min: 25, max: 35, target: 30 },
    quarterly: { min: 80, max: 100, target: 91 },
    annual:    { min: 350, max: 380, target: 365 }
  }.freeze

  MIN_OCCURRENCES = 3
  LOOKBACK_MONTHS = 12
  MISSED_GRACE_FACTOR = 1.5
  CANCELLED_FACTOR = 2.5

  def initialize(user)
    @user = user
  end

  def detect_all
    results = { created: 0, updated: 0, missed: 0 }

    @user.accounts.find_each do |account|
      account_results = detect_for_account(account)
      results.merge!(account_results) { |_, a, b| a + b }
    end

    results[:missed] = mark_missed_recurring
    results
  end

  def detect_for_account(account)
    results = { created: 0, updated: 0, missed: 0 }

    candidate_groups(account).each do |normalized_desc, transactions|
      analysis = analyze_group(normalized_desc, transactions)
      next unless analysis

      recurring = RecurringTransaction.find_or_initialize_by(
        account: account,
        description_pattern: normalized_desc
      )

      # Don't overwrite user-dismissed patterns
      next if recurring.persisted? && recurring.user_dismissed?

      was_new = recurring.new_record?

      recurring.assign_attributes(analysis)
      # Preserve user confirmations
      recurring.status = :active if recurring.new_record? || !recurring.user_confirmed?

      if recurring.save
        results[was_new ? :created : :updated] += 1
      end
    end

    results
  end

  private

  def candidate_groups(account)
    Transaction.where(account: account)
      .where.not(normalized_desc: [nil, ""])
      .where("date >= ?", LOOKBACK_MONTHS.months.ago)
      .where(is_transfer: false)
      .select(:normalized_desc, :date, :amount_cents, :category_id)
      .order(:date)
      .group_by(&:normalized_desc)
      .select { |_, txns| txns.size >= MIN_OCCURRENCES }
  end

  def analyze_group(normalized_desc, transactions)
    dates = transactions.map(&:date).sort
    intervals = dates.each_cons(2).map { |a, b| (b - a).to_i }
    return nil if intervals.empty?

    median_interval = median(intervals)
    frequency = classify_frequency(median_interval)
    return nil unless frequency

    confidence = calculate_confidence(intervals, FREQUENCY_RANGES[frequency][:target])
    # Require minimum confidence to avoid false positives
    return nil if confidence < 0.4

    amounts = transactions.map(&:amount_cents)

    {
      title: humanize_description(normalized_desc),
      description_pattern: normalized_desc,
      frequency: frequency,
      average_amount_cents: (amounts.sum.to_f / amounts.size).round,
      last_amount_cents: transactions.last.amount_cents,
      last_seen_date: dates.last,
      next_expected_date: dates.last + median_interval.days,
      confidence: confidence,
      occurrence_count: transactions.size,
      average_interval_days: median_interval,
      amount_variance: standard_deviation(amounts),
      category_id: transactions.last.category_id
    }
  end

  def classify_frequency(median_interval)
    FREQUENCY_RANGES.find { |_, range| median_interval.between?(range[:min], range[:max]) }&.first
  end

  def calculate_confidence(intervals, target)
    return 0.0 if intervals.empty?

    deviations = intervals.map { |i| (i - target).abs.to_f / target }
    avg_deviation = deviations.sum / deviations.size
    (1.0 - avg_deviation).clamp(0.0, 1.0).round(2)
  end

  def mark_missed_recurring
    count = 0

    RecurringTransaction.joins(:account)
      .where(accounts: { user_id: @user.id })
      .where(status: :active)
      .not_dismissed
      .find_each do |recurring|
        next unless recurring.next_expected_date

        days_overdue = (Date.current - recurring.next_expected_date).to_i
        grace_days = (recurring.average_interval_days || 30) * MISSED_GRACE_FACTOR

        if days_overdue > grace_days
          recurring.update!(status: :missed)
          count += 1
        end
      end

    count
  end

  def humanize_description(desc)
    desc.titleize.gsub(/\s+/, " ").strip.truncate(50)
  end

  def median(arr)
    sorted = arr.sort
    mid = sorted.size / 2
    sorted.size.odd? ? sorted[mid] : ((sorted[mid - 1] + sorted[mid]) / 2.0).round
  end

  def standard_deviation(arr)
    return 0.0 if arr.size < 2

    mean = arr.sum.to_f / arr.size
    Math.sqrt(arr.sum { |x| (x - mean)**2 } / (arr.size - 1)).round(2)
  end
end
