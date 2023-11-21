class AddTimestampToLineItems < ActiveRecord::Migration[6.1]
  def change
    add_column :line_items, :created_at, :datetime
    add_column :line_items, :updated_at, :datetime

    LineItem.where(order_year: "2022").update_all(created_at: DateTime.parse("01-01-2022"))
    LineItem.where(order_year: "2023").update_all(created_at: DateTime.parse("01-11-2023"))
  end
end
