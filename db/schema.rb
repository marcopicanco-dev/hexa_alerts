# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_22_000004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "alert_subscriptions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "event_kind"
    t.bigint "fan_id", null: false
    t.bigint "match_id"
    t.bigint "team_id"
    t.datetime "updated_at", null: false
    t.index ["fan_id", "team_id", "match_id", "event_kind"], name: "index_alert_subscriptions_uniqueness", unique: true, nulls_not_distinct: true
    t.index ["fan_id"], name: "index_alert_subscriptions_on_fan_id"
    t.index ["match_id"], name: "index_alert_subscriptions_on_match_id"
    t.index ["team_id"], name: "index_alert_subscriptions_on_team_id"
  end

  create_table "fans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_fans_on_email", unique: true
  end

  create_table "match_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "kind", null: false
    t.bigint "match_id", null: false
    t.datetime "occurred_at", null: false
    t.jsonb "payload", default: {}, null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_match_events_on_external_id", unique: true
    t.index ["match_id", "occurred_at"], name: "index_match_events_on_match_id_and_occurred_at"
    t.index ["match_id"], name: "index_match_events_on_match_id"
    t.index ["team_id"], name: "index_match_events_on_team_id"
  end

  create_table "match_external_references", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.bigint "match_id", null: false
    t.string "source", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_match_external_references_on_external_id", unique: true
    t.index ["match_id"], name: "index_match_external_references_on_match_id"
    t.index ["source", "external_id"], name: "index_match_external_references_on_source_and_external_id", unique: true
  end

  create_table "matches", force: :cascade do |t|
    t.integer "away_score", default: 0, null: false
    t.bigint "away_team_id", null: false
    t.boolean "clock_running", default: false, null: false
    t.integer "clock_seconds", default: 0, null: false
    t.datetime "clock_updated_at"
    t.datetime "created_at", null: false
    t.string "data_source"
    t.string "external_id", null: false
    t.integer "home_score", default: 0, null: false
    t.bigint "home_team_id", null: false
    t.integer "matchday"
    t.jsonb "source_payload", default: {}, null: false
    t.string "stage"
    t.datetime "starts_at", null: false
    t.jsonb "statistics", default: {}, null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "updated_at", null: false
    t.string "venue_external_id"
    t.jsonb "win_probabilities", default: {}, null: false
    t.index ["away_team_id"], name: "index_matches_on_away_team_id"
    t.index ["data_source", "stage"], name: "index_matches_on_data_source_and_stage"
    t.index ["external_id"], name: "index_matches_on_external_id", unique: true
    t.index ["home_team_id"], name: "index_matches_on_home_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "country", null: false
    t.datetime "created_at", null: false
    t.string "data_source"
    t.string "external_id"
    t.string "fifa_code", null: false
    t.string "flag_url"
    t.string "group_name"
    t.string "iso2"
    t.string "name", null: false
    t.jsonb "source_payload", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["data_source", "external_id"], name: "index_teams_on_data_source_and_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["fifa_code"], name: "index_teams_on_fifa_code", unique: true
  end

  add_foreign_key "alert_subscriptions", "fans"
  add_foreign_key "alert_subscriptions", "matches"
  add_foreign_key "alert_subscriptions", "teams"
  add_foreign_key "match_events", "matches"
  add_foreign_key "match_events", "teams"
  add_foreign_key "match_external_references", "matches"
  add_foreign_key "matches", "teams", column: "away_team_id"
  add_foreign_key "matches", "teams", column: "home_team_id"
end
