class CreateCompetitionSyncs < ActiveRecord::Migration[8.1]
  def change
    create_table :competition_syncs do |t|
      t.string :status, default: "queued", null: false
      t.jsonb :details, default: {}, null: false
      t.text :error_message
      t.datetime :finished_at
      t.timestamps
    end

    add_index :competition_syncs, "(1)", unique: true,
      where: "status IN ('queued', 'running')", name: "index_one_active_competition_sync"
  end
end
