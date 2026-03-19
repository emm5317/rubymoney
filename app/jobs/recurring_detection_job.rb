class RecurringDetectionJob < ApplicationJob
  queue_as :default

  def perform
    User.find_each do |user|
      RecurringDetector.new(user).detect_all
    rescue => e
      Rails.logger.error("RecurringDetectionJob failed for user #{user.id}: #{e.message}")
    end
  end
end
