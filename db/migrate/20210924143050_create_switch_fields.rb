class CreateSwitchFields < ActiveRecord::Migration[6.0]
  def change
    create_table :switch_fields do |t|
      t.belongs_to :submit_point
      t.string :dependency, default: ""
      t.string :dependency_condition, default: ""
      t.string :dependency_value, default: ""
      t.boolean :display_field, default: false
      t.boolean :read_only, default: false
      t.string :field_id
      t.string :kind
      t.text :enum_values
      t.boolean :required
      t.string :name, default: ""
      t.text :description
      t.integer :sort
      t.string :default_value
      t.boolean :visible_on_line_item, default: false
      t.timestamps
    end
  end
end
