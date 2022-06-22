class CreateLineItems < ActiveRecord::Migration[6.0]
  def change
    create_table :line_items do |t|
      t.belongs_to :order
      t.belongs_to :customer_machine
      t.belongs_to :aggregated_job
      t.belongs_to :submit_point
      t.integer :row_number
      t.integer :subjects
      t.integer :quantity
      t.integer :height
      t.integer :width
      t.integer :print_number_of_files, default: 0
      t.integer :cut_number_of_files, default: 0
      t.string :material
      t.string :article_code
      t.string :article_name
      t.string :scale, default: '1:1'
      t.string :sides, default: 'Monofacciale'
      t.text :description
      t.text :error_message, default: nil
      t.datetime :switch_sent, default: nil
      t.boolean :aluan, default: true
      t.boolean :need_printing, default: false
      t.boolean :need_cutting, default: false
      t.boolean :sending, default: false
      t.json :fields_data
    end
    add_reference :line_items, :print_customer_machine, foreign_key: { to_table: 'customer_machines' }
    add_reference :line_items, :cut_customer_machine, foreign_key: { to_table: 'customer_machines' }
  end
end
