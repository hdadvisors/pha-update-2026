# bps.R ----
# What:   Building permits by structure type (single-family vs multifamily), annual,
#         2000-2025, for the 8 rr localities. Feeds ownership.qmd's production figure.
# Source: U.S. Census Bureau Building Permits Survey, county-level annual text files,
#         live fetch from https://www2.census.gov/econ/bps/County/co<year>a.txt
#         (CLAUDE.md data-fetch rule pre-approves this census.gov file-server fetch).
#         Manual fallback: download each co<year>a.txt into data/raw/bps/ by hand if the
#         live fetch fails, and point bps_url() at the local path instead.
# Layout: 2 header rows + 1 blank row, then comma-delimited: year, state fips, county
#         fips, region code, division code, county name, then bldgs/units/value for
#         1-unit, 2-units, 3-4 units, and 5+ units (cols 7-18), then a second "reported
#         only" (excludes imputation) copy of the same 12 columns (cols 19-30, unused
#         here -- cols 7-18 are the published totals). Verified identical 30-column
#         layout at both ends of the range (2000, 2024) before writing this loop.
# Output: data/bps.rds  (+ data-out/bps.csv)

## 1. Setup ----
library(tidyverse)
library(readr)
source("_common.R")   # rr; flag_reliability(); export_csv()

dir.create("data", showWarnings = FALSE, recursive = TRUE)

years <- 2000:2025

col_names <- c(
  "year", "fips_state", "fips_county", "region", "division", "name",
  "sf_bldgs", "sf_units", "sf_value",
  "two_bldgs", "two_units", "two_value",
  "three4_bldgs", "three4_units", "three4_value",
  "five_bldgs", "five_units", "five_value",
  paste0("rep_", 1:12)
)

bps_url <- function(yr) sprintf("https://www2.census.gov/econ/bps/County/co%da.txt", yr)

## 2. Pull each annual county file and keep the 8 rr localities ----
pull_year <- function(yr) {
  tryCatch(
    read_csv(bps_url(yr), skip = 3, col_names = col_names,
             col_types = cols(.default = "c"), progress = FALSE) |>
      mutate(geoid = paste0(fips_state, fips_county)) |>
      filter(geoid %in% rr) |>
      mutate(
        year = as.integer(year),
        name = str_squish(name),
        across(c(sf_bldgs, sf_units, sf_value,
                 two_bldgs, two_units, two_value,
                 three4_bldgs, three4_units, three4_value,
                 five_bldgs, five_units, five_value), as.numeric)
      ) |>
      select(year, geoid, name, sf_bldgs, sf_units, sf_value,
             two_bldgs, two_units, two_value,
             three4_bldgs, three4_units, three4_value,
             five_bldgs, five_units, five_value),
    error = function(e) {
      warning("BPS pull failed for ", yr, ": ", conditionMessage(e),
               " -- manual fallback: download co", yr, "a.txt into data/raw/bps/.")
      NULL
    }
  )
}

message("Pulling BPS county files, ", min(years), "-", max(years), "...")
raw <- map(years, pull_year) |> list_rbind()

stopifnot(nrow(raw) > 0)
failed_years <- setdiff(years, unique(raw$year))
if (length(failed_years) > 0) {
  message("BPS years not pulled (see warnings above): ", paste(failed_years, collapse = ", "))
}
message("BPS years pulled: ", n_distinct(raw$year), " of ", length(years))

## 3. Reshape to structure type: single-family vs multifamily (2+ units) ----
bps <- raw |>
  mutate(
    mf_bldgs = two_bldgs + three4_bldgs + five_bldgs,
    mf_units = two_units + three4_units + five_units,
    mf_value = two_value + three4_value + five_value
  ) |>
  select(year, geoid, name, sf_bldgs, sf_units, sf_value, mf_bldgs, mf_units, mf_value) |>
  pivot_longer(
    cols = -c(year, geoid, name),
    names_to = c("structure", ".value"),
    names_pattern = "(sf|mf)_(.*)"
  ) |>
  mutate(structure = recode_values(
    structure,
    "sf" ~ "Single-family",
    "mf" ~ "Multifamily",
    default = NA
  )) |>
  arrange(name, year, structure)

## 4. Write output ----
write_rds(bps, "data/bps.rds")
export_csv(bps, "bps")
message("Wrote data/bps.rds + data-out/bps.csv (", nrow(bps), " rows)")

## 5. Validate ----
d <- read_rds("data/bps.rds")
stopifnot(
  nrow(d) > 0,
  all(unname(rr) %in% d$geoid),
  setequal(unique(d$structure), c("Single-family", "Multifamily")),
  !anyNA(d$bldgs), !anyNA(d$units), !anyNA(d$value),
  all(d$units >= 0)
)

## 2022 baseline: sf_building_permits_annual, Chesterfield -- same metric, same years,
## not vintage-shifted (both are BPS calendar-year annual permits). Logged, not gated.
ches_sf <- d |>
  filter(geoid == unname(rr["chesterfield"]), structure == "Single-family",
         year %in% c(2010, 2020))
if (nrow(ches_sf) == 2) {
  message("2022 baseline check -- Chesterfield single-family permits: ",
          "2010 baseline 545, this pull ",
          ches_sf$units[ches_sf$year == 2010], "; ",
          "2020 baseline 2202, this pull ", ches_sf$units[ches_sf$year == 2020])
}

reg_recent <- d |>
  filter(geoid %in% rr, year %in% c(2020, max(d$year))) |>
  summarise(units = sum(units), .by = c(year, structure))
message("Regional permits by structure, 2020 vs ", max(d$year), ":")
print(reg_recent)

message("bps.R validation passed.")
