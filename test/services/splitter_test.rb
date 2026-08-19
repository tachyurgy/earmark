require "test_helper"

class SplitterTest < ActiveSupport::TestCase
  S = Designation::Splitter

  test "conserves every cent for an indivisible total" do
    parts = S.split(1000, [1, 1, 1])
    assert_equal 1000, parts.sum
    assert_equal [334, 333, 333], parts
  end

  test "conserves cents across a thousand random splits" do
    rng = Random.new(20260818)
    1000.times do
      total = rng.rand(1..5_000_00)
      weights = Array.new(rng.rand(1..7)) { rng.rand(1..1000) }
      parts = S.split(total, weights)
      assert_equal total, parts.sum, "lost cents on #{total} / #{weights.inspect}"
      assert_equal weights.size, parts.size
      assert parts.all? { |p| p >= 0 }
    end
  end

  test "a negative total splits negatively and still conserves" do
    parts = S.split(-1000, [1, 1, 1])
    assert_equal(-1000, parts.sum)
    assert parts.all?(&:negative?)
  end

  test "is stable: the same input always gives the same output" do
    a = S.split(100_01, [3, 3, 3, 1])
    b = S.split(100_01, [3, 3, 3, 1])
    assert_equal a, b
  end

  test "a zero weight receives nothing" do
    assert_equal [1000, 0], S.split(1000, [1, 0])
  end

  test "refuses weights that sum to zero rather than dividing by zero" do
    assert_raises(ArgumentError) { S.split(100, [0, 0]) }
  end
end
