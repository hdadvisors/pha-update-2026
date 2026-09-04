# gaps.R ----
# What:   Two of gaps.qmd's four planned cuts, built without the PUMS pipeline (Section
#         5 row 15, r/pums/*, not yet built -- Phase 4 is `not planned`): (1) minimum
#         income needed to buy at representative price points by structure type, set
#         against the region's household-income distribution, and (2) the starter-home
#         gap, renter households whose income clears that entry-level threshold. The
#         AMI-band-by-income rental gap and the renter-competition table (gaps.qmd
#         sections 1-2) need PUMS or CHAS Table 14/15 unit-affordability data, neither
#         of which exists yet -- left as "Coming in a future draft" in the chapter.
# Source: data/mls_transactions.rds (price points), data/fred.rds (mortgage rate),
#         data/acs_income.rds (household income distribution), data/chas_cb.rds (renter
#         households by AMI band), data/hud_ami.rds (AMI dollar thresholds).
# Note:   Ownership affordability assumptions (down payment, tax, insurance) live in
#         r/affordcalc.R and are provisional -- flagged there and in gaps.qmd for PHA
#         input. The starter-home cut compares a dollar income threshold (FY2026 HUD
#         income limits) against CHAS 2018-2022 AMI-relative household counts -- a
#         vintage mismatch (current-dollar limits vs. 2018-2022 HAMFI bands) logged as
#         a narrative caveat, never a validation gate (see CLAUDE.md, Validation semantics).
# Output: data/gaps_income_table.rds (+ data-out/gaps_income_table.csv)
#         data/gaps_starter.rds       (+ data-out/gaps_starter.csv)

## 1. Setup ----
library(tidyverse)
source("_common.R") # pha; export_csv()
source("r/affordcalc.R") # income_needed_for_price()

mls  <- read_rds("data/mls_transactions.rds")
fred <- read_rds("data/fred.rds")
inc  <- read_rds("data/acs_income.rds")
chas <- read_rds("data/chas_cb.rds")
ami  <- read_rds("data/hud_ami.rds")

pha_names <- c("CHESTERFIELD", "HANOVER", "HENRICO", "RICHMOND CITY")

## 2. Recent-window MLS price points, pha region, by structure type ----
# Trailing 12 months of closed sales -- "today's prices" per the Section 8 spec,
# not the full 2020-2026 trend window used elsewhere in the report.
max_date <- max(mls$sales_date, na.rm = TRUE)
window_start <- max_date %m-% months(12) + days(1)

mls_recent <- mls |>
  filter(
    toupper(county) %in% pha_names,
    sales_date >= window_start, sales_date <= max_date,
    !is.na(sales_price), sales_price > 10000
  )

price_points <- function(df) {
  tibble(
    n_sales   = nrow(df),
    p25       = quantile(df$sales_price, 0.25),
    p50       = quantile(df$sales_price, 0.50),
    p75       = quantile(df$sales_price, 0.75),
    sqft_p50  = median(df$sqft_total, na.rm = TRUE)
  )
}

by_type <- mls_recent |>
  filter(property_type %in% c("Single Family", "Townhouse", "Condominium")) |>
  reframe(price_points(pick(everything())), .by = property_type) |>
  rename(structure_type = property_type)

all_types <- price_points(mls_recent) |> mutate(structure_type = "All types")

price_grid <- bind_rows(all_types, by_type) |>
  pivot_longer(c(p25, p50, p75), names_to = "price_tier", values_to = "price") |>
  mutate(price_tier = recode_values(
    price_tier,
    "p25" ~ "Entry-level (25th pct.)",
    "p50" ~ "Typical (median)",
    "p75" ~ "Upper (75th pct.)"
  ))

## 3. Income needed at each price point, current mortgage rate ----
rate_latest <- fred |> slice_max(month, n = 1) |> pull(rate)
rate_month  <- fred |> slice_max(month, n = 1) |> pull(month)

price_grid <- price_grid |>
  mutate(
    rate = rate_latest,
    income_needed = income_needed_for_price(price, rate_latest)
  )

## 4. Household-income CDF, pha region, 2024 (linear interpolation within bracket) ----
# B19001 brackets are closed except the top; its upper bound is a documented
# placeholder ($500,000) used only to interpolate a threshold that falls inside the
# open-ended "$200,000 or more" bracket -- none of this section's income thresholds
# do, but the fallback is included so the helper never silently mis-handles one.
brackets_raw <- inc |>
  filter(table == "B19001", year == 2024, geoid %in% pha, variable != "B19001_001") |>
  summarise(count = sum(estimate), .by = variable)

bracket_bounds <- tribble(
  ~variable,     ~lower,   ~upper,
  "B19001_002",       0,   9999,
  "B19001_003",   10000,  14999,
  "B19001_004",   15000,  19999,
  "B19001_005",   20000,  24999,
  "B19001_006",   25000,  29999,
  "B19001_007",   30000,  34999,
  "B19001_008",   35000,  39999,
  "B19001_009",   40000,  44999,
  "B19001_010",   45000,  49999,
  "B19001_011",   50000,  59999,
  "B19001_012",   60000,  74999,
  "B19001_013",   75000,  99999,
  "B19001_014",  100000, 124999,
  "B19001_015",  125000, 149999,
  "B19001_016",  150000, 199999,
  "B19001_017",  200000, 500000
)

income_brackets <- brackets_raw |> left_join(bracket_bounds, by = "variable")
stopifnot(!anyNA(income_brackets$lower))

pct_hh_at_or_above <- function(threshold, brackets = income_brackets) {
  total <- sum(brackets$count)
  above <- brackets |> filter(lower >= threshold) |> pull(count) |> sum()
  straddle <- brackets |> filter(lower < threshold, upper > threshold)
  if (nrow(straddle) == 1) {
    frac <- (straddle$upper - threshold) / (straddle$upper - straddle$lower + 1)
    above <- above + straddle$count * frac
  }
  above / total
}

price_grid <- price_grid |>
  mutate(pct_hh_at_or_above = map_dbl(income_needed, pct_hh_at_or_above))

## 5. Write the income table ----
# Every row carries an MLS sale-price statistic, so the CSV export gets the mls_
# prefix per the commit policy (MLS derivatives stay private, however aggregated).
write_rds(price_grid, "data/gaps_income_table.rds")
export_csv(price_grid, "mls_gaps_income_table")
message("Wrote data/gaps_income_table.rds (", nrow(price_grid), " rows)")

## 6. Starter-home gap: renter households vs. the entry-level threshold ----
entry_price <- price_grid |>
  filter(structure_type == "All types", price_tier == "Entry-level (25th pct.)") |>
  pull(price)
entry_income_needed <- income_needed_for_price(entry_price, rate_latest)

mfi_4p <- ami |> filter(household_size == 4, pct_ami == 100) |> pull(income_limit)
entry_ami_pct <- entry_income_needed / mfi_4p * 100

renter_by_band <- chas |>
  filter(geoid %in% pha, tenure == "Renter") |>
  summarise(households = sum(estimate), .by = income_band)

band_bounds <- tribble(
  ~income_band,   ~lower, ~upper,
  "0-30% AMI",         0,     30,
  "30-50% AMI",       30,     50,
  "50-80% AMI",       50,     80,
  "80-100% AMI",      80,    100,
  "100%+ AMI",       100,    200
)

renter_by_band <- renter_by_band |> left_join(band_bounds, by = "income_band")

renter_total <- sum(renter_by_band$households)
renter_above <- renter_by_band |> filter(lower >= entry_ami_pct) |> pull(households) |> sum()
straddle <- renter_by_band |> filter(lower < entry_ami_pct, upper > entry_ami_pct)
if (nrow(straddle) == 1) {
  frac <- (straddle$upper - entry_ami_pct) / (straddle$upper - straddle$lower)
  renter_above <- renter_above + straddle$households * frac
}
renter_pct_qualifying <- renter_above / renter_total

starter <- list(
  entry_price = entry_price,
  entry_sqft_p50 = price_grid |> filter(structure_type == "All types", price_tier == "Entry-level (25th pct.)") |>
    (\(x) mls_recent |> filter(sales_price <= entry_price * 1.02, sales_price >= entry_price * 0.98) |> pull(sqft_total) |> median(na.rm = TRUE))(),
  rate = rate_latest,
  rate_month = rate_month,
  income_needed = entry_income_needed,
  ami_pct = entry_ami_pct,
  renter_total_pha = renter_total,
  renter_qualifying = renter_above,
  renter_pct_qualifying = renter_pct_qualifying
) |> as_tibble()

renter_bands_out <- renter_by_band |> select(income_band, households) |>
  mutate(income_band = factor(income_band, levels = c(
    "0-30% AMI", "30-50% AMI", "50-80% AMI", "80-100% AMI", "100%+ AMI"
  )))

## 7. Write the starter-home outputs ----
# `starter` carries an MLS-derived entry price -> mls_ prefix. `renter_bands_out` is
# CHAS-only (no MLS content) and stays a plain public-source export.
write_rds(list(summary = starter, renter_bands = renter_bands_out), "data/gaps_starter.rds")
export_csv(starter, "mls_gaps_starter_summary")
export_csv(renter_bands_out, "gaps_starter_renter_bands")
message("Wrote data/gaps_starter.rds (entry price ", scales::dollar(entry_price), ")")

## 8. Validate ----
stopifnot(
  nrow(price_grid) == 4 * 3, # 4 structure-type rows (All types + 3 types) x 3 tiers
  all(price_grid$pct_hh_at_or_above >= 0, price_grid$pct_hh_at_or_above <= 1),
  all(price_grid$income_needed > 0),
  abs(sum(renter_by_band$households) - renter_total) < 1,
  renter_pct_qualifying >= 0, renter_pct_qualifying <= 1,
  nrow(renter_bands_out) == 5
)
message("Entry-level price (pha, trailing 12 mo.): ", scales::dollar(entry_price),
        " | income needed: ", scales::dollar(round(entry_income_needed)),
        " (", round(entry_ami_pct), "% of 4-person AMI)")
message("Renter households at/above that income (CHAS 2018-2022, pha): ",
        scales::percent(renter_pct_qualifying, accuracy = 1))
message("gaps.R validation passed.")
