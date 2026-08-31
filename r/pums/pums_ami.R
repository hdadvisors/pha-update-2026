# pums_ami.R ----
# What:   Bands every PUMS household into one of six AMI tiers using the HUD FY2026
#         income limits, then aggregates the banded households two ways with replicate
#         standard errors: by tenure and locality, and by tenure and householder race
#         group at the regional grain.
# Source: data/pums_hh.rds (r/pums/pums_prep.R), data/hud_ami.rds (r/hud_ami.R).
# Bands:  Below 30%, 30-50%, 50-80%, 80-100%, 100-120%, Above 120% AMI. Upper bounds are
#         inclusive, matching HUD's own reading of a published income limit. Households
#         with zero or negative income fold into Below 30% AMI.
# Income: hh_income is in 2024 dollars (ADJINC-adjusted in pums_prep.R). The HUD limits
#         are FY2026, so the comparison carries a one-year forward mismatch —
#         data-notes.qmd caveat.
# Geos:   Core-3 only. Chesterfield, Henrico, and Richmond city tile cleanly into whole
#         PUMAs; Hanover and the secondary counties never get a PUMS estimate
#         (METHODOLOGY.md, Geography and PUMS). A pooled regional row covers the three.
# Output: data/pums_ami.rds              household microdata + ami_band
#         data/pums_ami_bands.rds        (+ data-out/pums_ami_bands.csv)
#           band x tenure x locality, with the pooled regional row
#         data/pums_ami_race.rds         (+ data-out/pums_ami_race.csv)
#           band x tenure x race group, regional grain only
# Note:   Both aggregates carry a 0-100 `cv` column and no suppression. Tiering with
#         flag_reliability() and cell suppression happen in the chapter, matching how
#         r/acs_tenure_race.R hands off.

## 1. Setup ----

library(tidyverse)
library(tidycensus)
library(srvyr)
source("_common.R") # puma_locality; export_csv()

pums_hh <- read_rds("data/pums_hh.rds")
hud_ami <- read_rds("data/hud_ami.rds")

message("Households: ", nrow(pums_hh))
message("HUD AMI rows: ", nrow(hud_ami), " | area: ", unique(hud_ami$hud_area))
message("HUD 4-person MFI: $", format(unique(hud_ami$mfi_4person), big.mark = ","))

# One HUD area covers the whole region, so the thresholds depend on household size alone
# and no area join key is needed.
stopifnot(n_distinct(hud_ami$hud_area) == 1)

ami_levels <- c(
  "Below 30% AMI",
  "30-50% AMI",
  "50-80% AMI",
  "80-100% AMI",
  "100-120% AMI",
  "Above 120% AMI"
)

## 2. Reshape the income limits ----
# One row per household size, one column per threshold. The key is renamed to hh_size
# before the join: join_by(hh_size == household_size) would keep only one of the two
# columns and silently drop the other (CLAUDE.md known gotcha), so both sides carry the
# same name and the join is on equal-named keys.

ami_wide <- hud_ami |>
  select(hh_size = household_size, pct_ami, income_limit) |>
  mutate(pct_ami = paste0("limit_", pct_ami)) |>
  pivot_wider(names_from = pct_ami, values_from = income_limit)

message("\nHUD FY2026 income limits by household size (Richmond area):")
ami_wide |>
  as.data.frame() |>
  print(row.names = FALSE)

# Thresholds must rise with each AMI step at every household size, or the banding
# case_when() below would assign households to the wrong tier.
stopifnot(
  nrow(ami_wide) == 8,
  all(ami_wide$limit_30 < ami_wide$limit_50),
  all(ami_wide$limit_50 < ami_wide$limit_80),
  all(ami_wide$limit_80 < ami_wide$limit_100),
  all(ami_wide$limit_100 < ami_wide$limit_120)
)

## 3. Band households ----
# Inclusive upper bounds: a household at exactly the 30% limit is Below 30% AMI. Zero and
# negative incomes fold into the bottom band, which the leading condition handles before
# any threshold comparison.

pums_ami <- pums_hh |>
  left_join(ami_wide, by = join_by(hh_size)) |>
  mutate(
    ami_band = factor(
      case_when(
        hh_income <= limit_30 ~ ami_levels[1], # includes zero and negative income
        hh_income <= limit_50 ~ ami_levels[2],
        hh_income <= limit_80 ~ ami_levels[3],
        hh_income <= limit_100 ~ ami_levels[4],
        hh_income <= limit_120 ~ ami_levels[5],
        TRUE ~ ami_levels[6]
      ),
      levels = ami_levels
    )
  )

stopifnot(nrow(pums_ami) == nrow(pums_hh), !anyNA(pums_ami$ami_band))

## 4. Survey design ----
# Core-3 subpopulation, filtered after to_survey() so the replicate variance is computed
# on the subpopulation rather than on a pre-subset design.

design_core3 <- pums_ami |>
  to_survey(type = "housing", design = "rep_weights") |>
  filter(core3)

# `cv` arrives from survey_total() as a proportion. Rescale to 0-100 so downstream
# flag_reliability() reads it against the right 15/30 thresholds.
tidy_estimates <- function(df) {
  df |>
    ungroup() |>
    rename(estimate = households, se = households_se, cv = households_cv) |>
    mutate(cv = cv * 100)
}

# srvyr drops a grouping combination with no sampled households, which would leave the
# cross-tabs ragged and break a chapter's facet grid. complete() restores the full
# factor grid: an empty cell is a genuine zero estimate, and its CV stays NA because a
# coefficient of variation on zero is undefined.
fill_grid <- function(df, ...) {
  df |>
    complete(..., fill = list(estimate = 0, se = 0, cv = NA_real_))
}

## 5. Band by tenure and locality ----
# Three localities plus a pooled regional row. The pooled row is the grain the regional
# chapters read; the locality rows feed the local summaries.

region_label <- "Richmond region (core-3 PUMAs)"

bands_locality <- design_core3 |>
  group_by(locality, ami_band, tenure) |>
  summarise(households = survey_total(vartype = c("se", "cv"))) |>
  tidy_estimates()

bands_region <- design_core3 |>
  group_by(ami_band, tenure) |>
  summarise(households = survey_total(vartype = c("se", "cv"))) |>
  tidy_estimates() |>
  mutate(locality = region_label)

locality_levels <- c(region_label, unique(unname(puma_locality)))

pums_ami_bands <- bind_rows(bands_region, bands_locality) |>
  mutate(locality = factor(locality, levels = locality_levels)) |>
  fill_grid(locality, ami_band, tenure) |>
  # Share within each geography-tenure column, so a figure can plot band composition
  # without recomputing the denominator.
  mutate(
    total = sum(estimate),
    share = estimate / total,
    .by = c(locality, tenure)
  ) |>
  select(locality, ami_band, tenure, estimate, se, cv, total, share) |>
  arrange(locality, tenure, ami_band)

## 6. Band by tenure and householder race group ----
# Regional grain only. Locality-by-race-by-band would put nearly every cell past CV-30,
# and the suppression decision belongs to the chapter either way.

pums_ami_race <- design_core3 |>
  group_by(ami_band, tenure, race_group) |>
  summarise(households = survey_total(vartype = c("se", "cv"))) |>
  tidy_estimates() |>
  fill_grid(ami_band, tenure, race_group) |>
  mutate(
    total = sum(estimate),
    share = estimate / total,
    .by = c(race_group, tenure)
  ) |>
  select(race_group, ami_band, tenure, estimate, se, cv, total, share) |>
  arrange(race_group, tenure, ami_band)

## 7. Write output ----

write_rds(pums_ami, "data/pums_ami.rds")
message("\nWrote data/pums_ami.rds (", nrow(pums_ami), " households)")

write_rds(pums_ami_bands, "data/pums_ami_bands.rds")
export_csv(pums_ami_bands, "pums_ami_bands")
message(
  "Wrote data/pums_ami_bands.rds + data-out/pums_ami_bands.csv (",
  nrow(pums_ami_bands), " rows)"
)

write_rds(pums_ami_race, "data/pums_ami_race.rds")
export_csv(pums_ami_race, "pums_ami_race")
message(
  "Wrote data/pums_ami_race.rds + data-out/pums_ami_race.csv (",
  nrow(pums_ami_race), " rows)"
)

## 8. Validate ----

hh <- read_rds("data/pums_ami.rds")
b <- read_rds("data/pums_ami_bands.rds")
r <- read_rds("data/pums_ami_race.rds")

stopifnot(
  # Every household banded, thresholds joined
  !anyNA(hh$ami_band),
  !anyNA(hh$limit_30),
  setequal(levels(hh$ami_band), ami_levels),
  # Zero and negative incomes landed in the bottom band
  all(hh$ami_band[hh$hh_income <= 0] == ami_levels[1]),
  # Rectangular cross-tabs after fill_grid(): 4 geographies and 6 race groups, each
  # crossed with all 6 bands and both tenures.
  nrow(b) == n_distinct(b$locality) * length(ami_levels) * 2,
  nrow(r) == n_distinct(r$race_group) * length(ami_levels) * 2,
  n_distinct(b$locality) == 4,
  n_distinct(r$race_group) == 6,
  setequal(levels(b$ami_band), ami_levels),
  setequal(levels(r$ami_band), ami_levels),
  # No structural gaps
  !anyNA(b$estimate),
  !anyNA(r$estimate),
  # Shares sum to 1 within every geography-tenure and race-tenure column
  all(abs(tapply(b$share, list(b$locality, b$tenure), sum) - 1) < 1e-9),
  all(abs(tapply(r$share, list(r$race_group, r$tenure), sum) - 1) < 1e-9)
)

# Band totals must reconcile to the household total already benchmarked in pums_prep.R
# against ACS B25003. This is the one arithmetic gate that ties the banding back to a
# published figure.
region_total <- b |>
  filter(locality == region_label) |>
  pull(estimate) |>
  sum()

acs_core3_hh <- read_rds("data/acs_tenure.rds") |>
  filter(
    table == "B25003",
    tenure == "Total",
    year == max(year),
    geoid %in% c("51041", "51087", "51760")
  ) |>
  pull(estimate) |>
  sum()

message(
  "\nBanded households sum — PUMS: ", format(round(region_total), big.mark = ","),
  " | ACS B25003: ", format(acs_core3_hh, big.mark = ","),
  " | difference: ", round((region_total / acs_core3_hh - 1) * 100, 2), "%"
)

stopifnot(abs(region_total / acs_core3_hh - 1) < 0.03)

## 8a. Band distribution for the session log ----

message("\n-- Regional AMI band distribution by tenure --")
b |>
  filter(locality == region_label) |>
  mutate(
    out = paste0(
      tenure, " | ", ami_band, ": ", scales::comma(round(estimate)),
      " (", scales::percent(share, accuracy = 0.1), ", CV ", round(cv, 1), ")"
    )
  ) |>
  pull(out) |>
  walk(message)

# The headline gap-analysis input: renters at or below 80% AMI, cumulative.
renters_80 <- b |>
  filter(
    locality == region_label,
    tenure == "Renter",
    ami_band %in% ami_levels[1:3]
  )

message(
  "\nRenters at or below 80% AMI: ",
  format(round(sum(renters_80$estimate)), big.mark = ","),
  " of ", format(round(unique(renters_80$total)), big.mark = ","),
  " (", scales::percent(sum(renters_80$share), accuracy = 0.1), ")"
)

message("\n-- Locality AMI band distribution, renters only --")
b |>
  filter(locality != region_label, tenure == "Renter") |>
  mutate(
    out = paste0(
      locality, " | ", ami_band, ": ", scales::comma(round(estimate)),
      " (", scales::percent(share, accuracy = 0.1), ", CV ", round(cv, 1), ")"
    )
  ) |>
  pull(out) |>
  walk(message)

message("\n-- Share at or below 50% AMI by householder race group, renters --")
r |>
  filter(tenure == "Renter", ami_band %in% ami_levels[1:2]) |>
  summarise(
    share = sum(share),
    estimate = sum(estimate),
    total = unique(total),
    max_cv = max(cv, na.rm = TRUE),
    .by = race_group
  ) |>
  arrange(desc(share)) |>
  mutate(
    out = paste0(
      race_group, ": ", scales::percent(share, accuracy = 0.1),
      " (", scales::comma(round(estimate)), " of ", scales::comma(round(total)),
      " renter households, worst cell CV ", round(max_cv, 1), ")"
    )
  ) |>
  pull(out) |>
  walk(message)

# Cell reliability census, so the chapter knows how much survives a CV-30 screen.
message(
  "\nCells above CV-30 — bands frame: ", sum(b$cv > 30, na.rm = TRUE), " of ", nrow(b),
  " | race frame: ", sum(r$cv > 30, na.rm = TRUE), " of ", nrow(r)
)

# No same-vintage published AMI-banded benchmark exists for this region: HUD CHAS is
# 2018-2022, a different sample and a different set of income limits, so it is not a
# gate. The comparison is narrative in the chapter.
message("\nNo same-vintage AMI-banded benchmark: CHAS is 2018-2022 (logged, not gated).")

message("\npums_ami.R validation passed.")
