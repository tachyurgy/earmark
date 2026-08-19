ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  parallelize(workers: 1)

  def fund!(code, name = nil, restricted: false)
    Fund.find_or_create_by!(code: code) { |f| f.name = name || code.titleize; f.restricted = restricted }
  end

  def gift!(cents, donor: nil, ref: nil)
    donor ||= Donor.create!(name: "Donor #{SecureRandom.hex(3)}")
    Gift.create!(donor: donor, amount_cents: cents, received_at: Time.current,
                 external_ref: ref || SecureRandom.hex(8))
  end
end
