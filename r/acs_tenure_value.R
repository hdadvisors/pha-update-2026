# acs_tenure_value.R ----
# What:   ACS 5-year tenure and housing-cost medians -- owner/renter household
#         counts and shares (B25003), median home value (B25077), and median
#         gross rent (B25064) -- for the ownership and rental chapters.
# Source: tidycensus ACS 5-year, three non-overlapping windows ending 2014,
#         2019, and 2024 (overlapping 5-year samples are not independent).
# Tables: B25003 (tenure: total/owner/renter), B25077 (median home value),
#         B25064 (median gross rent). Medians cannot be summed or averaged to
#         a regional figure, so the value/rent frame stays locality-level
#         (plus Virginia) only -- no regional aggregate is computed.
# Geos:   the 8 rr localities + Virginia.
# Output: data/acs_tenure.rds      (+ data-out/acs_tenure.csv)
#         data/acs_value_rent.rds  (+ data-out/acs_value_rent.csv)

## 1. Setup ----
library(tidyverse)
library(tidycensus)
library(janitor)
source("_common.R")   # rr / virginia; flag_reliability(); export_csv()

# .Renviron fallback -- R's HOME may not be ~/Documents, so the key file isn't
# always auto-loaded (CLAUDE.md API-keys gotcha). Load it only if unset.
if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- file.path(Sys.getenv("USERPROFILE"), "Documents", ".Renviron")
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}
message("CENSUS_API_KEY present: ", Sys.getenv("CENSUS_API_KEY") != "")

dir.create("data", showWarnings = FALSE, recursive = TRUE)

years <- c(2014, 2019, 2024)

## 2. Pull helper ----

# Pull one ACS table for the 8 rr counties + Virginia across the three trend
# years, compute the 0-100 CV, and tier reliability -- same treatment as
# r/acs_income.R. A zero/absent MOE on a positive estimate means a controlled
# estimate with no sampling error (CV 0 -> High); only an absent or zero
# estimate leaves the CV genuinely undefined.
pull_acs_trend <- function(table) {
  map(years, \(yr) {
    county <- get_acs(geography = "county", state = "VA", table = table,
                      year = yr, survey = "acs5", cache_table = TRUE) |>
      clean_names() |>
      filter(geoid %in% rr)

    state <- get_acs(geography = "state", state = "VA", table = table,
                     year = yr, survey = "acs5", cache_table = TRUE) |>
      clean_names() |>
      filter(geoid %in% virginia)

    bind_rows(county, state) |>
      mutate(year = yr)
  }) |>
    list_rbind() |>
    mutate(
      table = table,
      cv = case_when(
        is.na(estimate) | estimate <= 0 ~ NA_real_,
        is.na(moe) | moe == 0           ~ 0,
        .default = (moe / 1.645) / estimate * 100
      )
    ) |>
    flag_reliability()
}

## 3. B25003 -- Tenure (owner/renter counts and shares) ----
message("Pulling B25003 (2014, 2019, 2024)...")
b25003_raw <- pull_acs_trend("B25003")
message("B25003 pulled: ", nrow(b25003_raw), " rows")

# _001 total occupied, _002 owner-occupied, _003 renter-occupied. Share is the
# tenure count over the same-geography total for that year.
acs_tenure <- b25003_raw |>
  mutate(tenure = recode_values(
    variable,
    "B25003_001" ~ "Total",
    "B25003_002" ~ "Owner",
    "B25003_003" ~ "Renter",
    default = NA
  )) |>
  filter(!is.na(tenure)) |>
  mutate(share = estimate / estimate[tenure == "Total"], .by = c(geoid, year)) |>
  select(geoid, name, year, table, variable, tenure,
         estimate, moe, cv, reliability, share)

## 4. B25077 + B25064 -- Median home value and median gross rent ----
# Locality-level only: medians do not aggregate to a region (see header).
message("Pulling B25077 and B25064 (2014, 2019, 2024)...")
acs_value_rent <- map(c("B25077", "B25064"), pull_acs_trend) |>
  list_rbind() |>
  mutate(measure = recode_values(
    table,
    "B25077" ~ "Median home value",
    "B25064" ~ "Median gross rent",
    default = NA
  )) |>
  select(geoid, name, year, table, variable, measure,
         estimate, moe, cv, reliability)
message("B25077/B25064 pulled: ", nrow(acs_value_rent), " rows")

## 5. Write output ----
write_rds(acs_tenure, "data/acs_tenure.rds")
export_csv(acs_tenure, "acs_tenure")
message("Wrote data/acs_tenure.rds + data-out/acs_tenure.csv (",
        nrow(acs_tenure), " rows)")

write_rds(acs_value_rent, "data/acs_value_rent.rds")
export_csv(acs_value_rent, "acs_value_rent")
message("Wrote data/acs_value_rent.rds + data-out/acs_value_rent.csv (",
        nrow(acs_value_rent), " rows)")

## 6. Validate ----
ten <- read_rds("data/acs_tenure.rds")
vr  <- read_rds("data/acs_value_rent.rds")

no_all_na <- function(x) !all(is.na(x))
geos <- c(unname(rr), virginia)

# Structure only: all 9 geographies x 3 years in both frames, no all-NA
# estimate column, and owner + renter ~ total within each geography-year
# (exact for B25003, but allow a 1-household rounding slack).
tenure_check <- ten |>
  pivot_wider(id_cols = c(geoid, year), names_from = tenure,
              values_from = estimate) |>
  mutate(gap = abs(Owner + Renter - Total))

vr_cells <- vr |>
  distinct(geoid, year)

stopifnot(
  nrow(ten) > 0,
  nrow(vr) > 0,
  all(geos %in% ten$geoid),
  all(geos %in% vr$geoid),
  setequal(unique(ten$year), years),
  setequal(unique(vr$year), years),
  nrow(distinct(ten, geoid, year)) == length(geos) * length(years),
  nrow(vr_cells) == length(geos) * length(years),
  no_all_na(ten$estimate),
  no_all_na(vr$estimate),
  all(tenure_check$gap <= 1)
)

# Console figures for the session log / chapter sanity checks.
region_2024 <- ten |>
  filter(geoid %in% rr, year == 2024) |>
  summarise(hh = sum(estimate), .by = tenure)
owner_share <- region_2024$hh[region_2024$tenure == "Owner"] /
  region_2024$hh[region_2024$tenure == "Total"]
message("2024 regional owner share (8 rr localities): ",
        scales::percent(owner_share, accuracy = 0.1))

vr24 <- vr |> filter(geoid %in% rr, year == 2024)
message("2024 locality median home values: ",
        scales::dollar(min(vr24$estimate[vr24$table == "B25077"], na.rm = TRUE)),
        " to ",
        scales::dollar(max(vr24$estimate[vr24$table == "B25077"], na.rm = TRUE)))
message("2024 locality median gross rents: ",
        scales::dollar(min(vr24$estimate[vr24$table == "B25064"], na.rm = TRUE)),
        " to ",
        scales::dollar(max(vr24$estimate[vr24$table == "B25064"], na.rm = TRUE)))

message("acs_tenure_value.R validation passed.")
