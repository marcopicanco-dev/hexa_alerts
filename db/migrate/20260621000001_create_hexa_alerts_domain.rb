class CreateHexaAlertsDomain < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.string :fifa_code, null: false
      t.string :name, null: false
      t.string :country, null: false
      t.string :group_name
      t.timestamps
    end
    add_index :teams, :fifa_code, unique: true

    create_table :matches do |t|
      t.references :home_team, null: false, foreign_key: { to_table: :teams }
      t.references :away_team, null: false, foreign_key: { to_table: :teams }
      t.datetime :starts_at, null: false
      t.string :status, null: false, default: "scheduled"
      t.string :external_id, null: false
      t.integer :home_score, null: false, default: 0
      t.integer :away_score, null: false, default: 0
      t.timestamps
    end
    add_index :matches, :external_id, unique: true

    create_table :match_events do |t|
      t.references :match, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.string :kind, null: false
      t.datetime :occurred_at, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :external_id, null: false
      t.timestamps
    end
    add_index :match_events, :external_id, unique: true
    add_index :match_events, %i[match_id occurred_at]

    create_table :fans do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :fans, :email, unique: true

    create_table :alert_subscriptions do |t|
      t.references :fan, null: false, foreign_key: true
      t.references :team, foreign_key: true
      t.references :match, foreign_key: true
      t.string :event_kind
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :alert_subscriptions, %i[fan_id team_id match_id event_kind], unique: true, name: "index_alert_subscriptions_uniqueness", nulls_not_distinct: true
  end
end
