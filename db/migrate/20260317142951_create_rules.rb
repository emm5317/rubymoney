class CreateRules < ActiveRecord::Migration[7.2]
  def change
    create_table :rules do |t|
      t.references :category, null: false, foreign_key: true
      t.integer :match_field, null: false, default: 0
      t.integer :match_type, null: false, default: 0
      t.string :match_value, null: false
      t.string :match_value_upper
      t.integer :priority, null: false, default: 0
      t.boolean :enabled, null: false, default: true
      t.boolean :apply_retroactive, null: false, default: false
      t.jsonb :auto_tag_ids, default: []

      t.timestamps
    end

    add_index :rules, :priority
    add_index :rules, :enabled
  end
end
