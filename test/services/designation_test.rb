require "test_helper"

class DesignationTest < ActiveSupport::TestCase
  setup do
    @annual = fund!("annual", "Annual Fund")
    @schol  = fund!("scholarship", "Named Scholarship", restricted: true)
    @athl   = fund!("athletics", "Athletics")
  end

  test "an applied split balances the gift exactly" do
    g = gift!(250_00)
    Designation::Apply.new(g).call({ "annual" => 150_00, "scholarship" => 100_00 })
    assert g.reload.balanced?
    assert_equal 150_00, @annual.balance_cents
    assert_equal 100_00, @schol.balance_cents
  end

  test "a split that does not add up is refused, and nothing is written" do
    g = gift!(250_00)
    assert_raises(Designation::Apply::Unbalanced) do
      Designation::Apply.new(g).call({ "annual" => 100_00, "scholarship" => 100_00 })
    end
    assert_equal 0, g.reload.allocations.count
    assert_equal 0, @annual.balance_cents
  end

  test "applying the same split twice writes nothing the second time" do
    g = gift!(90_00)
    first  = Designation::Apply.new(g).call({ "annual" => 1, "scholarship" => 1, "athletics" => 1 }, by_weight: true)
    second = Designation::Apply.new(g).call({ "annual" => 1, "scholarship" => 1, "athletics" => 1 }, by_weight: true)
    assert_equal 3, first
    assert_equal 0, second
    assert g.reload.balanced?
  end

  test "redesignating moves money and zeroes the fund it left" do
    g = gift!(100_00)
    Designation::Apply.new(g).call({ "annual" => 100_00 })
    Designation::Apply.new(g).call({ "scholarship" => 100_00 }, reason: "reallocation")
    assert_equal 0, @annual.balance_cents
    assert_equal 100_00, @schol.balance_cents
    assert g.reload.balanced?
    # the history survives: the annual fund's two rows are both still there
    assert_equal 2, g.allocations.where(fund: @annual).count
  end

  test "a refund comes out of the funds that actually hold the money" do
    g = gift!(100_00)
    Designation::Apply.new(g).call({ "annual" => 75_00, "scholarship" => 25_00 })
    Designation::Refund.new(g).call(40_00)

    assert_equal 40_00, g.reload.refunded_cents
    assert_equal 60_00, g.designatable_cents
    assert g.balanced?
    # 40.00 taken pro rata from 75/25 is 30.00 and 10.00, not 40.00 off the first fund
    assert_equal 45_00, @annual.balance_cents
    assert_equal 15_00, @schol.balance_cents
  end

  test "refunding more than remains is refused" do
    g = gift!(50_00)
    Designation::Apply.new(g).call({ "annual" => 50_00 })
    Designation::Refund.new(g).call(30_00)
    assert_raises(Designation::Refund::TooMuch) { Designation::Refund.new(g).call(30_00) }
    assert_equal 30_00, g.reload.refunded_cents
  end

  test "allocations cannot be edited or deleted once written" do
    g = gift!(10_00)
    Designation::Apply.new(g).call({ "annual" => 10_00 })
    a = g.allocations.first
    assert_raises(ActiveRecord::ReadOnlyRecord) { a.update!(delta_cents: 1) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { a.destroy! }
  end

  test "the ledger stays balanced through a random storm of designations and refunds" do
    rng = Random.new(4242)
    codes = %w[annual scholarship athletics]
    40.times do
      g = gift!(rng.rand(5_00..2_000_00))
      Designation::Apply.new(g).call(
        codes.sample(rng.rand(1..3), random: rng).index_with { rng.rand(1..9) }, by_weight: true)
      rng.rand(0..2).times do
        left = g.reload.amount_cents - g.refunded_cents
        next if left < 2
        Designation::Refund.new(g).call(rng.rand(1..left))
      end
      assert g.reload.balanced?, "gift #{g.id} unbalanced"
    end

    # And the global invariant: every cent sitting in a fund traces to a gift.
    assert_equal Gift.sum("amount_cents - refunded_cents"), Allocation.sum(:delta_cents)
  end
end
