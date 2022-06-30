class CreateItalteloUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :italtelo_users do |t|
      t.integer :code
      t.text :description
      t.timestamps
    end
    add_reference :line_items, :italtelo_user
  end
end
