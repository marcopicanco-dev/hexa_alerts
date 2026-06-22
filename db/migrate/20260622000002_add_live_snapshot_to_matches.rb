class AddLiveSnapshotToMatches < ActiveRecord::Migration[8.1]
  def change
    change_table :matches, bulk: true do |t|
      t.integer :clock_seconds, null: false, default: 0
      t.boolean :clock_running, null: false, default: false
      t.datetime :clock_updated_at
      t.jsonb :statistics, null: false, default: {}
      t.jsonb :win_probabilities, null: false, default: {}
    end
  end
end
