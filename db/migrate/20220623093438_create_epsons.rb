class CreateEpsons < ActiveRecord::Migration[6.1]
  def change
    create_table :epsons do |t|
      t.string   :PrinterName, default: nil
      t.string   :DocName, default: nil
      t.datetime :PrintStartTime, default: nil
      t.datetime :PrintEndTime, default: nil
      t.integer  :PageNumber, default: nil
      t.string   :UserMediaName, default: nil
      t.string   :SerialNumber, default: nil
      t.text     :Ink
      t.string   :DbSource, default: nil
      t.string   :DbTable, default: nil
      t.integer  :JobId, default: nil
      t.boolean  :imported, default: false
    end
  end
end
