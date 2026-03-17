class Category < ApplicationRecord
  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: :parent_id, dependent: :nullify

  has_many :transactions, dependent: :nullify
  has_many :rules, dependent: :destroy
  has_many :budgets, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  scope :top_level, -> { where(parent_id: nil) }
  scope :sorted, -> { order(:position, :name) }

  def full_name
    parent ? "#{parent.name} > #{name}" : name
  end
end
