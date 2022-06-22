class AddFieldsToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :first_name, :string, default: '', limit: 64, null: false
    add_column :users, :last_name, :string, default: '', limit: 64, null: false
  end
end
