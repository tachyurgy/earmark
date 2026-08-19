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

ActiveRecord::Schema[8.1].define(version: 2026_08_18_210000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "allocations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "delta_cents", null: false
    t.bigint "fund_id", null: false
    t.bigint "gift_id", null: false
    t.string "reason", null: false
    t.index ["fund_id"], name: "index_allocations_on_fund_id"
    t.index ["gift_id", "fund_id"], name: "index_allocations_on_gift_id_and_fund_id"
    t.index ["gift_id"], name: "index_allocations_on_gift_id"
    t.check_constraint "delta_cents <> 0", name: "allocation_nonzero"
  end

  create_table "donors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "funds", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.boolean "restricted", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_funds_on_code", unique: true
  end

  create_table "gifts", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.bigint "donor_id", null: false
    t.string "external_ref"
    t.datetime "received_at", null: false
    t.integer "refunded_cents", default: 0, null: false
    t.string "source", default: "card", null: false
    t.datetime "updated_at", null: false
    t.index ["donor_id"], name: "index_gifts_on_donor_id"
    t.index ["external_ref"], name: "index_gifts_on_external_ref", unique: true
    t.check_constraint "amount_cents > 0", name: "gift_amount_positive"
    t.check_constraint "refunded_cents >= 0 AND refunded_cents <= amount_cents", name: "gift_refund_within_amount"
  end

  add_foreign_key "allocations", "funds"
  add_foreign_key "allocations", "gifts"
  add_foreign_key "gifts", "donors"
end
