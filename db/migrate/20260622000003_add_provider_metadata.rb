class AddProviderMetadata < ActiveRecord::Migration[8.1]
  def change
    change_table :teams, bulk: true do |t|
      t.string :external_id
      t.string :data_source
      t.string :iso2
      t.string :flag_url
      t.jsonb :source_payload, null: false, default: {}
    end
    add_index :teams, %i[data_source external_id], unique: true, where: "external_id IS NOT NULL"

    change_table :matches, bulk: true do |t|
      t.string :data_source
      t.string :stage
      t.integer :matchday
      t.string :venue_external_id
      t.jsonb :source_payload, null: false, default: {}
    end
    add_index :matches, %i[data_source stage]
  end
end
