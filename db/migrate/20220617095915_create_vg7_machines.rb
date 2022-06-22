class CreateVg7Machines < ActiveRecord::Migration[6.1]
  def change
    create_table :vg7_machines do |t|
      t.text :description
      t.text :vg7_machine_reference
      t.timestamps
    end
    add_reference :line_items, :vg7_print_machine, foreign_key: { to_table: 'vg7_machines' }
    add_reference :line_items, :vg7_cut_machine, foreign_key: { to_table: 'vg7_machines' }
    add_reference :aggregated_jobs, :vg7_print_machine, foreign_key: { to_table: 'vg7_machines' }
    add_reference :aggregated_jobs, :vg7_cut_machine, foreign_key: { to_table: 'vg7_machines' }
    add_column :aggregated_jobs, :code, :text
  end
end
