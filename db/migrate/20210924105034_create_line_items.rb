class CreateLineItems < ActiveRecord::Migration[6.0]
  def change
    create_table :line_items do |t|
      t.belongs_to :customer_machine
      t.belongs_to :aggregated_job
      t.string :row_number
      t.string :customer
      t.string :article_code
      t.string :article_description
      t.string :status, default: 'brand_new'
      t.integer :order_code
      t.integer :quantity
      t.integer :number_of_files, default: 0
      t.text :notes
      t.boolean :need_printing, default: false
      t.boolean :need_cutting, default: false
      t.datetime :send_at, default: nil
    end
  end
end
