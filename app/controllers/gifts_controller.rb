class GiftsController < ApplicationController
  before_action :set_gift, except: :index

  def index
    @gifts = Gift.includes(:donor).order(received_at: :desc).limit(100)
  end

  def show
  end

  def designate
    weights = params.fetch(:weights, {}).to_unsafe_h
                    .transform_values { |v| v.to_i }.reject { |_, v| v <= 0 }
    if weights.empty?
      return respond_with_error("Give at least one fund a weight above zero.")
    end
    Designation::Apply.new(@gift).call(weights, by_weight: true, reason: params[:reason].presence || "reallocation")
    respond_ok
  rescue Designation::Apply::Unbalanced, ArgumentError, ActiveRecord::RecordNotFound => e
    respond_with_error(e.message)
  end

  def refund
    Designation::Refund.new(@gift).call((params[:amount].to_f * 100).round)
    respond_ok
  rescue Designation::Refund::TooMuch, ArgumentError => e
    respond_with_error(e.message)
  end

  private

  def set_gift
    @gift = Gift.find(params[:id])
  end

  def respond_ok
    redirect_to gift_path(@gift), notice: "Ledger updated and balanced."
  end

  def respond_with_error(msg)
    redirect_to gift_path(@gift), alert: msg
  end
end
