class AddColumnToPrinters < ActiveRecord::Migration[6.1]
  def change
    add_column :printers, :copies, :integer, default: 1
    add_column :printers, :material, :string, default: ''
  end
end
