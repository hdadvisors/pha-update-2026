# acs_demographics.R ----
# What:   ACS 5-year demographic profile -- age/sex, total population,
#         race/ethnicity, household type, average household size, and
#         seniors living alone -- for the demand chapter's population and
#         household-composition figures.
# Source: tidycensus ACS 5-year 2020-2024 (2024 endpoint; profile tables are
#         not trended -- see the phase-file decision on trend vs. profile
#         tables in .planning/phases/02-demand-data.md, Session 3B)
# Tables: B01001 (sex by age), B01003 (total population), B03002
#         (race/ethnicity), B11001 (household type), B25010 (average
#         household size), B11007 (seniors living alone)
# Output: data/acs_demographics.rds  (+ data-out/acs_demographics.csv)

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
# the pull year. bind_rows() rather than list_rbind() here because the three
# calls are positional, not a mapped list; list_rbind() is used below for the
# B19013-style year loop in the income script.
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
# n_parts is computed from the widest label in the table so
# separate_wider_delim() doesn't choke on tables whose variables nest to
# different depths (e.g. B01001's sex/age bands vs. B25010's single total).
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
# and shape to the frame's fixed column order. flag_reliability() default
# cv_col = cv matches the column name produced here, so no override is needed.
pull_table <- function(table, yr = 2024, dataset = "acs5") {
  labels <- build_labels(table, yr, dataset)

  pull_acs(table, yr) |>
    left_join(labels, by = "variable") |>
    mutate(
      table = table,
      # A missing or zero MOE on a positive estimate is not missing data. ACS controls
      # table totals to independent population estimates, so they carry no sampling
      # error and Census publishes no MOE for them -- the CV is 0, which tiers to High.
      # Treating those as NA flagged the four secondary counties' total population as
      # unrated, which is backwards: they are the most reliable cells in the frame.
      # Only an absent or zero estimate leaves the CV genuinely undefined.
      cv = case_when(
        is.na(estimate) | estimate <= 0 ~ NA_real_,
        is.na(moe) | moe == 0           ~ 0,
        .default = (moe / 1.645) / estimate * 100
      )
    ) |>
    flag_reliability() |>
    select(geoid, name, year, table, variable, label, estimate, moe, cv, reliability)
}

## 3. B01001 -- Sex by age ----
message("Pulling B01001...")
b01001 <- pull_table("B01001")
message("B01001 pulled: ", nrow(b01001), " rows")

## 4. B01003 -- Total population ----
message("Pulling B01003...")
b01003 <- pull_table("B01003")
message("B01003 pulled: ", nrow(b01003), " rows")

## 5. B03002 -- Race and ethnicity ----
message("Pulling B03002...")
b03002 <- pull_table("B03002")
message("B03002 pulled: ", nrow(b03002), " rows")

## 6. B11001 -- Household type ----
message("Pulling B11001...")
b11001 <- pull_table("B11001")
message("B11001 pulled: ", nrow(b11001), " rows")

## 7. B25010 -- Average household size ----
message("Pulling B25010...")
b25010 <- pull_table("B25010")
message("B25010 pulled: ", nrow(b25010), " rows")

## 8. B11007 -- Seniors living alone ----
message("Pulling B11007...")
b11007 <- pull_table("B11007")
message("B11007 pulled: ", nrow(b11007), " rows")

## 9. Combine into one tidy long frame ----
acs_demographics <- bind_rows(b01001, b01003, b03002, b11001, b25010, b11007)

## 10. Write output ----
write_rds(acs_demographics, "data/acs_demographics.rds")
export_csv(acs_demographics, "acs_demographics")
message("Wrote data/acs_demographics.rds + data-out/acs_demographics.csv (",
        nrow(acs_demographics), " rows)")

## 11. Validate ----
dem <- read_rds("data/acs_demographics.rds")

no_all_na <- function(x) !all(is.na(x))

# Structure only -- row counts, expected geographies, no all-NA column.
stopifnot(
  nrow(dem) > 0,
  all(rr %in% dem$geoid),
  virginia %in% dem$geoid,
  unname(ashland) %in% dem$geoid,
  no_all_na(dem$estimate),
  no_all_na(dem$moe),
  no_all_na(dem$cv),
  no_all_na(dem$reliability),
  setequal(unique(dem$table), c("B01001", "B01003", "B03002", "B11001", "B25010", "B11007"))
)

# No numeric same-vintage benchmark is asserted here. I do not have a
# confirmed, current published Virginia total-population figure for the
# 2020-2024 ACS 5-year estimates to stopifnot() against without guessing, and
# CLAUDE.md's validation semantics only permit a same-vintage stopifnot() when
# one is actually in hand (a HUD MFI, a Census table total, or the SOH deck).
# Structural checks above are the gate; Jonathan's console output is the
# place to eyeball the Virginia B01003 total against QuickFacts if desired.

# Reliability tier counts for secondary-locality + Ashland rows -- logged, not
# gated, because a genuinely small cell can legitimately land at Low or (if
# its estimate is 0) at NA. The phase Verify line asks the log entry to report
# this count.
secondary_ashland_geoids <- c(unname(secondary), unname(ashland))
sa_rel <- dem |> filter(geoid %in% secondary_ashland_geoids)
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

# 2022 baseline: baseline_2022's section == "demand" rows are net changes,
# projections, and derived counts (population_change_net, subfamilies_count,
# multigenerational_hh_share, adult_children_with_parents, etc.), not raw
# table levels from B01001/B01003/B03002/B11001/B25010/B11007. None of them
# map to a single current-vintage estimate in this frame without a second,
# older vintage pull this script does not make. Logging that explicitly
# rather than fabricating a comparison.
baseline_path <- "data/baseline_2022.rds"
if (file.exists(baseline_path)) {
  demand_2022 <- read_rds(baseline_path) |> filter(section == "demand")
  message("baseline_2022 demand rows available: ", nrow(demand_2022),
          " -- none map directly to a B01001/B01003/B03002/B11001/B25010/",
          "B11007 level; no 2022 delta computed for this script's tables.")
} else {
  message("data/baseline_2022.rds not found -- skipping 2022 baseline note.")
}

message("acs_demographics.R validation passed.")
message("  Virginia total population (B01003): ",
        format(dem$estimate[dem$geoid == virginia & dem$table == "B01003"], big.mark = ","))
