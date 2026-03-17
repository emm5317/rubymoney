class ImportProfile < ApplicationRecord
  belongs_to :account

  validates :account_id, uniqueness: { scope: :institution }

  def apply_description_correction(raw_desc)
    description_corrections&.fetch(raw_desc, raw_desc) || raw_desc
  end

  def learn_description_correction!(raw, corrected)
    corrections = description_corrections || {}
    corrections[raw] = corrected
    update!(description_corrections: corrections)
  end

  def learn_column_mapping!(mapping)
    update!(column_mapping: mapping)
  end

  def learn_date_format!(format)
    update!(date_format: format)
  end
end
