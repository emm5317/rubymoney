class DatabaseBackupJob < ApplicationJob
  queue_as :default

  def perform
    Rake::Task["db:backup"].invoke
  ensure
    Rake::Task["db:backup"].reenable
  end
end
