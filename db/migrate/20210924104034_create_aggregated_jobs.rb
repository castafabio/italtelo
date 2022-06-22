class CreateAggregatedJobs < ActiveRecord::Migration[6.0]
  def change
    create_table :aggregated_jobs do |t|
      t.belongs_to :customer_machine
      t.belongs_to :submit_point
      t.string :status, default: "brand_new"
      t.date :deadline
      t.datetime :switch_sent, default: nil
      t.text :error_message, default: nil
      t.text :notes
      t.integer :print_number_of_files, default: 0
      t.integer :cut_number_of_files, default: 0
      t.boolean :need_printing, default: false
      t.boolean :need_cutting, default: false
      t.boolean :tilia, default: false
      t.boolean :aluan, default: true
      t.boolean :sending, default: false
      t.json :fields_data
      t.timestamps
    end
    add_reference :aggregated_jobs, :print_customer_machine, foreign_key: { to_table: 'customer_machines' }
    add_reference :aggregated_jobs, :cut_customer_machine, foreign_key: { to_table: 'customer_machines' }
  end
end
