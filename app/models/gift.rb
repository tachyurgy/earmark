class Gift < ApplicationRecord
  belongs_to :donor
  has_many :allocations, dependent: :restrict_with_exception

  validates :amount_cents, numericality: { greater_than: 0 }

  # What the ledger for this gift must sum to right now.
  def designatable_cents
    amount_cents - refunded_cents
  end

  def allocated_cents
    allocations.sum(:delta_cents)
  end

  def balanced?
    allocated_cents == designatable_cents
  end

  # Current split, funds with a zero net position dropped.
  def designations
    allocations.group(:fund_id).sum(:delta_cents).reject { |_, c| c.zero? }
  end
end
