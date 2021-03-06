class CreateAggregatedJobs < ActiveRecord::Migration[6.0]
  def change
    create_table :aggregated_jobs do |t|
      t.belongs_to :customer_machine
      t.string :code
      t.string :status, default: "brand_new"
      t.text :notes
      t.integer :print_number_of_files, default: 0
      t.integer :cut_number_of_files, default: 0
      t.boolean :need_printing, default: false
      t.boolean :need_cutting, default: false
      t.datetime :send_at, default: nil
      t.timestamps
    end
    add_reference :aggregated_jobs, :print_customer_machine, foreign_key: { to_table: 'customer_machines' }
    add_reference :aggregated_jobs, :cut_customer_machine, foreign_key: { to_table: 'customer_machines' }
  end
end
