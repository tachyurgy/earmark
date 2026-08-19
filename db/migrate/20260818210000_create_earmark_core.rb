class CreateEarmarkCore < ActiveRecord::Migration[8.1]
  def change
    create_table :funds do |t|
      t.string  :code, null: false
      t.string  :name, null: false
      t.boolean :restricted, null: false, default: false
      t.timestamps
    end
    add_index :funds, :code, unique: true

    create_table :donors do |t|
      t.string :name, null: false
      t.string :email
      t.timestamps
    end

    create_table :gifts do |t|
      t.references :donor, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.integer :refunded_cents, null: false, default: 0
      t.string  :source, null: false, default: "card"
      t.string  :external_ref
      t.datetime :received_at, null: false
      t.timestamps
    end
    add_index :gifts, :external_ref, unique: true
    add_check_constraint :gifts, "amount_cents > 0", name: "gift_amount_positive"
    add_check_constraint :gifts, "refunded_cents >= 0 AND refunded_cents <= amount_cents",
                         name: "gift_refund_within_amount"

    # Append-only. A designation is never updated in place; it is corrected by
    # writing an offsetting row, so the history of where a gift was pointed is
    # recoverable and an audit can be reproduced from the table alone.
    create_table :allocations do |t|
      t.references :gift, null: false, foreign_key: true
      t.references :fund, null: false, foreign_key: true
      t.integer :delta_cents, null: false
      t.string  :reason, null: false
      t.datetime :created_at, null: false
    end
    add_index :allocations, [:gift_id, :fund_id]
    add_check_constraint :allocations, "delta_cents <> 0", name: "allocation_nonzero"
  end
end
