class AddOldCustomerMachineToLineItems < ActiveRecord::Migration[6.1]
  def change
    add_reference :line_items, :old_print_customer_machine, foreign_key: { to_table: 'customer_machines' }
    add_reference :line_items, :old_cut_customer_machine, foreign_key: { to_table: 'customer_machines' }
  end
end
