class Allocation < ApplicationRecord
  REASONS = %w[initial reallocation refund chargeback correction].freeze

  belongs_to :gift
  belongs_to :fund
  validates :delta_cents, numericality: { other_than: 0 }
  validates :reason, inclusion: { in: REASONS }

  # Append-only: an allocation row is a fact about a moment, and facts do not change.
  before_update { raise ActiveRecord::ReadOnlyRecord, "allocations are append-only" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "allocations are append-only" }
end
