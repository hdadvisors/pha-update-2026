# acs_burden.R ----
# What:   ACS 5-year housing cost burden by tenure -- gross rent as a share of
#         household income (renters) and selected monthly owner costs as a
#         share of household income (owners, collapsed across mortgage
#         status) -- trended across three non-overlapping 5-year windows,
#         with the percentage bands collapsed into burden categories.
# Source: tidycensus ACS 5-year, survey years 2014/2019/2024.
# Tables: B25070 (gross rent as a percentage of household income, renters),
#         B25091 (mortgage status by selected monthly owner costs as a
#         percentage of household income, owners).
# Output: data/acs_burden.rds  (+ data-out/acs_burden.csv)

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

## 2. Pull + label helpers ----

# Pull one ACS table for the 8 rr counties plus the Virginia state row, tagging
# the pull year. This script's universe is rr + Virginia only -- no Ashland
# place pull, because burden shares for a sub-county place would ride on cells
# too small to survive the CV-30 suppression rule anyway.
pull_acs <- function(table, yr) {
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
}

# Build a variable -> label lookup from load_variables(), stripping the leading
# "Estimate" segment and rejoining the remaining "!!"-delimited parts.
build_labels <- function(table, yr) {
  vars <- load_variables(year = yr, dataset = "acs5", cache = TRUE) |>
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

# Collapse a labeled table pull into burden categories. The band is the final
# "!!" label segment; rows without a percentage band (the table total and the
# B25091 mortgage-status subtotals) are dropped before collapsing, so B25091's
# with-/without-mortgage bands stack into a single owner series. The band's
# lower bound (its first number) sorts every vintage's band set correctly:
# both tables split cleanly at 30 and 50 percent.
collapse_bands <- function(df, tenure) {
  df |>
    mutate(band = str_extract(label, "[^!]+$")) |>
    filter(str_detect(band, "percent|Not computed")) |>
    mutate(
      # "Not computed" has no number to parse; suppress that expected warning.
      lower = suppressWarnings(parse_number(band)),
      burden = case_when(
        str_detect(band, "Not computed") ~ "Not computed",
        lower >= 50                      ~ "Severely cost-burdened",
        lower >= 30                      ~ "Cost-burdened",
        .default                         = "Not cost-burdened"
      )
    ) |>
    summarise(
      estimate = sum(estimate),
      moe      = moe_sum(moe, estimate),
      .by = c(geoid, name, year, burden)
    ) |>
    mutate(tenure = tenure, .after = year)
}

## 3. Pull B25070 (renters) and B25091 (owners), 2014/2019/2024 ----
# Three non-overlapping 5-year windows, matching r/acs_income.R: overlapping
# 5-year ACS samples are not independent.
years <- c(2014, 2019, 2022, 2024)

message("Pulling B25070 (renters)...")
b25070_raw <- map(years, \(yr) {
  pull_acs("B25070", yr) |>
    left_join(build_labels("B25070", yr), by = "variable")
}) |>
  list_rbind()
message("B25070 pulled: ", nrow(b25070_raw), " rows")

message("Pulling B25091 (owners)...")
b25091_raw <- map(years, \(yr) {
  pull_acs("B25091", yr) |>
    left_join(build_labels("B25091", yr), by = "variable")
}) |>
  list_rbind()
message("B25091 pulled: ", nrow(b25091_raw), " rows")

## 4. Collapse bands into burden categories ----
renter <- collapse_bands(b25070_raw, "Renter")
owner  <- collapse_bands(b25091_raw, "Owner")

# Table totals ("_001" rows), kept aside as the validation benchmark.
totals <- bind_rows(
  b25070_raw |> filter(str_ends(variable, "_001")) |> mutate(tenure = "Renter"),
  b25091_raw |> filter(str_ends(variable, "_001")) |> mutate(tenure = "Owner")
) |>
  select(geoid, year, tenure, total = estimate)

## 5. Shares, CV, reliability ----
# Share is of *computed* households -- the three burden categories sum to the
# denominator; "Not computed" is excluded and carries an NA share.
acs_burden <- bind_rows(renter, owner) |>
  mutate(
    computed_total = sum(estimate[burden != "Not computed"]),
    share = if_else(burden == "Not computed", NA_real_,
                    estimate / computed_total),
    .by = c(geoid, year, tenure)
  ) |>
  mutate(
    # Same CV guard as r/acs_income.R: a zero/absent MOE on a positive estimate
    # is a controlled total (CV 0 -> High); only a zero/absent estimate leaves
    # the CV undefined.
    cv = case_when(
      is.na(estimate) | estimate <= 0 ~ NA_real_,
      is.na(moe) | moe == 0           ~ 0,
      .default = (moe / 1.645) / estimate * 100
    )
  ) |>
  flag_reliability() |>
  mutate(burden = factor(burden, levels = c(
    "Not cost-burdened", "Cost-burdened", "Severely cost-burdened", "Not computed"
  ))) |>
  arrange(year, tenure, geoid, burden) |>
  select(geoid, name, year, tenure, burden, estimate, moe, share, cv, reliability)

## 6. Write output ----
write_rds(acs_burden, "data/acs_burden.rds")
export_csv(acs_burden, "acs_burden")
message("Wrote data/acs_burden.rds + data-out/acs_burden.csv (",
        nrow(acs_burden), " rows)")

## 7. Validate ----
d <- read_rds("data/acs_burden.rds")

# Structure: 9 geographies x 3 years x 2 tenures x 4 categories, shares in
# [0,1], and category sums matching the pulled table totals (same vintage,
# same pull -- a structural identity, not a cross-source benchmark).
check <- d |>
  summarise(n_cat = n(), cat_sum = sum(estimate), .by = c(geoid, year, tenure)) |>
  left_join(totals, by = c("geoid", "year", "tenure"))

stopifnot(
  nrow(d) == 9 * 4 * 2 * 4,
  setequal(d$geoid, c(unname(rr), virginia)),
  setequal(d$year, years),
  setequal(d$tenure, c("Renter", "Owner")),
  all(check$n_cat == 4),
  all(check$cat_sum == check$total),
  all(d$share >= 0 & d$share <= 1, na.rm = TRUE),
  all(is.na(d$share) == (d$burden == "Not computed"))
)

# Regional 30%+ burden shares, 2024 window -- chapter sanity numbers, logged.
reg <- d |>
  filter(geoid %in% rr, year == 2024, burden != "Not computed") |>
  summarise(estimate = sum(estimate), .by = c(tenure, burden)) |>
  mutate(share = estimate / sum(estimate), .by = tenure)

reg_30 <- reg |>
  filter(burden != "Not cost-burdened") |>
  summarise(share = sum(share), .by = tenure)

message("Regional 30%+ burden share, 2020-2024 ACS: renter ",
        scales::percent(reg_30$share[reg_30$tenure == "Renter"], accuracy = 0.1),
        " | owner ",
        scales::percent(reg_30$share[reg_30$tenure == "Owner"], accuracy = 0.1))

# 2022 baseline: baseline_2022 comparison logged if available, never gated
# (2016-2020 and 2020-2024 ACS differ by construction).
baseline_path <- "data/baseline_2022.rds"
if (file.exists(baseline_path)) {
  b22 <- read_rds(baseline_path)
  key_col <- intersect(c("metric", "measure", "label"), names(b22))[1]
  if (!is.na(key_col)) {
    burden_rows <- b22 |>
      filter(str_detect(.data[[key_col]], regex("burden", ignore_case = TRUE)))
    message("baseline_2022 burden-keyed rows found: ", nrow(burden_rows),
            " -- compare against the regional shares above in the session log.")
  } else {
    message("baseline_2022 loaded but no metric-like key column found; ",
            "compare shares manually in the session log.")
  }
} else {
  message("data/baseline_2022.rds not found -- skipping 2022 baseline note.")
}

message("acs_burden.R validation passed.")
