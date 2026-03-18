class ImportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account
  before_action :set_import, only: [:show, :preview, :confirm, :rollback]

  def index
    @imports = @account.imports.recent
  end

  def show
  end

  def new
    @import = @account.imports.build
  end

  def create
    @import = @account.imports.build(import_params)
    @import.file_name = params[:import][:file]&.original_filename || "upload"
    @import.file.attach(params[:import][:file]) if params[:import][:file]

    unless @import.file.attached?
      @import.errors.add(:base, "Please select a file to upload")
      render :new, status: :unprocessable_entity
      return
    end

    # Auto-detect file type from extension
    ext = File.extname(@import.file_name).downcase.delete(".")
    @import.file_type = ext if Import.file_types.key?(ext)

    if @import.save
      # Parse and generate preview synchronously (good_job runs inline in dev)
      processor = ImportProcessor.new(@import)
      processor.preview
      redirect_to preview_account_import_path(@account, @import), notice: "File parsed. Review transactions below."
    else
      render :new, status: :unprocessable_entity
    end
  rescue StandardError => e
    @import.update(status: :failed, error_log: [{ error: e.message, at: Time.current.iso8601 }]) if @import&.persisted?
    redirect_to new_account_import_path(@account), alert: "Failed to parse file: #{e.message}"
  end

  def preview
    @parsed_transactions = @import.preview_data || []
    fingerprints = @parsed_transactions.filter_map { |t| t["source_fingerprint"] || t[:source_fingerprint] }
    @existing_fingerprints = Transaction.where(account_id: @account.id, source_fingerprint: fingerprints)
                                        .pluck(:source_fingerprint)
                                        .to_set
  end

  def confirm
    unless @import.previewing?
      redirect_to account_import_path(@account, @import), alert: "This import cannot be confirmed."
      return
    end

    processor = ImportProcessor.new(@import)
    result = processor.confirm

    redirect_to account_import_path(@account, @import),
      notice: "Import complete: #{result[:imported]} imported, #{result[:skipped]} skipped, #{result[:categorized]} auto-categorized."
  end

  def rollback
    unless @import.completed?
      redirect_to account_import_path(@account, @import), alert: "Only completed imports can be rolled back."
      return
    end

    removed_count = @import.transactions.count
    @import.rollback!
    redirect_to account_imports_path(@account), notice: "Import rolled back. #{removed_count} transactions removed."
  end

  private

  def set_account
    @account = current_user.accounts.find(params[:account_id])
  end

  def set_import
    @import = @account.imports.find(params[:id])
  end

  def import_params
    params.require(:import).permit(:file_type)
  end
end
