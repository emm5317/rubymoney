class CreateCategories < ActiveRecord::Migration[7.2]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.bigint :parent_id
      t.string :color
      t.string :icon
      t.integer :position

      t.timestamps
    end

    add_index :categories, :name, unique: true
    add_index :categories, :parent_id
  end
end
