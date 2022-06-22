class CreateSubmitPoints < ActiveRecord::Migration[6.0]
  def change
    create_table :submit_points do |t|
      t.string :name
      t.string :kind, default: "preflight"
      t.timestamps
    end
  end
end
