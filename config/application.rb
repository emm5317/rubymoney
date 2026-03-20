require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Rubymoney
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Use good_job as the Active Job backend
    config.active_job.queue_adapter = :good_job

    config.good_job.preserve_job_records = true
    config.good_job.retry_on_unhandled_error = false
    config.good_job.on_thread_error = ->(exception) { Rails.logger.error(exception) }
    config.good_job.execution_mode = :async
    config.good_job.enable_cron = true
    config.good_job.cron = {
      balance_snapshot: {
        cron: "0 2 * * *", # Daily at 2 AM
        class: "BalanceSnapshotJob",
        description: "Record daily account balance snapshots for net worth tracking"
      },
      recurring_detection: {
        cron: "0 3 * * *", # Daily at 3 AM (after balance snapshots)
        class: "RecurringDetectionJob",
        description: "Detect recurring transaction patterns across all accounts"
      },
      database_backup: {
        cron: "0 3 * * *", # Daily at 3 AM
        class: "DatabaseBackupJob",
        description: "Automated database backup with 30-day rotation"
      }
    }
  end
end
