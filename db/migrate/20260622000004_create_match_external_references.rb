class CreateMatchExternalReferences < ActiveRecord::Migration[8.1]
  def change
    create_table :match_external_references do |t|
      t.references :match, null: false, foreign_key: true
      t.string :source, null: false
      t.string :external_id, null: false
      t.timestamps
    end

    add_index :match_external_references, :external_id, unique: true
    add_index :match_external_references, %i[source external_id], unique: true
  end
end
