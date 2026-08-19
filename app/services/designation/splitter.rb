module Designation
  # Split an integer number of cents across weights so that the parts sum EXACTLY
  # to the whole. Proportional division in cents is where donation systems quietly
  # lose money: three funds at a third of $10.00 is 333 + 333 + 333 = 999, and the
  # missing cent has to go somewhere deterministic rather than nowhere.
  #
  # Largest-remainder (Hamilton) apportionment: floor everything, then hand the
  # leftover cents out one at a time to the largest fractional remainders, breaking
  # ties on the caller's order so the result is stable across runs.
  module Splitter
    module_function

    def split(total_cents, weights)
      raise ArgumentError, "no weights" if weights.empty?
      raise ArgumentError, "weights must be non-negative" if weights.any?(&:negative?)

      sum = weights.sum
      raise ArgumentError, "weights sum to zero" if sum.zero?

      sign = total_cents.negative? ? -1 : 1
      magnitude = total_cents.abs

      exact = weights.map { |w| Rational(magnitude * w, sum) }
      base  = exact.map(&:floor)
      short = magnitude - base.sum

      order = exact.each_with_index
                   .sort_by { |value, i| [-(value - value.floor), i] }
                   .map(&:last)
      order.first(short).each { |i| base[i] += 1 }

      base.map { |c| c * sign }
    end
  end
end
