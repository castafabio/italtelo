class CreateCutters < ActiveRecord::Migration[6.0]
  def change
    create_table :cutters do |t|
      t.belongs_to :resource, polymorphic: true
      t.belongs_to :customer_machine, default: nil
      t.string :file_name
      t.integer :cut_time, default: nil
      t.integer :quantity, default: 0
      t.datetime :gest_sent, default: nil
      t.datetime :starts_at
      t.datetime :ends_at
      t.timestamps
    end
  end
end
