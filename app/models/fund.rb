class Fund < ApplicationRecord
  has_many :allocations, dependent: :restrict_with_exception
  validates :code, :name, presence: true
  validates :code, uniqueness: true

  # The balance is derived, never stored. A cached total is one more thing that can
  # disagree with the ledger, and disagreeing with the ledger is the whole failure
  # mode this schema exists to prevent.
  def balance_cents
    allocations.sum(:delta_cents)
  end
end
