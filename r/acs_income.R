# acs_income.R ----
# What:   ACS 5-year income and poverty profile -- median household income
#         (trended across three non-overlapping 5-year windows), household
#         income distribution, and poverty status -- for the demand
#         chapter's household-income figures.
# Source: tidycensus ACS 5-year, survey table years 2014/2019/2024 for the
#         B19013 trend, 2024 endpoint for the profile tables. S1701 is a
#         Census subject table (get_acs() routes "S"-prefixed tables to the
#         subject dataset automatically; only load_variables() needs an
#         explicit dataset = "acs5/subject" argument).
# Tables: B19013 (median household income, trend), B19001 (household income
#         distribution), S1701 (poverty status). B25074 (income by rent
#         burden) is explicitly NOT pulled here -- it belongs to
#         r/acs_costs.R in Phase 3/5 per the PLAN.md Section 5 / phase-file
#         decision confirming this split.
# Output: data/acs_income.rds  (+ data-out/acs_income.csv)

## 1. Setup ----
library(tidyverse)
library(tidycensus)
library(janitor)
source("_common.R")   # rr / virginia / ashland; flag_reliability(); export_csv()

# .Renviron fallback -- R's HOME may not be ~/Documents, so the key file isn't
# always auto-loaded (CLAUDE.md API-keys gotcha). Load it only if unset.
if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- file.path(Sys.getenv("USERPROFILE"), "Documents", ".Renviron")
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}
message("CENSUS_API_KEY present: ", Sys.getenv("CENSUS_API_KEY") != "")

dir.create("data", showWarnings = FALSE, recursive = TRUE)

## 2. Pull + label helpers ----

# Pull one ACS table across the three geography levels this project uses --
# the 8 rr counties, Virginia, and the Ashland place (sumlev 160) -- and tag
# the pull year.
pull_acs <- function(table, yr, survey = "acs5") {
  county <- get_acs(geography = "county", state = "VA", table = table,
                     year = yr, survey = survey, cache_table = TRUE) |>
    clean_names() |>
    filter(geoid %in% rr)

  state <- get_acs(geography = "state", state = "VA", table = table,
                    year = yr, survey = survey, cache_table = TRUE) |>
    clean_names() |>
    filter(geoid %in% virginia)

  place <- get_acs(geography = "place", state = "VA", table = table,
                    year = yr, survey = survey, cache_table = TRUE) |>
    clean_names() |>
    filter(geoid %in% ashland)

  bind_rows(county, state, place) |>
    mutate(year = yr)
}

# Build a variable -> label lookup from load_variables(), stripping the
# leading "Estimate" segment and rejoining the remaining "!!"-delimited parts.
# S1701 lives in the "acs5/subject" dataset for load_variables() even though
# get_acs() takes it the same way as a detail table via table = "S1701".
build_labels <- function(table, yr, dataset = "acs5") {
  vars <- load_variables(year = yr, dataset = dataset, cache = TRUE) |>
    clean_names()

  tvars <- vars |> filter(str_starts(name, paste0(table, "_")))
  n_parts <- max(str_count(tvars$label, "!!")) + 1

  tvars |>
    separate_wider_delim(label, delim = "!!", names = paste0("part", seq_len(n_parts)),
                          too_few = "align_start") |>
    select(-part1) |>                                   # drop the "Estimate" segment
    unite("label", starts_with("part"), sep = "!!", na.rm = TRUE) |>
    transmute(variable = name, label)
}

# Pull a table, join its label lookup, compute the 0-100 CV, tier reliability,
# and shape to the frame's fixed column order.
pull_table <- function(table, yr = 2024, dataset = "acs5") {
  labels <- build_labels(table, yr, dataset)

  pull_acs(table, yr) |>
    left_join(labels, by = "variable") |>
    mutate(
      table = table,
      # A missing or zero MOE on a positive estimate is not missing data. ACS controls
      # table totals to independent population estimates, so they carry no sampling
      # error and Census publishes no MOE for them -- the CV is 0, which tiers to High.
      # Only an absent or zero estimate leaves the CV genuinely undefined. See
      # r/acs_demographics.R for the finding this guard came from.
      cv = case_when(
        is.na(estimate) | estimate <= 0 ~ NA_real_,
        is.na(moe) | moe == 0           ~ 0,
        .default = (moe / 1.645) / estimate * 100
      )
    ) |>
    flag_reliability() |>
    select(geoid, name, year, table, variable, label, estimate, moe, cv, reliability)
}

## 3. B19013 -- Median household income (trend) ----
# Three non-overlapping 5-year windows ending 2014, 2019, and 2024, per the
# phase-file decision: overlapping 5-year ACS samples are not independent, so
# every available endpoint would overstate how much of a 15-point series is
# real movement versus shared sample.
message("Pulling B19013 (2014, 2019, 2022, 2024)...")
b19013 <- map(c(2014, 2019, 2022, 2024), \(yr) pull_table("B19013", yr)) |>
  list_rbind()
message("B19013 pulled: ", nrow(b19013), " rows across ",
        n_distinct(b19013$year), " years")

## 4. B19001 -- Household income distribution ----
# Profile table; 2024 is the anchor, not trended, per the phase-file decision
# that only B19013 is a trend table in this session's scope.
message("Pulling B19001...")
b19001 <- pull_table("B19001")
message("B19001 pulled: ", nrow(b19001), " rows")

## 5. S1701 -- Poverty status ----
# Subject table -- load_variables() needs dataset = "acs5/subject" to resolve
# the S1701 variable list; get_acs() itself takes table = "S1701" like any
# other table id.
message("Pulling S1701...")
s1701 <- pull_table("S1701", dataset = "acs5/subject")
message("S1701 pulled: ", nrow(s1701), " rows")

## 6. Combine into one tidy long frame ----
acs_income <- bind_rows(b19013, b19001, s1701)

## 7. Write output ----
write_rds(acs_income, "data/acs_income.rds")
export_csv(acs_income, "acs_income")
message("Wrote data/acs_income.rds + data-out/acs_income.csv (",
        nrow(acs_income), " rows)")

## 8. Validate ----
inc <- read_rds("data/acs_income.rds")

no_all_na <- function(x) !all(is.na(x))

# Structure only -- row counts, expected geographies, expected years, no
# all-NA column.
stopifnot(
  nrow(inc) > 0,
  all(rr %in% inc$geoid),
  virginia %in% inc$geoid,
  unname(ashland) %in% inc$geoid,
  no_all_na(inc$estimate),
  no_all_na(inc$moe),
  no_all_na(inc$cv),
  no_all_na(inc$reliability),
  setequal(unique(inc$table), c("B19013", "B19001", "S1701")),
  setequal(inc$year[inc$table == "B19013"], c(2014, 2019, 2022, 2024))
)

# No numeric same-vintage benchmark is asserted here. I do not have a
# confirmed, current published Virginia median-household-income figure for
# the 2020-2024 ACS 5-year estimates to stopifnot() against without guessing.
# Structural checks above are the gate; Jonathan's console output is the
# place to eyeball the Virginia B19013 2024-window estimate against
# QuickFacts or the SOH deck if desired.

# Reliability tier counts for secondary-locality + Ashland rows -- logged, not
# gated, per the same reasoning as acs_demographics.R: a genuinely small cell
# can legitimately land at Low or (if its estimate is 0) at NA.
secondary_ashland_geoids <- c(unname(secondary), unname(ashland))
sa_rel <- inc |> filter(geoid %in% secondary_ashland_geoids)
message("Secondary/Ashland rows: ", nrow(sa_rel),
        " | Low: ", sum(sa_rel$reliability == "Low", na.rm = TRUE),
        " | NA reliability: ", sum(is.na(sa_rel$reliability)),
        " (estimate absent: ", sum(is.na(sa_rel$estimate)),
        ", estimate zero: ", sum(!is.na(sa_rel$estimate) & sa_rel$estimate <= 0), ")")

# No row should be NA for any reason other than an absent or zero estimate. A NA that
# survives this check means the CV guard above missed a case -- most likely a new
# no-MOE condition -- and the tier would silently drop cells from every chart.
stopifnot(all(!is.na(sa_rel$reliability) |
                is.na(sa_rel$estimate) | sa_rel$estimate <= 0))

# 2022 baseline: baseline_2022 has no "demand" rows keyed to median household
# income, income distribution, or poverty levels -- its demand section
# records population and household-count changes, not income. No comparison
# is fabricated; the closest baseline_2022 income figures
# (median_household_income_owner / _renter) live under section == "local"
# for individual localities, not this script's region-wide B19013 pull, and
# are 2020-ACS-vintage single-year figures that Session 3B's tables were not
# scoped to reproduce.
baseline_path <- "data/baseline_2022.rds"
if (file.exists(baseline_path)) {
  demand_2022 <- read_rds(baseline_path) |> filter(section == "demand")
  message("baseline_2022 demand rows available: ", nrow(demand_2022),
          " -- none map directly to B19013/B19001/S1701; no 2022 delta ",
          "computed for this script's tables.")
} else {
  message("data/baseline_2022.rds not found -- skipping 2022 baseline note.")
}

message("acs_income.R validation passed.")
message("  Virginia median household income, 2020-2024 (B19013): ",
        format(inc$estimate[inc$geoid == virginia & inc$table == "B19013" &
                             inc$year == 2024], big.mark = ","))
