# A small, plausible institutional advancement dataset. Nothing here is real data.
require "securerandom"

funds = [
  ["annual",      "Annual Fund",                 false],
  ["scholarship", "Chen Family Scholarship",     true],
  ["athletics",   "Athletics",                   false],
  ["library",     "Library Acquisitions",        true],
  ["unrestricted","Greatest Need",               false],
]
funds.each { |code, name, r| Fund.find_or_create_by!(code: code) { |f| f.name = name; f.restricted = r } }

names = ["Alice Warren", "Ben Okafor", "Clara Diaz", "Dmitri Volkov", "Elena Marsh",
         "Frank Ibarra", "Grace Lin", "Hugo Bennett", "Ingrid Salo", "Jonas Pike",
         "Keiko Tanaka", "Luis Fuentes", "Marta Reyes", "Nils Berg", "Omar Haddad"]
rng = Random.new(20260818)

names.each_with_index do |n, i|
  donor = Donor.find_or_create_by!(name: n) { |d| d.email = "#{n.split.first.downcase}@example.edu" }
  2.times do |k|
    ref = "gf-#{i}-#{k}"
    next if Gift.exists?(external_ref: ref)
    g = Gift.create!(donor: donor, amount_cents: rng.rand(25_00..7_500_00),
                     received_at: rng.rand(1..200).days.ago,
                     source: %w[card ach check].sample(random: rng),
                     external_ref: ref)
    picks = funds.map(&:first).sample(rng.rand(1..3), random: rng)
    Designation::Apply.new(g).call(picks.index_with { rng.rand(1..5) }, by_weight: true)
    if rng.rand < 0.18
      left = g.reload.designatable_cents
      Designation::Refund.new(g).call(rng.rand(1..[left, 1]. max) ) if left > 1
    end
  end
end

bad = Gift.all.reject(&:balanced?)
raise "seed produced #{bad.size} unbalanced gifts" if bad.any?
puts "seeded #{Fund.count} funds, #{Donor.count} donors, #{Gift.count} gifts, #{Allocation.count} ledger rows"
