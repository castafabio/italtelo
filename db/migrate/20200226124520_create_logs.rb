class CreateLogs < ActiveRecord::Migration[5.2]
  def change
    create_table :logs do |t|
      t.string :kind, default: nil
      t.string :action, default: nil
      t.string :description, default: nil
      t.timestamps
    end
  end
end
