class CreatePrinters < ActiveRecord::Migration[5.2]
  def change
    create_table :printers do |t|
      t.belongs_to :customer_machine
      t.belongs_to :resource, polymorphic: true
      t.string :job_id
      t.string :file_name
      t.text :ink
      t.datetime :gest_sent, default: nil
      t.datetime :start_at
      t.datetime :end_at
      t.string :print_time
      t.string :extra_data
      t.timestamps
    end
  end
end
