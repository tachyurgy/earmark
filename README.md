# Earmark

A designated-giving ledger for institutional fundraising, in Rails 8 on PostgreSQL.

Advancement offices do not receive money, they receive money *with strings on it*. A
$2,500 gift is 60 percent annual fund, 40 percent a named scholarship. Six weeks later
the donor asks to move it to athletics. Two weeks after that the card is charged back.
At every one of those moments the finance office needs to be able to say which fund is
holding which cent, and be right.

The usual implementation keeps a `designated_amount` column on the gift and a running
`balance` on the fund, updates both, and slowly drifts apart. Earmark does not have
those columns.

## What it actually does

**The ledger is append-only.** `allocations` is the only place designation lives. A row
is a signed integer number of cents pointing one gift at one fund, with a reason. Rows
are never updated and never deleted; `Allocation` raises `ActiveRecord::ReadOnlyRecord`
on both, so a correction has to be an offsetting row and the history stays reconstructible.

**Fund balances are derived.** `Fund#balance_cents` is `SUM(delta_cents)`. There is no
cached total, so there is nothing that can disagree with the ledger.

**Splits conserve every cent.** `Designation::Splitter` is largest-remainder (Hamilton)
apportionment over integer cents. Three equal designations on $10.00 come out
334 / 333 / 333, not 333 / 333 / 333 with a cent evaporating. The leftover goes to the
largest fractional remainder, ties broken on caller order, so the result is deterministic
and the same input always produces the same output.

**Applying a split is idempotent.** `Designation::Apply` posts the *difference* between
where the gift currently sits and where it should sit. Running the same designation twice
writes zero rows the second time. Funds the gift has left are explicitly zeroed.

**Refunds come out of the funds that hold the money.** `Designation::Refund` apportions
the refund pro rata across the gift's current position, through the same splitter. A
$40.00 refund against a gift sitting 75/25 takes $30.00 and $10.00, not $40.00 off
whichever fund the query happened to return first. That is the bug this codebase exists
to not have.

**The invariant is checked, not assumed.** Both services re-read the gift inside the
transaction and raise unless `allocated_cents == amount_cents - refunded_cents`, so a
half-written designation rolls back rather than persisting an imbalance. The dashboard
prints the same equation across the whole database on every page load.

## Tests

    bin/rails test

14 tests, ~3,000 assertions. The interesting ones are not the happy path:

- 1,000 randomized splits, asserting the parts sum to the total exactly every time
- a 40-gift storm of random designations, redesignations and partial refunds, asserting
  each gift stays balanced and that the global sum of the ledger equals the sum of all
  outstanding gift amounts
- an unbalanced split writes nothing at all
- allocations refuse to be updated or destroyed

## Stack

Rails 8.1, PostgreSQL 17, Hotwire, Propshaft, Puma. No JavaScript build step. Integer
cents throughout; no float touches money anywhere in the codebase.

## Running it

    bin/rails db:create db:migrate db:seed
    bin/rails server

Seed data is generated, not real: fifteen invented donors, five funds, thirty gifts with
randomized splits and occasional refunds. The seed refuses to finish if any gift it
created is unbalanced.
