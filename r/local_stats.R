# local_stats.R ----
# What:   One stats row per locality × metric: current value, 2022 reference,
#         formatted change. Feeds local-summaries.qmd.
# Source: data/*.rds — pep, acs_income, acs_tenure, acs_value_rent, acs_burden,
#         bps, psh, chas, wcoop. No API calls; all inputs must exist.
# Output: data/local_stats.rds   (+ data-out/local_stats.csv)

## 1. Setup ----
library(tidyverse)
library(scales)
library(janitor)
source("_common.R")   # rr, pha, secondary, ashland, virginia; export_csv()

dir.create("data", showWarnings = FALSE, recursive = TRUE)

# ---- Locality reference ----
# 9 localities in display order: 4 primary (alpha), 4 secondary (alpha), Ashland.
loc_ref <- tibble(
  geoid = c("51041", "51085", "51087", "51760",
            "51036", "51075", "51127", "51145",
            "5103368"),
  short_name = c("Chesterfield", "Hanover", "Henrico", "Richmond",
                 "Charles City", "Goochland", "New Kent", "Powhatan",
                 "Ashland"),
  group = c(rep("primary", 4), rep("secondary", 4), "ashland")
)

rr_geoids  <- unname(rr)
all_geoids <- c(rr_geoids, unname(ashland))

## 2. Metric skeleton ----
# Defines display order, labels, unit/format type, and change type for each metric.
metrics <- tribble(
  ~metric,                ~metric_label,                       ~fmt,       ~change_type,  ~comparison_label,
  "pop_current",          "Population",                        "count",    "pct",         "2022 vs. 2025",
  "net_migration",        "Net migration (2020–2025)",    "count",    "none",        "(cumulative)",
  "median_hh_income",     "Median household income",           "dollars",  "pct",         "2018–22 vs. 2020–24 ACS",
  "owner_rate",           "Homeownership rate",                "percent",  "pp",          "2018–22 vs. 2020–24 ACS",
  "med_home_value",       "Median home value",                 "dollars",  "pct",         "2018–22 vs. 2020–24 ACS",
  "med_gross_rent",       "Median gross rent",                 "dollars",  "pct",         "2018–22 vs. 2020–24 ACS",
  "burdened_renters",     "Cost-burdened renters",             "percent",  "pp",          "2018–22 vs. 2020–24 ACS",
  "burdened_owners",      "Cost-burdened homeowners",          "percent",  "pp",          "2018–22 vs. 2020–24 ACS",
  "permits_sf",           "Single-family permits",             "count",    "pct",         "2022 vs. 2024",
  "permits_mf",           "Multifamily permits",               "count",    "pct",         "2022 vs. 2024",
  "hud_units",            "HUD-assisted housing units",        "count",    "pct",         "2022 vs. 2024",
  "sev_burdened_renters", "Severely burdened renters (CHAS)",  "count",    "none",        "(2018–2022 vintage)",
  "pop_2050",             "Population projection (2050)",      "count",    "none",        "(Weldon Cooper)"
)

## 3. Source data ----

### 3a. PEP — population and migration ----
pep_raw <- read_rds("data/pep.rds") |>
  mutate(geoid = as.character(geoid))

pop_wide <- pep_raw |>
  filter(variable == "POPESTIMATE", year %in% c(2022, 2025)) |>
  select(geoid, year, value) |>
  pivot_wider(names_from = year, values_from = value, names_prefix = "yr")

net_mig <- pep_raw |>
  filter(variable == "NETMIG", year %in% 2021:2025) |>
  summarise(value_current = sum(value), .by = geoid)

### 3b. ACS income (B19013) ----
inc_wide <- read_rds("data/acs_income.rds") |>
  filter(table == "B19013", year %in% c(2022, 2024),
         geoid %in% all_geoids) |>
  select(geoid, year, estimate) |>
  pivot_wider(names_from = year, values_from = estimate, names_prefix = "yr")

### 3c. ACS tenure (B25003) — owner share ----
ten_wide <- read_rds("data/acs_tenure.rds") |>
  filter(tenure == "Owner", year %in% c(2022, 2024),
         geoid %in% rr_geoids) |>
  select(geoid, year, share) |>
  pivot_wider(names_from = year, values_from = share, names_prefix = "yr")

### 3d. ACS value and rent (B25077, B25064) ----
vr <- read_rds("data/acs_value_rent.rds") |>
  filter(year %in% c(2022, 2024), geoid %in% rr_geoids)

val_wide <- vr |>
  filter(measure == "Median home value") |>
  select(geoid, year, estimate) |>
  pivot_wider(names_from = year, values_from = estimate, names_prefix = "yr")

rent_wide <- vr |>
  filter(measure == "Median gross rent") |>
  select(geoid, year, estimate) |>
  pivot_wider(names_from = year, values_from = estimate, names_prefix = "yr")

### 3e. ACS burden (B25070 renters, B25091 owners) ----
burden_raw <- read_rds("data/acs_burden.rds") |>
  filter(burden %in% c("Cost-burdened", "Severely cost-burdened"),
         year %in% c(2022, 2024), geoid %in% rr_geoids)

burden_renter <- burden_raw |>
  filter(tenure == "Renter") |>
  summarise(share = sum(share, na.rm = TRUE), .by = c(geoid, year)) |>
  pivot_wider(names_from = year, values_from = share, names_prefix = "yr")

burden_owner <- burden_raw |>
  filter(tenure == "Owner") |>
  summarise(share = sum(share, na.rm = TRUE), .by = c(geoid, year)) |>
  pivot_wider(names_from = year, values_from = share, names_prefix = "yr")

### 3f. BPS — annual permits ----
bps_raw <- read_rds("data/bps.rds") |>
  mutate(geoid = as.character(geoid))

bps_sf <- bps_raw |>
  filter(structure == "Single-family", year %in% c(2022, 2024)) |>
  select(geoid, year, units) |>
  pivot_wider(names_from = year, values_from = units, names_prefix = "yr")

bps_mf <- bps_raw |>
  filter(structure == "Multifamily", year %in% c(2022, 2024)) |>
  select(geoid, year, units) |>
  pivot_wider(names_from = year, values_from = units, names_prefix = "yr")

### 3g. PSH — HUD-assisted units ----
psh_wide <- read_rds("data/psh.rds") |>
  mutate(geoid = as.character(geoid)) |>
  filter(program_label == "Summary of All HUD Programs",
         year %in% c(2022, 2024)) |>
  select(geoid, year, total_units) |>
  pivot_wider(names_from = year, values_from = total_units, names_prefix = "yr")

### 3h. CHAS — severely burdened renters ----
chas_sev <- read_rds("data/chas_cb.rds") |>
  mutate(geoid = as.character(geoid)) |>
  filter(tenure == "Renter", burden == "Severely cost-burdened") |>
  summarise(value_current = sum(estimate, na.rm = TRUE), .by = geoid)

### 3i. Weldon Cooper 2050 projection ----
wcoop_2050 <- read_rds("data/wcoop.rds") |>
  mutate(geoid = as.character(geoid)) |>
  filter(series == "total_population", year == 2050) |>
  select(geoid, value_current = estimate)

## 4. Assemble stats rows ----

rows <- bind_rows(
  # PEP
  pop_wide     |> transmute(geoid, metric = "pop_current",       value_current = yr2025, value_2022 = yr2022),
  net_mig      |> transmute(geoid, metric = "net_migration",      value_current,          value_2022 = NA_real_),
  # ACS
  inc_wide     |> transmute(geoid, metric = "median_hh_income",  value_current = yr2024, value_2022 = yr2022),
  ten_wide     |> transmute(geoid, metric = "owner_rate",         value_current = yr2024, value_2022 = yr2022),
  val_wide     |> transmute(geoid, metric = "med_home_value",     value_current = yr2024, value_2022 = yr2022),
  rent_wide    |> transmute(geoid, metric = "med_gross_rent",     value_current = yr2024, value_2022 = yr2022),
  burden_renter |> transmute(geoid, metric = "burdened_renters", value_current = yr2024, value_2022 = yr2022),
  burden_owner  |> transmute(geoid, metric = "burdened_owners",  value_current = yr2024, value_2022 = yr2022),
  # BPS
  bps_sf  |> transmute(geoid, metric = "permits_sf", value_current = yr2024, value_2022 = yr2022),
  bps_mf  |> transmute(geoid, metric = "permits_mf", value_current = yr2024, value_2022 = yr2022),
  # PSH
  psh_wide |> transmute(geoid, metric = "hud_units",  value_current = yr2024, value_2022 = yr2022),
  # Single-vintage
  chas_sev  |> transmute(geoid, metric = "sev_burdened_renters", value_current, value_2022 = NA_real_),
  wcoop_2050 |> transmute(geoid, metric = "pop_2050",             value_current, value_2022 = NA_real_)
)

## 5. Compute change, format, join metadata ----

local_stats <- loc_ref |>
  left_join(
    rows |>
      left_join(metrics, by = "metric") |>
      mutate(
        change_raw = case_when(
          change_type == "pct" & !is.na(value_2022) ~ (value_current - value_2022) / value_2022,
          change_type == "pp"  & !is.na(value_2022) ~ value_current - value_2022,
          TRUE ~ NA_real_
        ),
        value_current_fmt = case_when(
          fmt == "count"                   ~ label_comma(accuracy = 1)(round(value_current)),
          metric == "med_gross_rent"       ~ label_dollar(big.mark = ",")(round(value_current)),
          fmt == "dollars"                 ~ label_dollar(scale = 1e-3, suffix = "k", accuracy = 1)(value_current),
          fmt == "percent"                 ~ label_percent(accuracy = 1)(value_current)
        ),
        value_2022_fmt = case_when(
          is.na(value_2022)          ~ NA_character_,
          fmt == "count"             ~ label_comma(accuracy = 1)(round(value_2022)),
          metric == "med_gross_rent" ~ label_dollar(big.mark = ",")(round(value_2022)),
          fmt == "dollars"           ~ label_dollar(scale = 1e-3, suffix = "k", accuracy = 1)(value_2022),
          fmt == "percent"           ~ label_percent(accuracy = 1)(value_2022)
        ),
        change_fmt = case_when(
          is.na(change_raw)      ~ NA_character_,
          change_type == "pct"   ~ paste0(if_else(change_raw >= 0, "+", ""),
                                          label_percent(accuracy = 1)(change_raw)),
          change_type == "pp"    ~ paste0(if_else(change_raw >= 0, "+", ""),
                                          round(change_raw * 100, 1), " pp")
        ),
        metric = factor(metric, levels = metrics$metric)
      ),
    by = "geoid"
  ) |>
  drop_na(metric) |>
  arrange(match(geoid, loc_ref$geoid), metric)

## 6. Write output ----
write_rds(local_stats, "data/local_stats.rds")
export_csv(local_stats, "local_stats")
message("Wrote data/local_stats.rds + data-out/local_stats.csv (",
        nrow(local_stats), " rows, ",
        n_distinct(local_stats$geoid), " localities, ",
        n_distinct(local_stats$metric), " metrics)")

## 7. Validate ----
d <- read_rds("data/local_stats.rds")

stopifnot(
  nrow(d) > 0,
  n_distinct(d$geoid) == 9,
  all(all_geoids %in% d$geoid),
  all(!is.na(d$value_current[d$geoid != unname(ashland)])),
  "metric_label" %in% names(d),
  "value_current_fmt" %in% names(d)
)

message("local_stats.R validation passed.")
message("Row counts by locality:")
print(count(d, short_name, name = "n_metrics"))
message("\nNA summary (value_current / value_2022):")
print(d |> group_by(metric) |>
  summarise(
    n_cur_na  = sum(is.na(value_current)),
    n_2022_na = sum(is.na(value_2022))
  ) |>
  filter(n_cur_na > 0 | n_2022_na > 0))
