# chas.R ----
# What:   HUD CHAS cost burden by household income (AMI band) and tenure -- Table 7,
#         marginalized over household type. Gives the burden-by-AMI-band cut the ACS
#         B25070/B25091 tables (r/acs_burden.R) cannot support, and covers the four
#         secondary localities and Ashland at a reliable cut where ACS renter burden
#         cells are Low reliability.
# Source: HUD CHAS 2018-2022 5-year, manual download (data/raw/README.md spec).
#         Column mapping resolved from the data dictionary rather than hardcoded --
#         data/raw/chas/CHAS-data-dictionary-18-22.xlsx, sheet "Table 7". Each
#         (tenure, income band) cell is the sum of 5 household-type detail columns x
#         3 cost-burden levels; MOEs combine via sqrt(sum(moe^2)) across those 5.
# Tables: Table 7 (household income x household type x cost burden, by tenure).
# Geos:   the 8 rr counties (sumlevel 050, data/raw/chas/050/050/) plus Ashland town
#         (sumlevel 160, data/raw/chas/160/160/, place FIPS 03368).
# Output: data/chas.rds  (+ data-out/chas.csv -- public HUD source, no private prefix)

## 1. Setup ----
library(tidyverse)
library(readxl)
library(janitor)
source("_common.R")   # rr / ashland; flag_reliability(); export_csv()

dir.create("data", showWarnings = FALSE, recursive = TRUE)

dict_path   <- "data/raw/chas/CHAS-data-dictionary-18-22.xlsx"
county_path <- "data/raw/chas/050/050/Table7.csv"
place_path  <- "data/raw/chas/160/160/Table7.csv"
stopifnot(file.exists(dict_path), file.exists(county_path), file.exists(place_path))

## 2. Resolve the column mapping from the data dictionary ----
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

## 3. Read the raw tables and keep the 8 rr counties + Ashland ----
county <- read_csv(county_path, col_types = cols(.default = "c")) |>
  clean_names() |>
  mutate(fips = str_sub(geoid, -5)) |>
  filter(fips %in% rr) |>
  mutate(name = str_remove(name, ", Virginia$"))

place <- read_csv(place_path, col_types = cols(.default = "c")) |>
  clean_names() |>
  filter(st == "51", place == str_sub(unname(ashland), -5)) |>
  mutate(fips = unname(ashland), name = str_remove(name, ", Virginia$"))

raw <- bind_rows(
  county |> select(fips, name, all_of(t7_dict$est_col), all_of(t7_dict$moe_col)),
  place  |> select(fips, name, all_of(t7_dict$est_col), all_of(t7_dict$moe_col))
) |>
  mutate(across(-c(fips, name), as.numeric))

stopifnot(nrow(raw) == length(rr) + 1)
message("Raw geographies read: ", nrow(raw), " (8 rr counties + Ashland)")

## 4. Reshape long, join the dictionary, and sum across household type ----
est_long <- raw |>
  select(fips, name, all_of(t7_dict$est_col)) |>
  pivot_longer(-c(fips, name), names_to = "est_col", values_to = "estimate")

moe_long <- raw |>
  select(fips, name, all_of(t7_dict$moe_col)) |>
  pivot_longer(-c(fips, name), names_to = "moe_col", values_to = "moe")

chas_detail <- t7_dict |>
  left_join(est_long, by = "est_col", relationship = "many-to-many") |>
  left_join(moe_long, by = c("moe_col", "fips", "name"))

chas <- chas_detail |>
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

## 5. Write output ----
write_rds(chas, "data/chas.rds")
export_csv(chas, "chas")
message("Wrote data/chas.rds + data-out/chas.csv (", nrow(chas), " rows)")

## 6. Validate ----
d <- read_rds("data/chas.rds")
geos <- c(unname(rr), unname(ashland))

stopifnot(
  nrow(d) > 0,
  setequal(unique(d$geoid), geos),
  nrow(distinct(d, geoid, tenure, income_band, burden)) ==
    length(geos) * 2 * 5 * 3,       # 9 geographies x 2 tenures x 5 AMI bands x 3 burdens
  !anyNA(d$estimate),
  all(d$estimate >= 0),
  # Same reliability guard as r/acs_burden.R: NA reliability occurs only where the
  # estimate is genuinely zero (a small geography with no households in that
  # income-band x burden x tenure cell), never on a positive estimate.
  all(d$estimate[is.na(d$reliability)] == 0)
)

# Sanity check: every income-band-tenure cell is populated at the regional level
# (would flag a column mis-mapped rather than a genuine small cell).
stopifnot(all(
  d |> filter(geoid %in% rr) |> summarise(total = sum(estimate), .by = c(tenure, income_band)) |> pull(total) > 0
))

region_renter <- d |>
  filter(geoid %in% rr, tenure == "Renter", burden != "Not cost-burdened") |>
  summarise(estimate = sum(estimate), .by = burden)
message("2018-2022 CHAS regional renter cost-burdened households: ",
        scales::comma(sum(region_renter$estimate)))
message("chas.R validation passed.")
