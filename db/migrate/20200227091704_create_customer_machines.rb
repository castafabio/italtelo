class CreateCustomerMachines < ActiveRecord::Migration[6.0]
  def change
    create_table :customer_machines do |t|
      t.string :name
      t.string :bus240_machine_code
      t.string :kind
      t.string :ip_address
      t.string :serial_number
      t.string :path
      t.string :username
      t.string :psw
      t.string :hotfolder_path
      t.text :api_key
      t.string :import_job
      t.timestamps
    end
  end
end
