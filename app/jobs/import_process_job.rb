class ImportProcessJob < ApplicationJob
  queue_as :default

  def perform(import_id)
    import = Import.find(import_id)
    return if import.completed? || import.failed?

    processor = ImportProcessor.new(import)

    case import.status
    when "pending"
      processor.preview
    when "previewing"
      processor.confirm
    end
  rescue StandardError => e
    import&.update!(
      status: :failed,
      error_log: (import.error_log || []) + [{ error: e.message, at: Time.current.iso8601 }]
    )
    raise # Re-raise so good_job can track the failure
  end
end
