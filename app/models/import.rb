class Import < ApplicationRecord
  belongs_to :account
  has_many :transactions, dependent: :nullify

  has_one_attached :file

  enum :file_type, { csv: 0, ofx: 1, qfx: 2, pdf: 3 }
  enum :status, { pending: 0, previewing: 1, processing: 2, completed: 3, failed: 4 }

  validates :file_name, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def rollback!
    Transaction.where(import_id: id).destroy_all
    update!(
      status: :failed,
      imported_count: 0,
      error_log: (error_log || []) + [{ error: "Import rolled back by user", at: Time.current.iso8601 }]
    )
  end
end
