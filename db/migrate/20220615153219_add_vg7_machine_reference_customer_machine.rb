class AddVg7MachineReferenceCustomerMachine < ActiveRecord::Migration[6.1]
  def change
    add_column :customer_machines, :vg7_machine_reference, :text
  end
end
