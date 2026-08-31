# pums_prep.R ----
# What:   Builds the analysis-ready household frame from the raw PUMS pull. Joins the 80
#         housing replicate weights, drops group-quarters and vacant records, adds the
#         locality/core-3 geography columns, and derives tenure, income, housing cost,
#         cost burden, householder race group, and household earner count.
# Source: data/pums_raw.rds and data/pums_wgt.rds (r/pums/pums_collect.R).
# Units:  One row per household (SPORDER == 1). Household estimates use WGTP with
#         WGTP1-80 for replicate standard errors. No person-level frame is produced —
#         the only person-level input needed downstream is the earner count, which is
#         collapsed to the household row in section 5.
# Output: data/pums_hh.rds
# No CSV: this is an intermediate microdata frame carrying 80 replicate weight columns.
#         export_csv() pairs live on the aggregated outputs (pums_ami.R, pums_gap.R).

## 1. Setup ----

library(tidyverse)
library(tidycensus)
library(srvyr)
source("_common.R") # puma_core3, puma_locality, pha

pums_raw <- read_rds("data/pums_raw.rds")
pums_wgt <- read_rds("data/pums_wgt.rds")

message("Raw person records: ", nrow(pums_raw))

## 2. Join housing replicate weights ----
# Take only the numbered replicate columns from the weights file. WGTP and PWGTP already
# arrive on pums_raw, so pulling them again would produce .x/.y suffixes. Keys are
# equal-named on both sides, which avoids the join_by() column-dropping gotcha.

rep_wgt_housing <- pums_wgt |>
  select(SERIALNO, SPORDER, matches("^WGTP\\d+$"))

pums_joined <- pums_raw |>
  left_join(rep_wgt_housing, by = join_by(SERIALNO, SPORDER))

stopifnot(nrow(pums_joined) == nrow(pums_raw))

## 3. Geography columns ----
# `locality` labels only the core-3 PUMAs, which tile cleanly into Chesterfield, Henrico,
# and Richmond city. The two mixed outer PUMAs (08501, 14501) get NA, because no locality
# can be isolated from them (METHODOLOGY.md, Geography and PUMS). `core3` is the filter
# flag every downstream script uses in place of re-listing PUMA codes.

pums_geo <- pums_joined |>
  mutate(
    locality = unname(puma_locality[PUMA]),
    core3 = PUMA %in% puma_core3,
    .after = PUMA
  )

## 4. Occupied-household universe ----
# TEN == "b" marks group-quarters persons and vacant units. Both are outside the
# household universe for every downstream estimate.

pums_occ <- pums_geo |>
  filter(TEN != "b")

message(
  "Dropped TEN == 'b' records: ", nrow(pums_geo) - nrow(pums_occ),
  " (group quarters and vacant units)"
)

## 5. Household earner count ----
# Computed on person rows before the collapse to householders. A person counts as an
# earner with at least $5,000 in wage plus self-employment income — the threshold carried
# over from the FAAR PUMS engine.

pums_earners <- pums_occ |>
  mutate(
    hh_earners = sum(coalesce(WAGP, 0) + coalesce(SEMP, 0) >= 5000),
    .by = SERIALNO
  )

## 6. Collapse to households ----

pums_hh_base <- pums_earners |>
  filter(SPORDER == 1)

message("Household records: ", nrow(pums_hh_base))

## 7. Derived household variables ----
# Dollar handling. A 5-year PUMS file reports HINCP, GRNTP, and SMOCP in the dollars of
# each record's own survey year, so every dollar level is put in 2024 dollars first:
# ADJINC for income, ADJHSG for housing cost, both stored as 7-digit integers that divide
# by 1e6 to give the factor. `hh_income` and `housing_cost` are the adjusted values, and
# every downstream script — AMI banding, the affordability test — reads those.
#
# Cost burden is the one exception. It is a ratio of two same-year quantities, so it is
# computed from the nominal values, where ADJINC and ADJHSG cancel exactly. Adjusting
# first would apply two slightly different factors to the numerator and denominator and
# pull the ratio away from Census's own GRPIP/OCPIP, which section 10a checks against.
#
# Cost burden is computed rather than read from GRPIP/OCPIP so the arithmetic is visible
# and identical across tenures.

tenure_levels <- c("Owner", "Renter")

tenure_detail_levels <- c(
  "Owner with mortgage",
  "Owner without mortgage",
  "Renter",
  "Renter, no cash rent"
)

cb_levels <- c("Not cost-burdened", "Cost-burdened", "Severely cost-burdened")

# ADJINC and ADJHSG both arrive as character, but the pinned tidycensus scales them
# inconsistently: ADJINC comes back already divided ("1.015250") while ADJHSG stays a raw
# 7-digit integer ("1000000"). Rescale only values still in integer form, so this holds
# under either representation.
adj_factor <- function(x) {
  f <- as.numeric(x)
  if_else(f > 100, f / 1e6, f)
}

pums_hh <- pums_hh_base |>
  mutate(
    # Tenure: TEN 1-2 owned, 3 rented for cash, 4 occupied without payment of rent
    tenure = factor(
      recode_values(
        TEN,
        c("1", "2") ~ "Owner",
        c("3", "4") ~ "Renter",
        default = NA_character_
      ),
      levels = tenure_levels
    ),
    tenure_detail = factor(
      recode_values(
        TEN,
        "1" ~ "Owner with mortgage",
        "2" ~ "Owner without mortgage",
        "3" ~ "Renter",
        "4" ~ "Renter, no cash rent",
        default = NA_character_
      ),
      levels = tenure_detail_levels
    ),
    # Household size, top-coded at 8 to match the HUD family-size adjustment table
    hh_size = pmin(NP, 8),
    # Per-record factors to 2024 dollars (see adj_factor() above)
    adj_inc = adj_factor(ADJINC),
    adj_hsg = adj_factor(ADJHSG),
    # Nominal (own survey year) dollars, kept for the cost-burden ratio
    hh_income_nominal = HINCP,
    housing_cost_nominal = if_else(tenure == "Renter", GRNTP, SMOCP),
    # 2024 dollars — what AMI banding and the affordability test read
    hh_income = round(hh_income_nominal * adj_inc),
    housing_cost = round(housing_cost_nominal * adj_hsg),
    # Cost burden ratio, from nominal dollars so the factors cancel. Undefined for zero or
    # negative income, and for renters paying no cash rent, whose housing cost is not a
    # share of income.
    cost_burden = if_else(
      hh_income_nominal > 0 & tenure_detail != "Renter, no cash rent",
      housing_cost_nominal / (hh_income_nominal / 12),
      NA_real_
    ),
    cb_label = factor(
      case_when(
        is.na(cost_burden) ~ NA_character_,
        cost_burden > 0.50 ~ "Severely cost-burdened",
        cost_burden > 0.30 ~ "Cost-burdened",
        TRUE ~ "Not cost-burdened"
      ),
      levels = cb_levels
    )
  )

## 8. Householder race and ethnicity ----
# The six report groups and their display order come from r/acs_tenure_race.R, so a PUMS
# figure and an ACS figure carry the same axis. The collapse rule matches too: White
# alone gives way to White non-Hispanic, and American Indian or Alaska Native, Native
# Hawaiian or Pacific Islander, and some other race combine into "Another race" because
# each is too small to report on its own.
#
# One definitional difference from acs_tenure_race_group.rds, which data-notes.qmd
# carries: the nine B25003 letter tables overlap, so a Hispanic Black householder counts
# in both "Black" and "Hispanic or Latino" there. A PUMS household is a single row and
# cannot hold an overlapping classification, so HHLDRHISP takes precedence here and the
# five race groups are all non-Hispanic. PUMS group shares therefore sum to 100%, and
# the ACS ones do not. HHLDRHISP "01" is the not-Hispanic code.

group_levels <- c(
  "White, non-Hispanic",
  "Black",
  "Hispanic or Latino",
  "Asian",
  "Multiracial",
  "Another race"
)

pums_hh <- pums_hh |>
  mutate(
    race_group = factor(
      if_else(
        HHLDRHISP != "01",
        "Hispanic or Latino",
        recode_values(
          HHLDRRAC1P,
          "1" ~ "White, non-Hispanic",
          "2" ~ "Black",
          "6" ~ "Asian",
          "9" ~ "Multiracial",
          c("3", "4", "5", "7", "8") ~ "Another race",
          default = NA_character_
        )
      ),
      levels = group_levels
    )
  )

## 9. Write output ----

write_rds(pums_hh, "data/pums_hh.rds")
message("Wrote data/pums_hh.rds")

## 10. Validate ----

d <- read_rds("data/pums_hh.rds")

stopifnot(
  nrow(d) > 0,
  # One row per household record
  !any(duplicated(d$SERIALNO)),
  all(d$SPORDER == 1),
  # No group-quarters or vacant records survived
  !any(d$TEN == "b"),
  # Replicate weights joined for every household
  sum(str_detect(names(d), "^WGTP\\d+$")) == 80,
  !anyNA(d$WGTP),
  !anyNA(d$WGTP1),
  # Every household has a tenure and a household size in range
  !anyNA(d$tenure),
  !anyNA(d$tenure_detail),
  all(between(d$hh_size, 1, 8)),
  # Geography columns behave: core-3 rows are labeled, mixed outer PUMAs are not
  all(!is.na(d$locality[d$core3])),
  all(is.na(d$locality[!d$core3])),
  setequal(unique(d$locality[d$core3]), unname(puma_locality)),
  # Dollar adjustment applied for every household, spanning more than one survey year
  !anyNA(d$adj_inc),
  !anyNA(d$adj_hsg),
  n_distinct(d$adj_inc) > 1,
  all(between(d$adj_inc, 0.9, 1.5)),
  all(between(d$adj_hsg, 0.9, 1.5)),
  # Every household lands in exactly one of the six report groups
  !anyNA(d$race_group),
  setequal(levels(d$race_group), group_levels)
)

## 10a. Cost-burden cross-check against the Census-computed ratios ----
# GRPIP and OCPIP are integer percentages, top-coded at 101. Comparing only the
# un-top-coded rows, the derived ratio should match to within a rounding point.

cb_check <- d |>
  mutate(
    census_pct = if_else(tenure == "Renter", GRPIP, OCPIP),
    derived_pct = cost_burden * 100
  ) |>
  filter(!is.na(census_pct), census_pct < 101, !is.na(derived_pct)) |>
  mutate(gap = abs(derived_pct - census_pct))

message(
  "\nCost-burden cross-check on ", nrow(cb_check), " households — ",
  "max gap vs GRPIP/OCPIP: ", round(max(cb_check$gap), 2), " points; ",
  "share within 1 point: ", round(mean(cb_check$gap <= 1) * 100, 1), "%"
)

stopifnot(mean(cb_check$gap <= 1) > 0.99)

## 10b. Weighted household total against the published ACS table ----
# Same-vintage benchmark: B25003_001 for the three core-3 localities, 2020-2024 ACS.
# PUMS is a subsample of the same survey, so the totals should agree closely. A 3%
# tolerance covers the subsampling difference without letting a real error through.

survey_hh <- d |>
  to_survey(type = "housing", design = "rep_weights")

acs_core3_hh <- read_rds("data/acs_tenure.rds") |>
  filter(
    table == "B25003",
    tenure == "Total",
    year == max(year),
    geoid %in% c("51041", "51087", "51760")
  ) |>
  pull(estimate) |>
  sum()

pums_core3_hh <- survey_hh |>
  filter(core3) |>
  summarise(households = survey_total(vartype = "se"))

message(
  "\nCore-3 households — PUMS: ",
  format(round(pums_core3_hh$households), big.mark = ","),
  " (SE ", format(round(pums_core3_hh$households_se), big.mark = ","), ") | ",
  "ACS B25003: ", format(acs_core3_hh, big.mark = ","), " | ",
  "difference: ",
  round((pums_core3_hh$households / acs_core3_hh - 1) * 100, 2), "%"
)

stopifnot(abs(pums_core3_hh$households / acs_core3_hh - 1) < 0.03)

## 10c. Composition diagnostics for the session log ----

message("\nHouseholds by tenure detail (weighted, core-3):")
survey_hh |>
  filter(core3) |>
  group_by(tenure_detail) |>
  summarise(households = survey_total(vartype = "cv")) |>
  # survey_total() reports the CV as a proportion; rescale to 0-100 so the printed
  # values read on the same scale as flag_reliability()'s 15/30 thresholds.
  mutate(
    households_cv = households_cv * 100,
    across(where(is.numeric), \(x) round(x, 1))
  ) |>
  as.data.frame() |>
  print(row.names = FALSE)

message("\nHouseholds by cost burden and tenure (weighted, core-3):")
survey_hh |>
  filter(core3, !is.na(cb_label)) |>
  group_by(tenure, cb_label) |>
  summarise(households = survey_total(vartype = "cv")) |>
  # survey_total() reports the CV as a proportion; rescale to 0-100 so the printed
  # values read on the same scale as flag_reliability()'s 15/30 thresholds.
  mutate(
    households_cv = households_cv * 100,
    across(where(is.numeric), \(x) round(x, 1))
  ) |>
  as.data.frame() |>
  print(row.names = FALSE)

message("\nHouseholds by householder race group (weighted, core-3):")
survey_hh |>
  filter(core3) |>
  group_by(race_group) |>
  summarise(households = survey_total(vartype = "cv")) |>
  # survey_total() reports the CV as a proportion; rescale to 0-100 so the printed
  # values read on the same scale as flag_reliability()'s 15/30 thresholds.
  mutate(
    households_cv = households_cv * 100,
    across(where(is.numeric), \(x) round(x, 1))
  ) |>
  as.data.frame() |>
  print(row.names = FALSE)

message("\nHousehold earner count distribution (unweighted records):")
d |>
  count(hh_earners, name = "records") |>
  as.data.frame() |>
  print(row.names = FALSE)

message("\nMissing cost_burden (zero/negative income or no cash rent): ", sum(is.na(d$cost_burden)))

# The inflation adjustment, so the log records how much it moved incomes.
message("\nADJINC factors present (one per survey year):")
d |>
  count(adj_inc, name = "households") |>
  arrange(adj_inc) |>
  as.data.frame() |>
  print(row.names = FALSE)

message(
  "\nMedian household income — nominal: $",
  format(median(d$hh_income_nominal[d$hh_income_nominal > 0]), big.mark = ","),
  " | 2024 dollars: $",
  format(median(d$hh_income[d$hh_income_nominal > 0]), big.mark = ","),
  " | lift: ",
  round(
    (median(d$hh_income[d$hh_income_nominal > 0]) /
      median(d$hh_income_nominal[d$hh_income_nominal > 0]) - 1) * 100,
    1
  ),
  "%"
)

message("\npums_prep.R validation passed.")
