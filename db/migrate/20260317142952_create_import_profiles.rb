class CreateImportProfiles < ActiveRecord::Migration[7.2]
  def change
    create_table :import_profiles do |t|
      t.references :account, null: false, foreign_key: true
      t.string :institution
      t.jsonb :column_mapping, default: {}
      t.string :date_format
      t.jsonb :description_corrections, default: {}
      t.string :amount_format
      t.integer :skip_header_rows, default: 1
      t.text :notes

      t.timestamps
    end

    add_index :import_profiles, [:account_id, :institution], unique: true
  end
end
