class CreateLineItems < ActiveRecord::Migration[6.0]
  def change
    create_table :line_items do |t|
      t.belongs_to :customer_machine
      t.belongs_to :aggregated_job
      t.string :print_reference, default: nil
      t.string :cut_reference, default: nil
      t.string :customer
      t.string :article_code
      t.string :article_description
      t.string :status, default: 'brand_new'
      t.string :order_year
      t.string :order_phase
      t.string :order_line_item
      t.string :order_series
      t.string :order_type
      t.integer :order_code
      t.integer :quantity
      t.integer :print_number_of_files, default: 0
      t.integer :cut_number_of_files, default: 0
      t.text :notes
      t.datetime :send_at, default: nil
    end
    add_reference :line_items, :print_customer_machine, foreign_key: { to_table: 'customer_machines' }
    add_reference :line_items, :cut_customer_machine, foreign_key: { to_table: 'customer_machines' }
  end
end
