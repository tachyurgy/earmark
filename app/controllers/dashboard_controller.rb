class DashboardController < ApplicationController
  def index
    @funds = Fund.order(:name)
    @gifts = Gift.includes(:donor).order(received_at: :desc).limit(25)
    @total_gifts = Gift.sum("amount_cents - refunded_cents")
    @total_allocated = Allocation.sum(:delta_cents)
  end
end
