class CreateRoles < ActiveRecord::Migration[5.2]
  def change
    create_table(:roles) do |t|
      t.string :code, uniq: true
      t.string :name, uniq: true
      t.integer :value, uniq: true

      t.timestamps
    end

    create_table(:roles_users, :id => false) do |t|
      t.references :role
      t.references :user
    end

    add_index(:roles_users, [ :role_id, :user_id ], unique: true)
  end
end
