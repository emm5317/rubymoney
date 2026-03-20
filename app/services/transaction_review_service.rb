class TransactionReviewService
  Suggestion = Struct.new(
    :signature,
    :rule_pattern,
    :transaction_ids,
    :sample_descriptions,
    :transaction_count,
    :total_amount_cents,
    :latest_date,
    :suggested_category,
    :confidence,
    :reason,
    :create_rule_default,
    keyword_init: true
  ) do
    def suggested?
      suggested_category.present?
    end

    def suggested_category_id
      suggested_category&.id
    end

    def confidence_percent
      (confidence.to_f * 100).round
    end
  end

  Summary = Struct.new(
    :total_transactions,
    :total_groups,
    :suggested_groups,
    :suggested_transactions,
    :rule_ready_groups,
    keyword_init: true
  )

  CATEGORY_RULES = [
    {
      category_name: "Transfers",
      confidence: 0.98,
      reason: "Transfer or card-payment wording",
      patterns: [/CITI CARD ONLINE/i, /ONLINE BANKING/i, /\bTRANSFER\b/i, /\bZELLE\b/i, /\bVENMO\b/i]
    },
    {
      category_name: "Income",
      confidence: 0.95,
      reason: "Payroll or reimbursement wording",
      patterns: [/\bPAYROLL\b/i, /\bSALARY\b/i, /\bDIRECT DEP/i, /\bREIMB/i],
      require_credit_majority: true
    },
    {
      category_name: "Education",
      confidence: 0.93,
      reason: "Student loan or education wording",
      patterns: [/\bSTUDENT LN\b/i, /\bEDUCATION\b/i, /\bTUITION\b/i]
    },
    {
      category_name: "Healthcare",
      confidence: 0.9,
      reason: "Medical provider wording",
      patterns: [/\bMEDICAL\b/i, /\bMED\b/i, /\bHOSPITAL\b/i, /\bCLINIC\b/i, /\bPHARM/i, /DUPAGEMEDGRP/i]
    },
    {
      category_name: "Subscriptions",
      confidence: 0.88,
      reason: "Subscription or streaming merchant",
      patterns: [/\bNETFLIX\b/i, /\bSPOTIFY\b/i, /\bAPPLE\.COM\/BILL\b/i, /\bHULU\b/i, /\bHOME CHEF\b/i]
    },
    {
      category_name: "Dining",
      confidence: 0.86,
      reason: "Restaurant or food-service merchant",
      patterns: [/\bMCDONALD'?S\b/i, /\bPIZZA\b/i, /\bCAFE\b/i, /\bBAR\b/i, /\bDD\/BR\b/i, /\bEATS\b/i, /\bRESTAUR/i]
    },
    {
      category_name: "Groceries",
      confidence: 0.84,
      reason: "Grocery merchant wording",
      patterns: [/\bWHOLE FOODS\b/i, /\bCOSTCO\b/i, /\bTRADER JOE'?S\b/i, /\bALDI\b/i, /\bKROGER\b/i, /\bJEWEL\b/i]
    },
    {
      category_name: "Transport",
      confidence: 0.84,
      reason: "Fuel or local transport merchant",
      patterns: [/\bSHELL\b/i, /\bEXXON\b/i, /\bCHEVRON\b/i, /\bBP\b/i, /\bUBER\b/i, /\bLYFT\b/i, /\bMETRA\b/i, /\bCTA\b/i]
    },
    {
      category_name: "Travel",
      confidence: 0.83,
      reason: "Travel or international purchase wording",
      patterns: [/\bINTERNATIONAL TRANSACTION FEE\b/i, /\bROISSY\b/i, /\bCDG\b/i, /\bAIRPORT\b/i, /\bAIRBNB\b/i, /\bHOTEL\b/i]
    },
    {
      category_name: "Shopping",
      confidence: 0.82,
      reason: "Retail merchant wording",
      patterns: [/\bAMAZON\b/i, /\bAMZN\b/i, /\bETSY\b/i, /\bOLDNAVY\b/i, /\bZARA\b/i, /\bHOBBY-LOBBY\b/i]
    },
    {
      category_name: "Utilities",
      confidence: 0.86,
      reason: "Utility or telecom merchant wording",
      patterns: [/\bCOMED\b/i, /\bVERIZON\b/i, /\bAT&T\b/i, /\bXFINITY\b/i, /\bWATER\b/i, /\bELECTRIC\b/i, /\bINTERNET\b/i]
    },
    {
      category_name: "Insurance",
      confidence: 0.88,
      reason: "Insurance merchant wording",
      patterns: [/\bINSURANCE\b/i, /\bGEICO\b/i, /\bPROGRESSIVE\b/i, /\bSTATE FARM\b/i]
    },
    {
      category_name: "Housing",
      confidence: 0.88,
      reason: "Rent or housing payment wording",
      patterns: [/\bRENT\b/i, /\bMORTGAGE\b/i, /\bHOA\b/i, /\bPROPERTY\b/i]
    },
    {
      category_name: "Entertainment",
      confidence: 0.82,
      reason: "Entertainment merchant wording",
      patterns: [/\bMOVIE\b/i, /\bTHEATER\b/i, /\bSTEAM\b/i, /\bPLAYSTATION\b/i, /\bXBOX\b/i]
    },
    {
      category_name: "Gifts",
      confidence: 0.8,
      reason: "Gift or floral merchant wording",
      patterns: [/\bFLOWERS\b/i, /\bGIFT\b/i]
    }
  ].freeze

  def initialize(user:, scope: nil)
    @user = user
    @scope = scope || Transaction.joins(:account)
      .where(accounts: { user_id: user.id })
      .uncategorized
      .order(date: :desc)
    @categories_by_name = Category.all.index_by { |category| category.name.downcase }
  end

  def suggestions
    @suggestions ||= grouped_transactions.map do |signature, transactions|
      build_suggestion(signature, transactions)
    end.sort_by do |suggestion|
      [
        suggestion.suggested? ? 0 : 1,
        -suggestion.transaction_count,
        -suggestion.confidence.to_f,
        suggestion.signature
      ]
    end
  end

  def summary
    @summary ||= begin
      current_suggestions = suggestions
      Summary.new(
        total_transactions: scoped_transactions.size,
        total_groups: current_suggestions.size,
        suggested_groups: current_suggestions.count(&:suggested?),
        suggested_transactions: current_suggestions.select(&:suggested?).sum(&:transaction_count),
        rule_ready_groups: current_suggestions.count(&:create_rule_default)
      )
    end
  end

  def suggestions_by_signature
    suggestions.index_by(&:signature)
  end

  private

  def scoped_transactions
    @scoped_transactions ||= @scope.to_a
  end

  def grouped_transactions
    scoped_transactions.group_by { |transaction| signature_for(transaction) }
  end

  def build_suggestion(signature, transactions)
    suggested_category, confidence, reason = infer_category(signature, transactions)
    rule_pattern = build_rule_pattern(signature)

    Suggestion.new(
      signature: signature,
      rule_pattern: rule_pattern,
      transaction_ids: transactions.map(&:id),
      sample_descriptions: transactions.map(&:description).uniq.first(3),
      transaction_count: transactions.size,
      total_amount_cents: transactions.sum(&:amount_cents),
      latest_date: transactions.max_by(&:date)&.date,
      suggested_category: suggested_category,
      confidence: confidence,
      reason: reason,
      create_rule_default: suggested_category.present? && transactions.size > 1 && rule_pattern.length >= 4
    )
  end

  def infer_category(signature, transactions)
    haystack = ([signature] + transactions.flat_map { |transaction| [transaction.description, transaction.normalized_desc, transaction.memo] })
      .compact
      .join(" ")
      .upcase

    credit_majority = transactions.count(&:credit?) >= ((transactions.size + 1) / 2.0)

    CATEGORY_RULES.each do |rule|
      category = @categories_by_name[rule[:category_name].downcase]
      next unless category
      next if rule[:require_credit_majority] && !credit_majority
      next unless rule[:patterns].any? { |pattern| haystack.match?(pattern) }

      return [category, rule[:confidence], rule[:reason]]
    end

    [nil, 0.0, nil]
  end

  def signature_for(transaction)
    text = transaction.normalized_desc.presence || transaction.description
    upcased = text.to_s.upcase

    signature = if upcased.include?("DES:")
      upcased.split("DES:").first.to_s
    elsif upcased.match?(/\b\d{1,2}\/\d{1,2}\b/)
      upcased.split(/\b\d{1,2}\/\d{1,2}\b/).first.to_s
    elsif upcased.include?("CONFIRMATION#")
      upcased.split("CONFIRMATION#").first.to_s
    else
      upcased
    end

    cleaned = cleanup_signature(signature)
    cleaned.presence || cleanup_signature(upcased)
  end

  def build_rule_pattern(signature)
    cleanup_signature(signature)
  end

  def cleanup_signature(text)
    cleaned = text.to_s.upcase
      .gsub(/\bX{2,}[A-Z0-9]*\b/, " ")
      .gsub(/\s+/, " ")
      .strip

    loop do
      updated = cleaned.gsub(/\b(?:MOBILE|ONLINE|PURCHASE|PAYMENT|TRANSFER|TO|FROM|WEB)\b\s*\z/, "").strip
      break if updated == cleaned

      cleaned = updated
    end

    cleaned.gsub(/[;,:-]+\z/, "").strip
  end
end
