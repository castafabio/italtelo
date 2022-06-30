class AddReferenceToCustomerMachines < ActiveRecord::Migration[6.1]
  def change
    add_column :customer_machines, :bus240_machine_reference, :integer
  end
end
