# chas.R ----
# What:   Two related HUD CHAS outputs. chas_cb: cost burden by household income
#         (AMI band) and tenure -- Table 7, marginalized over household type. Gives
#         the burden-by-AMI-band cut the ACS B25070/B25091 tables (r/acs_burden.R)
#         cannot support, and covers the four secondary localities and Ashland at a
#         reliable cut where ACS renter burden cells are Low reliability.
#         chas_gap: renter-shortage and cost-burden figures for a fact-sheet
#         infographic -- lowest-income renters vs. homes priced for them, who
#         occupies those homes, and the burden rate among low-income renters --
#         from Tables 8, 18C, and 17B. See METHODOLOGY.md for the full writeup,
#         including the RHUD/HAMFI household-size caveat and the "not computed"
#         and vacant-unit handling.
# Source: HUD CHAS 2018-2022 5-year table extracts, pre-staged under
#         data/raw/chas/ (Tables 7, 8, 18C, 17B for both geographies below).
#         Column mapping is resolved from the data dictionary rather than
#         hardcoded -- data/raw/chas/CHAS-data-dictionary-18-22.xlsx.
# Tables: Table 7   (household income x household type x cost burden, by tenure).
#         Table 8   (tenure x household income x cost burden x substandard housing).
#         Table 18C (units in structure x renter affordability x household income;
#                    renter-occupied universe).
#         Table 17B (units in structure x renter affordability; vacant-for-rent
#                    universe).
# Geos:   the 8 rr counties (sumlevel 050, data/raw/chas/050/050/) plus Ashland
#         town (sumlevel 160, data/raw/chas/160/160/, place FIPS 03368).
# Output: data/chas_cb.rds  (+ data-out/chas_cb.csv)  -- Table 7 cost burden.
#         data/chas_gap.rds (+ data-out/chas_gap.csv) -- Tables 8/18C/17B shortage
#         and burden figures, long/tidy (one row per geoid x measure).

## 1. Setup ----
library(tidyverse)
library(readxl)
library(janitor)
source("_common.R")   # rr / ashland; flag_reliability(); export_csv()

dir.create("data", showWarnings = FALSE, recursive = TRUE)

dict_path <- "data/raw/chas/CHAS-data-dictionary-18-22.xlsx"

raw_path <- function(table) {
  list(
    county = paste0("data/raw/chas/050/050/", table, ".csv"),
    place  = paste0("data/raw/chas/160/160/", table, ".csv")
  )
}

t7_path   <- raw_path("Table7")
t8_path   <- raw_path("Table8")
t18c_path <- raw_path("Table18C")
t17b_path <- raw_path("Table17B")

stopifnot(
  file.exists(dict_path),
  file.exists(t7_path$county),   file.exists(t7_path$place),
  file.exists(t8_path$county),   file.exists(t8_path$place),
  file.exists(t18c_path$county), file.exists(t18c_path$place),
  file.exists(t17b_path$county), file.exists(t17b_path$place)
)

# Shared geography reader: county table filtered to the 8 rr FIPS, place table
# filtered to Ashland, bound together and coerced to numeric. Reused across all
# four CHAS tables below.
read_chas_geo <- function(paths, est_cols, moe_cols) {
  cols_needed <- c(est_cols, moe_cols)

  county <- read_csv(paths$county, col_types = cols(.default = "c")) |>
    clean_names() |>
    mutate(fips = str_sub(geoid, -5)) |>
    filter(fips %in% rr) |>
    mutate(name = str_remove(name, ", Virginia$")) |>
    select(fips, name, all_of(cols_needed))

  place <- read_csv(paths$place, col_types = cols(.default = "c")) |>
    clean_names() |>
    filter(st == "51", place == str_sub(unname(ashland), -5)) |>
    mutate(fips = unname(ashland), name = str_remove(name, ", Virginia$")) |>
    select(fips, name, all_of(cols_needed))

  bind_rows(county, place) |>
    mutate(across(-c(fips, name), as.numeric))
}

# Reshape one raw table to long (fips, name, est_col -> estimate; moe_col -> moe),
# then join back its dictionary labels. Reused for every dictionary below.
chas_long <- function(raw, dict) {
  est_long <- raw |>
    select(fips, name, all_of(dict$est_col)) |>
    pivot_longer(-c(fips, name), names_to = "est_col", values_to = "estimate")

  moe_long <- raw |>
    select(fips, name, all_of(dict$moe_col)) |>
    pivot_longer(-c(fips, name), names_to = "moe_col", values_to = "moe")

  dict |>
    left_join(est_long, by = "est_col", relationship = "many-to-many") |>
    left_join(moe_long, by = c("moe_col", "fips", "name"))
}

# Estimate-only version of chas_long(), for dictionaries with no moe_col --
# used only in section 7's validation checks, which compare published
# subtotals against each other and don't need MOEs.
chas_long_est <- function(raw, dict) {
  raw |>
    select(fips, name, all_of(dict$est_col)) |>
    pivot_longer(-c(fips, name), names_to = "est_col", values_to = "estimate") |>
    left_join(dict, by = "est_col")
}

## 2. Resolve column mappings from the data dictionary ----

### Table 7 -- household income x household type x cost burden, by tenure ----
# Detail rows only -- household_type and cost_burden both specified (not "All") --
# are the 5-household-type x 3-burden x 2-tenure x 5-income-band cells we sum over
# household type. Table 7's own subtotals stop at household type, never at burden
# alone, so there is no pre-aggregated column to read instead.
burden_levels <- c(
  "housing cost burden is less than or equal to 30%",
  "housing cost burden is greater than 30% but less than or equal to 50%",
  "housing cost burden is greater than 50%"
)

t7_dict <- read_excel(dict_path, sheet = "Table 7") |>
  clean_names() |>
  filter(household_type != "All", cost_burden %in% burden_levels) |>
  mutate(
    tenure = recode_values(
      tenure,
      "Owner occupied" ~ "Owner",
      "Renter occupied" ~ "Renter",
      default = NA
    ),
    income_band = recode_values(
      household_income,
      "household income is less than or equal to 30% of HAMFI" ~ "0-30% AMI",
      "household income is greater than 30% but less than or equal to 50% of HAMFI" ~ "30-50% AMI",
      "household income is greater than 50% but less than or equal to 80% of HAMFI" ~ "50-80% AMI",
      "household income is greater than 80% but less than or equal to 100% of HAMFI" ~ "80-100% AMI",
      "household income is greater than 100% of HAMFI" ~ "100%+ AMI",
      default = NA
    ),
    burden = recode_values(
      cost_burden,
      "housing cost burden is less than or equal to 30%" ~ "Not cost-burdened",
      "housing cost burden is greater than 30% but less than or equal to 50%" ~ "Cost-burdened",
      "housing cost burden is greater than 50%" ~ "Severely cost-burdened",
      default = NA
    ),
    est_col = str_replace(column_name, "^T7_est", "t7_est"),
    moe_col = str_replace(est_col, "^t7_est", "t7_moe")
  ) |>
  filter(!is.na(tenure), !is.na(income_band), !is.na(burden)) |>
  select(est_col, moe_col, tenure, income_band, burden)

stopifnot(nrow(t7_dict) == 150)   # 2 tenures x 5 income bands x 5 household types x 3 burdens
message("Resolved ", nrow(t7_dict), " Table 7 columns from the data dictionary.")

### Table 8 -- tenure x household income x cost burden x substandard housing ----
# HUD already publishes the cost-burden subtotal (facilities == "All"), so unlike
# Table 7, no manual summing across the plumbing/kitchen-facility split is needed.
# Renter tenure only -- Table 8's owner block is not used. "Not computed" (zero or
# negative income) is its own cost_burden category here, kept for transparency but
# excluded from every chas_gap denominator downstream (METHODOLOGY.md).
t8_raw <- read_excel(dict_path, sheet = "Table 8") |>
  clean_names() |>
  filter(tenure == "Renter occupied")

t8_tenure_total <- t8_raw |>
  filter(household_income == "All", cost_burden == "All", facilities == "All",
         line_type == "Subtotal") |>
  mutate(est_col = str_replace(column_name, "^T8_est", "t8_est")) |>
  pull(est_col)
stopifnot(length(t8_tenure_total) == 1)

# Income-band subtotals (cost_burden == "All") -- confirmed empirically (see
# section 7's validation) to include "not computed" households, all of which
# fall in the 0-30% AMI band (a zero/negative-income household is trivially
# at or below any positive area median). Used only to validate t8_dict's
# sums, never fed into chas_gap -- chas_gap excludes "not computed" from
# every denominator regardless (METHODOLOGY.md).
t8_band_totals <- t8_raw |>
  filter(household_income != "All", cost_burden == "All", facilities == "All",
         line_type == "Subtotal") |>
  mutate(
    income_band = recode_values(
      household_income,
      "less than or equal to 30% of HAMFI" ~ "0-30% AMI",
      "greater than 30% but less than or equal to 50% of HAMFI" ~ "30-50% AMI",
      "greater than 50% but less than or equal to 80% of HAMFI" ~ "50-80% AMI",
      "greater than 80% but less than or equal to 100% of HAMFI" ~ "80-100% AMI",
      "greater than 100% of HAMFI" ~ "100%+ AMI",
      default = NA
    ),
    est_col = str_replace(column_name, "^T8_est", "t8_est")
  ) |>
  filter(!is.na(income_band)) |>
  select(est_col, income_band)
stopifnot(nrow(t8_band_totals) == 5)

t8_dict <- t8_raw |>
  filter(household_income != "All", facilities == "All", cost_burden != "All",
         line_type == "Subtotal") |>
  mutate(
    income_band = recode_values(
      household_income,
      "less than or equal to 30% of HAMFI" ~ "0-30% AMI",
      "greater than 30% but less than or equal to 50% of HAMFI" ~ "30-50% AMI",
      "greater than 50% but less than or equal to 80% of HAMFI" ~ "50-80% AMI",
      "greater than 80% but less than or equal to 100% of HAMFI" ~ "80-100% AMI",
      "greater than 100% of HAMFI" ~ "100%+ AMI",
      default = NA
    ),
    burden = recode_values(
      cost_burden,
      "less than or equal to 30%" ~ "Not cost-burdened",
      "greater than 30% but less than or equal to 50%" ~ "Cost-burdened",
      "greater than 50%" ~ "Severely cost-burdened",
      "not computed (no/negative income)" ~ "Not computed",
      default = NA
    ),
    est_col = str_replace(column_name, "^T8_est", "t8_est"),
    moe_col = str_replace(est_col, "^t8_est", "t8_moe")
  ) |>
  filter(!is.na(income_band), !is.na(burden)) |>
  select(est_col, moe_col, income_band, burden)

stopifnot(nrow(t8_dict) == 20)   # 5 income bands x 4 burden categories (renter only)
message("Resolved ", nrow(t8_dict), " Table 8 columns from the data dictionary.")

### Table 18C -- units in structure x renter affordability x household income ----
# Renter-occupied universe only. HUD already publishes both the rent-tier subtotal
# (summed across income bands) and the income-band detail within each tier, so the
# only summing left to do is across the 4 units-in-structure blocks.
t18c_raw <- read_excel(dict_path, sheet = "Table 18C") |> clean_names()

t18c_grand_total <- t18c_raw |>
  filter(line_type == "Total") |>
  mutate(est_col = str_replace(column_name, "^T18C_est", "t18c_est")) |>
  pull(est_col)
stopifnot(length(t18c_grand_total) == 1)

t18c_all <- t18c_raw |>
  filter(tenure == "Renter occupied", rent != "All") |>
  mutate(
    rent_tier = recode_values(
      rent,
      "less than or equal to RHUD30" ~ "<=RHUD30",
      "greater than RHUD30 and less than or equal to RHUD50" ~ "RHUD30-50",
      "greater than RHUD50 and less than or equal to RHUD80" ~ "RHUD50-80",
      "greater than RHUD80" ~ ">RHUD80",
      default = NA
    ),
    est_col = str_replace(column_name, "^T18C_est", "t18c_est"),
    moe_col = str_replace(est_col, "^t18c_est", "t18c_moe")
  ) |>
  filter(!is.na(rent_tier))

t18c_tier_subtotal <- t18c_all |>
  filter(household_income == "All") |>
  select(est_col, moe_col, units_in_structure, rent_tier)
stopifnot(nrow(t18c_tier_subtotal) == 16)   # 4 structure types x 4 rent tiers

t18c_income_detail <- t18c_all |>
  filter(household_income != "All") |>
  mutate(
    income_band = recode_values(
      household_income,
      "less than or equal to 30% of HAMFI" ~ "0-30% AMI",
      "greater than 30% of HAMFI but less than or equal to 50% of HAMFI" ~ "30-50% AMI",
      "greater than 50% of HAMFI but less than or equal to 80% of HAMFI" ~ "50-80% AMI",
      "greater than 80% of HAMFI but less than or equal to 100% of HAMFI" ~ "80-100% AMI",
      "greater than 100% of HAMFI" ~ "100%+ AMI",
      default = NA
    )
  ) |>
  filter(!is.na(income_band)) |>
  select(est_col, moe_col, units_in_structure, rent_tier, income_band)
stopifnot(nrow(t18c_income_detail) == 80)   # 4 structure types x 4 tiers x 5 income bands

message("Resolved ", nrow(t18c_tier_subtotal) + nrow(t18c_income_detail),
        " Table 18C columns from the data dictionary.")

### Table 17B -- units in structure x renter affordability, vacant-for-rent units ----
# Vacant-for-rent universe -- there is no occupant, so no income dimension. Two
# quirks specific to this table's dictionary sheet, confirmed against the raw
# file rather than assumed: (1) the column literally headed "Tenure" holds the
# structure-type labels instead (the whole table is already vacant-for-rent, so
# there's no real tenure dimension); (2) rent-tier labels carry a "Rent " prefix
# that Table 18C's don't. Both are normalized here so the two tables' rent tiers
# combine cleanly. HUD's Subtotal/Detail split doesn't reach an income dimension
# in this table, so all 16 structure x tier cells are labeled "Detail".
t17b_raw <- read_excel(dict_path, sheet = "Table 17B") |> clean_names()

t17b_grand_total <- t17b_raw |>
  filter(line_type == "Total") |>
  mutate(est_col = str_replace(column_name, "^T17B_est", "t17b_est")) |>
  pull(est_col)
stopifnot(length(t17b_grand_total) == 1)

# Structure-type subtotals (rent == "All"). Used only by section 7's finer-grained
# validation check, so estimates only -- no MOE column is resolved for them.
t17b_struct_subtotal <- t17b_raw |>
  rename(units_in_structure = tenure) |>
  filter(line_type == "Subtotal", rent == "All") |>
  mutate(est_col = str_replace(column_name, "^T17B_est", "t17b_est")) |>
  select(est_col, units_in_structure)
stopifnot(nrow(t17b_struct_subtotal) == 4)

t17b_dict <- t17b_raw |>
  rename(units_in_structure = tenure) |>
  filter(units_in_structure != "Total: Vacant-for-rent housing units", rent != "All") |>
  mutate(
    rent_tier = recode_values(
      rent,
      "Rent less than or equal to RHUD30" ~ "<=RHUD30",
      "Rent greater than RHUD30 and less than or equal to RHUD50" ~ "RHUD30-50",
      "Rent greater than RHUD50 and less than or equal to RHUD80" ~ "RHUD50-80",
      "Rent greater than RHUD80" ~ ">RHUD80",
      default = NA
    ),
    est_col = str_replace(column_name, "^T17B_est", "t17b_est"),
    moe_col = str_replace(est_col, "^t17b_est", "t17b_moe")
  ) |>
  filter(!is.na(rent_tier)) |>
  select(est_col, moe_col, units_in_structure, rent_tier)

stopifnot(nrow(t17b_dict) == 16)   # 4 structure types x 4 rent tiers
message("Resolved ", nrow(t17b_dict), " Table 17B columns from the data dictionary.")

## 3. Read the raw tables and keep the 8 rr counties + Ashland ----

raw7 <- read_chas_geo(t7_path, t7_dict$est_col, t7_dict$moe_col)
stopifnot(nrow(raw7) == length(rr) + 1)

raw8 <- read_chas_geo(
  t8_path,
  c(t8_dict$est_col, t8_band_totals$est_col, t8_tenure_total),
  t8_dict$moe_col
)
stopifnot(nrow(raw8) == length(rr) + 1)

raw18c <- read_chas_geo(
  t18c_path,
  c(t18c_tier_subtotal$est_col, t18c_income_detail$est_col, t18c_grand_total),
  c(t18c_tier_subtotal$moe_col, t18c_income_detail$moe_col)
)
stopifnot(nrow(raw18c) == length(rr) + 1)

raw17b <- read_chas_geo(
  t17b_path,
  c(t17b_dict$est_col, t17b_struct_subtotal$est_col, t17b_grand_total),
  t17b_dict$moe_col
)
stopifnot(nrow(raw17b) == length(rr) + 1)

message("Raw geographies read for all four CHAS tables: ", length(rr) + 1,
        " (8 rr counties + Ashland)")

## 4. Build chas_cb: Table 7 cost burden by AMI band and tenure ----

chas_cb_detail <- chas_long(raw7, t7_dict)

chas_cb <- chas_cb_detail |>
  summarise(
    estimate = sum(estimate),
    moe      = sqrt(sum(moe^2)),
    .by = c(fips, name, tenure, income_band, burden)
  ) |>
  mutate(
    income_band = factor(income_band, levels = c(
      "0-30% AMI", "30-50% AMI", "50-80% AMI", "80-100% AMI", "100%+ AMI"
    )),
    burden = factor(burden, levels = c(
      "Not cost-burdened", "Cost-burdened", "Severely cost-burdened"
    )),
    # Same CV guard as r/acs_burden.R and r/acs_tenure_value.R: absent/zero estimate
    # leaves the CV undefined; an absent/zero MOE on a positive estimate is a
    # controlled value with no sampling error (CV 0 -> High), not a missing one.
    cv = case_when(
      is.na(estimate) | estimate <= 0 ~ NA_real_,
      is.na(moe) | moe == 0           ~ 0,
      .default = (moe / 1.645) / estimate * 100
    )
  ) |>
  flag_reliability() |>
  rename(geoid = fips) |>
  arrange(name, tenure, income_band, burden)

## 5. Build chas_gap: renter shortage and cost-burden figures ----
# Tables 8, 18C, and 17B feed 13 measures, long/tidy (one row per geoid x
# measure). "Not computed" (T8) is excluded from every denominator here --
# reported as its own measure instead. homes_lowest_rent_tier includes vacant-
# for-rent stock (T17B), matching HUD's own published affordability convention
# (Joice, "Measuring Housing Affordability," Cityscape 16:1, 2014) rather than
# an occupied-only count; the occupant-income split necessarily covers occupied
# units only, since a vacant unit has no occupant to classify.

t8_long   <- chas_long(raw8, t8_dict)
t18c_tier_long <- chas_long(raw18c, t18c_tier_subtotal)
t18c_inc_long  <- chas_long(raw18c, t18c_income_detail)
t17b_long <- chas_long(raw17b, t17b_dict)

### 5a. Base counts from each table ----

renters_lowest_income <- t8_long |>
  filter(income_band == "0-30% AMI", burden != "Not computed") |>
  summarise(estimate = sum(estimate), moe = sqrt(sum(moe^2)), .by = c(fips, name)) |>
  mutate(measure = "renters_lowest_income", source_table = "T8")

renters_low_income <- t8_long |>
  filter(income_band %in% c("0-30% AMI", "30-50% AMI", "50-80% AMI"),
         burden != "Not computed") |>
  summarise(estimate = sum(estimate), moe = sqrt(sum(moe^2)), .by = c(fips, name)) |>
  mutate(measure = "renters_low_income", source_table = "T8")

renters_low_income_burdened <- t8_long |>
  filter(income_band %in% c("0-30% AMI", "30-50% AMI", "50-80% AMI"),
         burden %in% c("Cost-burdened", "Severely cost-burdened")) |>
  summarise(estimate = sum(estimate), moe = sqrt(sum(moe^2)), .by = c(fips, name)) |>
  mutate(measure = "renters_low_income_burdened", source_table = "T8")

renters_income_not_computed <- t8_long |>
  filter(burden == "Not computed") |>
  summarise(estimate = sum(estimate), moe = sqrt(sum(moe^2)), .by = c(fips, name)) |>
  mutate(measure = "renters_income_not_computed", source_table = "T8")

homes_occupied_lowest_rent_tier <- t18c_tier_long |>
  filter(rent_tier == "<=RHUD30") |>
  summarise(estimate = sum(estimate), moe = sqrt(sum(moe^2)), .by = c(fips, name)) |>
  mutate(measure = "homes_occupied_lowest_rent_tier", source_table = "T18C")

homes_occupied_lowest_income <- t18c_inc_long |>
  filter(rent_tier == "<=RHUD30", income_band == "0-30% AMI") |>
  summarise(estimate = sum(estimate), moe = sqrt(sum(moe^2)), .by = c(fips, name)) |>
  mutate(measure = "homes_occupied_lowest_income", source_table = "T18C")

homes_vacant_lowest_rent_tier <- t17b_long |>
  filter(rent_tier == "<=RHUD30") |>
  summarise(estimate = sum(estimate), moe = sqrt(sum(moe^2)), .by = c(fips, name)) |>
  mutate(measure = "homes_vacant_lowest_rent_tier", source_table = "T17B")

count_measures <- bind_rows(
  renters_lowest_income,
  renters_low_income,
  renters_low_income_burdened,
  renters_income_not_computed,
  homes_occupied_lowest_rent_tier,
  homes_occupied_lowest_income,
  homes_vacant_lowest_rent_tier
) |>
  mutate(
    cv = case_when(
      is.na(estimate) | estimate <= 0 ~ NA_real_,
      is.na(moe) | moe == 0           ~ 0,
      .default = (moe / 1.645) / estimate * 100
    )
  ) |>
  flag_reliability()

### 5b. Derived sums and differences ----
# MOE combines via sqrt(sum(moe^2)) for both sums and differences, same
# approximation used throughout this script. Each formula is self-contained
# (built straight from the base counts, not chained through other derived
# measures) so no ordering dependency exists between the five rows below.

wide <- count_measures |>
  select(fips, name, measure, estimate, moe) |>
  pivot_wider(names_from = measure, values_from = c(estimate, moe))

derived_counts <- bind_rows(
  wide |> transmute(
    fips, name, measure = "homes_lowest_rent_tier", source_table = "derived",
    estimate = estimate_homes_occupied_lowest_rent_tier + estimate_homes_vacant_lowest_rent_tier,
    moe = sqrt(moe_homes_occupied_lowest_rent_tier^2 + moe_homes_vacant_lowest_rent_tier^2)
  ),
  wide |> transmute(
    fips, name, measure = "homes_occupied_higher_income", source_table = "derived",
    estimate = estimate_homes_occupied_lowest_rent_tier - estimate_homes_occupied_lowest_income,
    moe = sqrt(moe_homes_occupied_lowest_rent_tier^2 + moe_homes_occupied_lowest_income^2)
  ),
  wide |> transmute(
    fips, name, measure = "homes_available_lowest_income", source_table = "derived",
    estimate = estimate_homes_occupied_lowest_income + estimate_homes_vacant_lowest_rent_tier,
    moe = sqrt(moe_homes_occupied_lowest_income^2 + moe_homes_vacant_lowest_rent_tier^2)
  ),
  wide |> transmute(
    fips, name, measure = "shortage_homes", source_table = "derived",
    estimate = estimate_renters_lowest_income -
      (estimate_homes_occupied_lowest_rent_tier + estimate_homes_vacant_lowest_rent_tier),
    moe = sqrt(moe_renters_lowest_income^2 + moe_homes_occupied_lowest_rent_tier^2 +
                 moe_homes_vacant_lowest_rent_tier^2)
  ),
  wide |> transmute(
    fips, name, measure = "shortage_homes_available", source_table = "derived",
    estimate = estimate_renters_lowest_income -
      (estimate_homes_occupied_lowest_income + estimate_homes_vacant_lowest_rent_tier),
    moe = sqrt(moe_renters_lowest_income^2 + moe_homes_occupied_lowest_income^2 +
                 moe_homes_vacant_lowest_rent_tier^2)
  )
) |>
  mutate(
    cv = case_when(
      is.na(estimate) | estimate <= 0 ~ NA_real_,
      is.na(moe) | moe == 0           ~ 0,
      .default = (moe / 1.645) / estimate * 100
    )
  ) |>
  flag_reliability()

### 5c. burden_rate: a ratio, not a sum -- no derived MOE ----
# Same convention as r/acs_tenure_race.R's owner_rate: a ratio of two counts
# doesn't get a propagated MOE/CV, since the sqrt(sum(moe^2)) approximation used
# for sums and differences above doesn't hold for a ratio. Carry the worse of
# the numerator's and denominator's reliability tiers instead.
burden_rate_reliability <- count_measures |>
  filter(measure %in% c("renters_low_income_burdened", "renters_low_income")) |>
  summarise(
    reliability = case_when(
      any(is.na(reliability) | reliability == "Low") ~ "Low",
      any(reliability == "Medium")                    ~ "Medium",
      .default = "High"
    ),
    .by = c(fips, name)
  )

burden_rate <- wide |>
  transmute(
    fips, name,
    estimate = estimate_renters_low_income_burdened / estimate_renters_low_income
  ) |>
  left_join(burden_rate_reliability, by = c("fips", "name")) |>
  mutate(measure = "burden_rate", source_table = "derived", moe = NA_real_, cv = NA_real_)

chas_gap <- bind_rows(count_measures, derived_counts, burden_rate) |>
  rename(geoid = fips) |>
  select(geoid, name, source_table, measure, estimate, moe, cv, reliability) |>
  arrange(name, source_table, measure)

## 6. Write output ----
write_rds(chas_cb, "data/chas_cb.rds")
export_csv(chas_cb, "chas_cb")
message("Wrote data/chas_cb.rds + data-out/chas_cb.csv (", nrow(chas_cb), " rows)")

write_rds(chas_gap, "data/chas_gap.rds")
export_csv(chas_gap, "chas_gap")
message("Wrote data/chas_gap.rds + data-out/chas_gap.csv (", nrow(chas_gap), " rows)")

## 7. Validate ----

geos <- c(unname(rr), unname(ashland))

### 7a. chas_cb ----
d_cb <- read_rds("data/chas_cb.rds")

stopifnot(
  nrow(d_cb) > 0,
  setequal(unique(d_cb$geoid), geos),
  nrow(distinct(d_cb, geoid, tenure, income_band, burden)) ==
    length(geos) * 2 * 5 * 3,       # 9 geographies x 2 tenures x 5 AMI bands x 3 burdens
  !anyNA(d_cb$estimate),
  all(d_cb$estimate >= 0),
  # Same reliability guard as r/acs_burden.R: NA reliability occurs only where the
  # estimate is genuinely zero (a small geography with no households in that
  # income-band x burden x tenure cell), never on a positive estimate.
  all(d_cb$estimate[is.na(d_cb$reliability)] == 0)
)

# Sanity check: every income-band-tenure cell is populated at the regional level
# (would flag a column mis-mapped rather than a genuine small cell).
stopifnot(all(
  d_cb |> filter(geoid %in% rr) |>
    summarise(total = sum(estimate), .by = c(tenure, income_band)) |>
    pull(total) > 0
))

region_renter <- d_cb |>
  filter(geoid %in% rr, tenure == "Renter", burden != "Not cost-burdened") |>
  summarise(estimate = sum(estimate), .by = burden)
message("2018-2022 CHAS regional renter cost-burdened households: ",
        scales::comma(sum(region_renter$estimate)))

### 7b. chas_gap -- structural checks against the raw tables ----

# Table 8: income-band subtotals sum to the renter tenure subtotal.
t8_band_check <- chas_long_est(raw8, t8_band_totals) |>
  summarise(band_sum = sum(estimate), .by = c(fips, name)) |>
  left_join(
    raw8 |> transmute(fips, name, tenure_total = .data[[t8_tenure_total]]),
    by = c("fips", "name")
  )
stopifnot(all(abs(t8_band_check$band_sum - t8_band_check$tenure_total) <= 5))

# Table 8: within each income band, all 4 burden-category subtotals (including
# "not computed") sum to that band's subtotal -- confirmed by inspecting the
# raw dictionary rows for the 0-30% AMI band directly: cost_burden == "All"
# (T8_est69-equivalent) is a true HUD subtotal over all 4 cost_burden values
# at facilities == "All" (T8_est70/73/76/79-equivalent), "not computed"
# included. Tolerance is 10, not 5, because Charles City -- the smallest
# county -- differs by 6 units, consistent with CHAS's disclosure-avoidance
# noise on small cells rather than a mapping error.
t8_burden_check <- t8_long |>
  summarise(burden_sum = sum(estimate), .by = c(fips, name, income_band)) |>
  left_join(
    chas_long_est(raw8, t8_band_totals) |> select(fips, name, income_band, band_total = estimate),
    by = c("fips", "name", "income_band")
  )
stopifnot(all(abs(t8_burden_check$burden_sum - t8_burden_check$band_total) <= 10))

# Table 18C: the detail mapping, checked at two grains. Every published CHAS
# cell is rounded to the nearest 5 independently, so the residual against a
# published total grows with the number of cells summed -- confirmed by
# inspecting the raw file directly: no geography's detail cells are mis-mapped,
# but the 80-cell sum drifts from the grand total by up to 22 units (Henrico),
# while the 16 tier subtotals drift from that same grand total by at most 10.
# So each check below gets a tolerance sized to its own cell count.

# (i) Within each structure x rent-tier block, the 5 income-band detail cells
# sum to that block's published subtotal. This is the direct test of the detail
# mapping feeding chas_gap. 5 cells at +/- 2.5 each; observed max residual is 10
# (Chesterfield, Henrico), so the tolerance is 10.
t18c_tier_check <- t18c_inc_long |>
  summarise(detail_sum = sum(estimate),
            .by = c(fips, name, units_in_structure, rent_tier)) |>
  left_join(
    t18c_tier_long |>
      select(fips, name, units_in_structure, rent_tier, tier_total = estimate),
    by = c("fips", "name", "units_in_structure", "rent_tier")
  )
stopifnot(
  nrow(t18c_tier_check) == length(geos) * 16,
  all(abs(t18c_tier_check$detail_sum - t18c_tier_check$tier_total) <= 10)
)

# (ii) All 80 detail cells sum to the table's grand total. 80 independently
# rounded cells at +/- 2.5 each give a root-sum-square drift of 2.5 * sqrt(80),
# about 23, so the tolerance is 25 -- still two orders of magnitude below the
# thousands a mis-mapped structure or tier block would move.
t18c_check <- t18c_inc_long |>
  summarise(estimate = sum(estimate), .by = c(fips, name)) |>
  left_join(
    raw18c |> transmute(fips, name, grand_total = .data[[t18c_grand_total]]),
    by = c("fips", "name")
  )
stopifnot(all(abs(t18c_check$estimate - t18c_check$grand_total) <= 25))

# Table 17B: the same two grains as Table 18C above, and the same cause -- HUD
# rounds each published cell independently, so the residual grows with the cell
# count. Checked against the raw file: the 16-cell mapping is correct for every
# geography. Charles City is the one that moves, and its own published numbers
# do not tie to each other -- the grand total reads 15 vacant-for-rent units
# while its 4 structure subtotals sum to 19, and its one-unit subtotal reads 15
# against details of 19. On a universe of roughly 15 units, spread over 16
# cells, that is disclosure-avoidance noise, and no tolerance on this script's
# summing can make HUD's own figures agree.

# (i) Within each structure type, the 4 rent-tier detail cells sum to that
# type's published subtotal. 4 cells at +/- 2.5 each; observed max residual is
# 5 (Charles City 4, Henrico 5, Richmond 5), so the tolerance is 5.
t17b_struct_check <- t17b_long |>
  summarise(detail_sum = sum(estimate), .by = c(fips, name, units_in_structure)) |>
  left_join(
    chas_long_est(raw17b, t17b_struct_subtotal) |>
      select(fips, name, units_in_structure, struct_total = estimate),
    by = c("fips", "name", "units_in_structure")
  )
stopifnot(
  nrow(t17b_struct_check) == length(geos) * 4,
  all(abs(t17b_struct_check$detail_sum - t17b_struct_check$struct_total) <= 5)
)

# (ii) All 16 detail cells sum to the table's grand total. 16 rounded cells at
# +/- 2.5 each give 2.5 * sqrt(16), so the tolerance is 10 -- the same figure
# the 16-cell Table 18C tier check and the Table 8 burden check use. Charles
# City's residual of 8 is the only nonzero one above 5.
t17b_check <- t17b_long |>
  summarise(estimate = sum(estimate), .by = c(fips, name)) |>
  left_join(
    raw17b |> transmute(fips, name, grand_total = .data[[t17b_grand_total]]),
    by = c("fips", "name")
  )
stopifnot(all(abs(t17b_check$estimate - t17b_check$grand_total) <= 10))

message("chas_gap structural checks passed: Table 8 band/burden subtotals and ",
        "Table 18C/17B detail sums all tie to their published totals.")

### 7c. chas_gap -- row shape and informational flags ----

d_gap <- read_rds("data/chas_gap.rds")
stopifnot(
  nrow(d_gap) > 0,
  setequal(unique(d_gap$geoid), geos),
  !anyNA(d_gap$estimate),
  nrow(distinct(d_gap, geoid, measure)) == nrow(d_gap)   # exactly one row per geoid x measure
)

# T8 and T18C renter-household totals are expected to differ -- different
# tabulation universes, not an error. Logged for transparency, never a stopifnot.
universe_compare <- inner_join(
  count_measures |> filter(measure == "renters_lowest_income") |>
    select(name, t8_renters = estimate),
  count_measures |> filter(measure == "homes_occupied_lowest_rent_tier") |>
    select(name, t18c_homes = estimate),
  by = "name"
)
message("T8 renters (<=30% HAMFI) vs. T18C occupied homes (<=RHUD30), by locality ",
        "-- expected to differ (different tabulation universes):")
pwalk(universe_compare, \(name, t8_renters, t18c_homes) {
  message("  ", name, ": ", scales::comma(t8_renters), " renters vs. ",
          scales::comma(t18c_homes), " homes")
})

# Human-review flag, never a build failure: a negative shortage means the
# affordable/available stock already exceeds the target renter population.
negative_shortage <- d_gap |>
  filter(measure %in% c("shortage_homes", "shortage_homes_available"), estimate < 0)

if (nrow(negative_shortage) > 0) {
  message("FLAG for review -- negative shortage (homes exceed renters) in:")
  pwalk(negative_shortage, \(...) {
    row <- list(...)
    message("  ", row$name, " / ", row$measure, ": ", scales::comma(row$estimate))
  })
} else {
  message("No locality shows a negative shortage on either measure.")
}

message("chas.R validation passed.")
