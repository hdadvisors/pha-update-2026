# affordcalc.R ----
# What:   Ownership and rental affordability calculators -- income needed for a given
#         home price or rent, and maximum affordable price or rent for a given income.
#         A methodology module, not a data pull: no API calls, no write_rds(). Sourced
#         by r/gaps.R, never called directly from a chapter (data-flow rule: chapters
#         read_rds() only).
# Source: None -- pure functions. Mortgage math follows the standard amortization
#         formula; ownership assumptions below are provisional placeholders pending
#         PHA input (Section 8 methodology spec: "PHA advises on them").
# Output: none (functions only; validated below against a hand-computed reference).

## 1. Setup ----
# No library() calls needed beyond base R.

## 2. Ownership affordability assumptions (PROVISIONAL -- PHA to confirm) ----
# Down payment: 10%, a common conventional/first-time-buyer assumption (not the 20%
# needed to avoid PMI, which this calculator does not model).
# Property tax: 1.00% of home value annually, a single regional placeholder -- real
# rates vary by locality and are not yet pulled into this project.
# Homeowners insurance: $1,500/year flat, a single regional placeholder.
# Loan term: 30-year fixed. Front-end ratio: 28% of gross monthly income (payment
# at or below 28 percent of monthly income, per the ownership-affordability method).
default_down_pct    <- 0.10
default_tax_rate    <- 0.0100
default_annual_ins  <- 1500
default_term_years  <- 30
default_dti         <- 0.28

## 3. Ownership functions ----

# Monthly principal, interest, tax, and insurance (PITI) for a home price at a given
# annual mortgage rate (percent, e.g. 6.54).
monthly_piti <- function(price, rate_annual,
                          down_pct = default_down_pct,
                          term_years = default_term_years,
                          tax_rate = default_tax_rate,
                          annual_ins = default_annual_ins) {
  loan <- price * (1 - down_pct)
  r <- (rate_annual / 100) / 12
  n <- term_years * 12
  pi <- loan * r * (1 + r)^n / ((1 + r)^n - 1)
  monthly_tax <- price * tax_rate / 12
  monthly_ins <- annual_ins / 12
  pi + monthly_tax + monthly_ins
}

# Annual household income needed to afford a home price at a 28% front-end ratio.
income_needed_for_price <- function(price, rate_annual, dti = default_dti, ...) {
  monthly_piti(price, rate_annual, ...) / dti * 12
}

# Maximum affordable home price for a given annual household income (inverse of the
# above), solved by bisection since PITI is not linear in price once tax/insurance
# scale with it -- though in practice the relationship is close to linear.
max_affordable_price <- function(income, rate_annual, dti = default_dti, ...) {
  target_monthly <- income * dti / 12
  lo <- 0; hi <- 5e6
  for (i in 1:60) {
    mid <- (lo + hi) / 2
    if (monthly_piti(mid, rate_annual, ...) > target_monthly) hi <- mid else lo <- mid
  }
  (lo + hi) / 2
}

## 4. Rental affordability functions (Section 8 methodology: 30% of monthly income) ----

income_needed_for_rent <- function(rent, dti = 0.30) rent * 12 / dti

max_affordable_rent <- function(income, dti = 0.30) income * dti / 12

## 5. Validate ----
# Hand-computed reference: $300,000 price, 10% down, 6.5% rate, 30-year term ->
# loan $270,000, monthly rate 0.5416667%, standard amortization P&I is ~$1,706.
ref_pi <- monthly_piti(300000, 6.5, tax_rate = 0, annual_ins = 0)
stopifnot(abs(ref_pi - 1706) < 5)

# income_needed_for_price and max_affordable_price must invert each other.
p <- 350000
inc <- income_needed_for_price(p, 6.54)
stopifnot(abs(max_affordable_price(inc, 6.54) - p) < 1)

# Rental round-trip.
stopifnot(abs(max_affordable_rent(income_needed_for_rent(1500)) - 1500) < 0.01)

message("affordcalc.R validation passed (reference P&I $", round(ref_pi), " vs. ~$1,706 expected).")
