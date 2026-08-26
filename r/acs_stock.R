# acs_stock.R ----
# What:   ACS 5-year housing stock snapshot: total units (B25001), occupancy
#         and vacancy (B25002/B25004), structure type (B25024), year built
#         (B25034-36), and bedrooms (B25041/42). Single endpoint at 2024
#         (2020-2024 5-year estimates). No trend series.
# Source: tidycensus ACS 5-year, year = 2024.
# Tables: B25001  total housing units
#         B25002  occupancy status (total / occupied / vacant)
#         B25004  vacancy status by type (for rent / for sale / seasonal / etc.)
#         B25024  units in structure (structure type)
#         B25034  year structure built (detailed 10-category breakdown)
#         B25035  median year structure built
#         B25036  year structure built by tenure
#         B25041  bedrooms in occupied housing units
#         B25042  bedrooms by tenure (owner-occupied / renter-occupied)
# Frame:  One combined long frame, confirmed after pull. All nine tables share
#         the same column schema from get_acs(); all 10 geographies are present
#         for every table; variable counts range from 1 (B25001, B25035) to 23
#         (B25036) with no awkward joins in long format. Chapters filter by the
#         `table` column to access individual concept slices. Splitting by
#         concept group would add frames without removing any complexity --
#         the long format already isolates each group by table value.
#         See LOG.md 2026-08-26 for per-table shape diagnostics.
# Geos:   8 rr localities + Virginia + Ashland place (sumlev 160), matching
#         acs_income.R's geography setup.
# Output: data/acs_stock.rds  (+ data-out/acs_stock.csv)

## 1. Setup ----
library(tidyverse)
library(tidycensus)
library(janitor)
source("_common.R")   # rr / virginia / ashland; flag_reliability(); export_csv()

# .Renviron fallback -- R's HOME may not be ~/Documents (CLAUDE.md API-keys gotcha).
if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- file.path(Sys.getenv("USERPROFILE"), "Documents", ".Renviron")
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}
message("CENSUS_API_KEY present: ", Sys.getenv("CENSUS_API_KEY") != "")

dir.create("data", showWarnings = FALSE, recursive = TRUE)

yr     <- 2024
tables <- c("B25001", "B25002", "B25004", "B25024",
            "B25034", "B25035", "B25036", "B25041", "B25042")

## 2. Pull helper ----
# Pulls one ACS table across county (rr), state (Virginia), and place (Ashland)
# geographies and tags each row with year and table ID. CV is on a 0-100 scale
# for flag_reliability(). MOE-zero guard matches acs_income.R: a zero or absent
# MOE on a positive estimate is a controlled total with no sampling error, so
# CV == 0 and the cell tiers to High.
pull_acs <- function(table, yr) {
  county <- get_acs(geography = "county", state = "VA", table = table,
                    year = yr, survey = "acs5", cache_table = TRUE) |>
    clean_names() |>
    filter(geoid %in% rr)

  state <- get_acs(geography = "state", state = "VA", table = table,
                   year = yr, survey = "acs5", cache_table = TRUE) |>
    clean_names() |>
    filter(geoid %in% virginia)

  place <- get_acs(geography = "place", state = "VA", table = table,
                   year = yr, survey = "acs5", cache_table = TRUE) |>
    clean_names() |>
    filter(geoid %in% ashland)

  bind_rows(county, state, place) |>
    mutate(
      year  = yr,
      table = table,
      cv    = case_when(
        is.na(estimate) | estimate <= 0 ~ NA_real_,
        is.na(moe) | moe == 0           ~ 0,
        .default = (moe / 1.645) / estimate * 100
      )
    )
}

## 3. Pull all nine housing-stock tables ----
message("Pulling ", paste(tables, collapse = ", "), " (year = ", yr, ")...")
stock_raw <- map(tables, \(t) pull_acs(t, yr)) |> list_rbind()
message("All tables pulled: ", nrow(stock_raw), " rows across ",
        n_distinct(stock_raw$table), " tables")

## 4. Resolve variable labels from load_variables() ----
# Same pattern as acs_income.R's build_labels(): strip the leading "Estimate"
# segment, then rejoin the remaining !!-delimited parts as a readable label.
# n_parts computed per-table so each table gets its own column count.
build_labels <- function(table, yr) {
  vars <- load_variables(year = yr, dataset = "acs5", cache = TRUE) |>
    clean_names()

  tvars <- vars |> filter(str_starts(name, paste0(table, "_")))
  n_parts <- max(str_count(tvars$label, "!!")) + 1

  tvars |>
    separate_wider_delim(label, delim = "!!", names = paste0("part", seq_len(n_parts)),
                         too_few = "align_start") |>
    select(-part1) |>   # drop the leading "Estimate" segment
    unite("label", starts_with("part"), sep = "!!", na.rm = TRUE) |>
    transmute(variable = name, label)
}

message("Building variable labels from load_variables()...")
label_map <- map(tables, \(t) build_labels(t, yr)) |> list_rbind()
message("Labels resolved: ", nrow(label_map), " variable-label pairs")

## 5. Join labels and tier reliability ----
acs_stock <- stock_raw |>
  left_join(label_map, by = "variable") |>
  flag_reliability() |>
  select(geoid, name, year, table, variable, label, estimate, moe, cv, reliability)

## 6. Frame-structure diagnostics ----
# Row counts and geography coverage per table drive the one-vs-split frame
# decision recorded in the script header and LOG.md 2026-08-26.
message("\n-- Row counts and variable counts per table --")
acs_stock |>
  summarise(n_rows = n(), n_vars = n_distinct(variable), .by = table) |>
  arrange(table) |>
  mutate(out = paste0(table, ": ", n_rows, " rows, ", n_vars, " variables")) |>
  pull(out) |>
  walk(message)

expected_geos <- c(unname(rr), virginia, unname(ashland))
message("\n-- Geography coverage per table (expect ", length(expected_geos),
        " geographies each) --")
acs_stock |>
  summarise(n_geos = n_distinct(geoid), .by = table) |>
  arrange(table) |>
  mutate(out = paste0(table, ": ", n_geos, " geographies")) |>
  pull(out) |>
  walk(message)

## 7. Write output ----
write_rds(acs_stock, "data/acs_stock.rds")
export_csv(acs_stock, "acs_stock")
message("Wrote data/acs_stock.rds + data-out/acs_stock.csv (",
        nrow(acs_stock), " rows)")

## 8. Validate ----
d <- read_rds("data/acs_stock.rds")

# Structure: all expected geographies, all nine tables, no all-NA columns.
stopifnot(
  nrow(d) > 0,
  all(expected_geos %in% d$geoid),
  setequal(unique(d$table), tables),
  !all(is.na(d$estimate)),
  !all(is.na(d$cv)),
  !all(is.na(d$reliability))
)

# Same-vintage structural benchmark: B25002 total = occupied + vacant for every
# geography. Within-table arithmetic identity -- a gap > 1 unit indicates a
# pull or reshape defect, not a data-vintage mismatch, so this is a structural
# stopifnot() gate per CLAUDE.md validation semantics.
occ_check <- d |>
  filter(table == "B25002",
         variable %in% c("B25002_001", "B25002_002", "B25002_003")) |>
  pivot_wider(id_cols = geoid, names_from = variable, values_from = estimate) |>
  mutate(gap = abs(B25002_001 - (B25002_002 + B25002_003)))

message("\nB25002 balance (total = occupied + vacant), max gap: ",
        max(occ_check$gap, na.rm = TRUE), " units")
stopifnot(all(occ_check$gap <= 1, na.rm = TRUE))

# Log Virginia totals for a quick sanity read against Census QuickFacts or
# the SOH deck. No hard gate -- no same-vintage published benchmark was verified
# before this run.
va_units <- d |>
  filter(geoid == virginia, variable == "B25001_001") |>
  pull(estimate)
message("Virginia total housing units (B25001_001, 2020-2024 ACS 5-yr): ",
        format(va_units, big.mark = ","))

va_occ <- d |>
  filter(geoid == virginia, variable == "B25002_002") |>
  pull(estimate)
message("Virginia occupied housing units (B25002_002): ",
        format(va_occ, big.mark = ","))

# Reliability tier counts for secondary-locality and Ashland rows -- logged,
# not gated (small cells in detailed vacancy-type and bedroom-count categories
# for secondary localities may legitimately land at Low or NA).
secondary_ashland_geoids <- c(unname(secondary), unname(ashland))
sa_rel <- d |> filter(geoid %in% secondary_ashland_geoids)
message("Secondary/Ashland rows: ", nrow(sa_rel),
        " | High: ", sum(sa_rel$reliability == "High", na.rm = TRUE),
        " | Medium: ", sum(sa_rel$reliability == "Medium", na.rm = TRUE),
        " | Low: ", sum(sa_rel$reliability == "Low", na.rm = TRUE),
        " | NA reliability: ", sum(is.na(sa_rel$reliability)))

# 2022 baseline: the 2022 Framework records total units and vacancy rate at the
# region level; exact variable-level counts for B25001/B25002/B25024 were not
# published as discrete data rows. Baseline comparison is narrative in the
# chapter, not a stopifnot() gate.
if (file.exists("data/baseline_2022.rds")) {
  b22 <- read_rds("data/baseline_2022.rds") |> filter(section == "stock")
  message("baseline_2022 stock rows: ", nrow(b22),
          " -- compared narratively in chapter, not gated here.")
} else {
  message("data/baseline_2022.rds not found -- skipping 2022 baseline note.")
}

message("\nacs_stock.R validation passed.")
