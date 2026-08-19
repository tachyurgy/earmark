module Designation
  # Point a gift at one or more funds. Idempotent on the gift's CURRENT position:
  # calling it twice with the same target split writes nothing the second time,
  # because it posts the difference between where the gift is and where it should
  # be, not the split itself.
  class Apply
    class Unbalanced < StandardError; end

    def initialize(gift)
      @gift = gift
    end

    # target: { fund_code => cents } or { fund_code => weight } with :by_weight
    def call(target, reason: "initial", by_weight: false)
      Gift.transaction do
        gift = Gift.lock.find(@gift.id)
        funds = Fund.where(code: target.keys).index_by(&:code)
        missing = target.keys - funds.keys
        raise ActiveRecord::RecordNotFound, "unknown funds: #{missing.join(', ')}" if missing.any?

        cents =
          if by_weight
            parts = Splitter.split(gift.designatable_cents, target.values)
            target.keys.zip(parts).to_h
          else
            target
          end

        total = cents.values.sum
        unless total == gift.designatable_cents
          raise Unbalanced,
                "split of #{total} does not match designatable #{gift.designatable_cents}"
        end

        current = gift.allocations.group(:fund_id).sum(:delta_cents)
        rows = []
        now = Time.current
        cents.each do |code, want|
          fund = funds[code]
          delta = want - current.fetch(fund.id, 0)
          next if delta.zero?
          rows << { gift_id: gift.id, fund_id: fund.id, delta_cents: delta,
                    reason: reason, created_at: now }
        end
        # Funds the gift used to point at but no longer does get zeroed out.
        (current.keys - cents.keys.map { |c| funds[c].id }).each do |fund_id|
          held = current[fund_id]
          next if held.zero?
          rows << { gift_id: gift.id, fund_id: fund_id, delta_cents: -held,
                    reason: reason, created_at: now }
        end

        Allocation.insert_all!(rows) if rows.any?
        gift.reload
        raise Unbalanced, "ledger did not balance after apply" unless gift.balanced?
        rows.size
      end
    end
  end
end
