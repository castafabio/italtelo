class CreateOrders < ActiveRecord::Migration[6.0]
  def change
    create_table :orders do |t|
      t.string :order_code
      t.date :order_date
      t.string :customer
    end
  end
end
