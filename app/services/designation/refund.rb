module Designation
  # Take money back out of a gift and out of the funds it was pointed at, pro rata
  # to where it currently sits. The refunded cents come off the funds that actually
  # hold them, which is the part a naive implementation gets wrong: it debits the
  # first fund, or the largest, and the restricted-fund balance ends up carrying a
  # refund that belonged to the annual fund.
  class Refund
    class TooMuch < StandardError; end

    def initialize(gift)
      @gift = gift
    end

    def call(cents, reason: "refund")
      raise ArgumentError, "refund must be positive" unless cents.positive?

      Gift.transaction do
        gift = Gift.lock.find(@gift.id)
        remaining = gift.amount_cents - gift.refunded_cents
        raise TooMuch, "cannot refund #{cents} of #{remaining} remaining" if cents > remaining

        held = gift.allocations.group(:fund_id).sum(:delta_cents).reject { |_, c| c.zero? }
        raise TooMuch, "gift holds no designations to refund from" if held.empty?

        fund_ids = held.keys
        parts = Splitter.split(cents, held.values_at(*fund_ids))
        now = Time.current
        rows = fund_ids.zip(parts).filter_map do |fund_id, part|
          next if part.zero?
          { gift_id: gift.id, fund_id: fund_id, delta_cents: -part,
            reason: reason, created_at: now }
        end

        Allocation.insert_all!(rows) if rows.any?
        gift.update!(refunded_cents: gift.refunded_cents + cents)
        gift.reload
        raise TooMuch, "ledger did not balance after refund" unless gift.balanced?
        rows.size
      end
    end
  end
end
