class CreateImports < ActiveRecord::Migration[7.2]
  def change
    create_table :imports do |t|
      t.references :account, null: false, foreign_key: true
      t.string :file_name, null: false
      t.integer :file_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.integer :total_rows, default: 0
      t.integer :imported_count, default: 0
      t.integer :skipped_count, default: 0
      t.integer :error_count, default: 0
      t.jsonb :error_log, default: []
      t.jsonb :preview_data
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :imports, [:account_id, :created_at]
  end
end
