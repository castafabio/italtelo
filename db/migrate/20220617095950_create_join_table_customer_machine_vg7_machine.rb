class CreateJoinTableCustomerMachineVg7Machine < ActiveRecord::Migration[6.1]
  def change
    create_join_table :customer_machines, :vg7_machines do |t|
      # t.index [:customer_machine_id, :vg7_machine_reference]
      # t.index [:vg7_machine_reference, :customer_machine_id]
    end
  end
end
