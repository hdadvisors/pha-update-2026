# wcoop.R ----
# What:   University of Virginia Weldon Cooper Center 2025 Virginia population
#         projections, combined into one long frame keyed by geography, year, and
#         projection series. The Total workbook carries the 8 rr localities; the
#         LargeTowns workbook carries Ashland; the AgeSex workbook carries age x sex
#         detail for whichever geographies it actually has -- which turns out to be
#         the 8 rr localities (state + county rows only, no town rows, so Ashland's
#         age detail is out of scope here; see the validation-block message).
# Source: Manual xlsx drops already on disk in data/raw/wcoop/ -- Weldon Cooper's
#         July 2025 release. Nothing is fetched. Published years are 2030/2040/2050;
#         the Total workbook's second sheet (2035/2045/2055) is Weldon Cooper's own
#         interpolation of those published years, not a separate published vintage,
#         and is out of this phase's scope, so it is not read here.
# Files:  VAPopProjections_Total_2030-2050_1July2025.xlsx      (rr, 8 localities)
#         VAPopProjections_LargeTowns_2030-2050_1July2025.xlsx (Ashland town)
#         VAPopProjections_AgeSex_2030-2050_1July2025.xlsx     (rr, age x sex detail)
# Output: data/wcoop.rds (+ data-out/wcoop.csv)

## 1. Setup ----
library(tidyverse)
library(readxl)
library(janitor)
source("_common.R")   # rr, ashland geography constants; export_csv()

dir.create("data", showWarnings = FALSE, recursive = TRUE)

# No API key / .Renviron fallback needed -- every input is a local xlsx already on disk.

raw_dir <- "data/raw/wcoop"

## 2. Total population -- rr localities ----
# Sheet layout: row 1 title, row 2 producer note, row 3 header labels, row 4 the year
# values (2030/2040/2050) under "Total Population", row 5+ data. skip = 4 and supplying
# col_names directly reads straight to the data rows.
message("Reading Total workbook...")
total_raw <- read_excel(
  file.path(raw_dir, "VAPopProjections_Total_2030-2050_1July2025.xlsx"),
  sheet     = "Total_2030,2040,2050",
  skip      = 4,
  col_names = c("fips", "name", "2030", "2040", "2050")
) |>
  clean_names() |>                 # "2030" -> "x2030" (janitor's leading-digit prefix)
  mutate(geoid = as.character(fips)) |>
  filter(geoid %in% rr)

# Stop-gate: the Total workbook must resolve all 8 rr localities by FIPS, or the drop
# is not the file this phase assumed and the fix is a new drop from Jonathan.
stopifnot(setequal(total_raw$geoid, rr))
message("Total workbook: all 8 rr localities resolved by FIPS.")

total_pop <- total_raw |>
  select(geoid, name, x2030, x2040, x2050) |>
  pivot_longer(starts_with("x20"), names_to = "year", values_to = "estimate") |>
  mutate(
    year      = as.integer(str_remove(year, "^x")),
    series    = "total_population",
    sex       = NA_character_,
    age_group = NA_character_
  )

## 3. Total population -- Ashland town ----
message("Reading LargeTowns workbook...")
ashland_raw <- read_excel(
  file.path(raw_dir, "VAPopProjections_LargeTowns_2030-2050_1July2025.xlsx"),
  sheet     = 1,
  skip      = 4,
  col_names = c("fips", "name", "parent_county", "2030", "2040", "2050")
) |>
  clean_names() |>
  mutate(geoid = as.character(fips)) |>
  filter(geoid %in% ashland)

# Stop-gate: the LargeTowns workbook must have an Ashland row.
stopifnot(nrow(ashland_raw) == 1)
message("LargeTowns workbook: Ashland row resolved by FIPS.")

ashland_pop <- ashland_raw |>
  select(geoid, name, x2030, x2040, x2050) |>
  pivot_longer(starts_with("x20"), names_to = "year", values_to = "estimate") |>
  mutate(
    year      = as.integer(str_remove(year, "^x")),
    series    = "total_population",
    sex       = NA_character_,
    age_group = NA_character_
  )

## 4. Age x sex detail -- rr localities only ----
# The AgeSex workbook has one sheet per projection year (2030/2040/2050), each with
# Total/Female/Male age-band blocks (18 bands x 3 = 54 columns) after fips/name/total.
# Columns are assigned directly below rather than run through clean_names(), because the
# human-readable age-band text ("0 to 4", "85 and Over") is deliberately preserved so the
# pivot_longer() regex below can split it back out into a sex/age_group pair.
age_bins <- c("0 to 4", "5 to 9", "10 to 14", "15 to 19", "20 to 24", "25 to 29",
              "30 to 34", "35 to 39", "40 to 44", "45 to 49", "50 to 54", "55 to 59",
              "60 to 64", "65 to 69", "70 to 74", "75 to 79", "80 to 84", "85 and Over")

agesex_col_names <- c(
  "fips", "name", "total_population",
  paste0("total_",  age_bins),
  paste0("female_", age_bins),
  paste0("male_",   age_bins)
)
age_cols <- setdiff(agesex_col_names, c("fips", "name", "total_population"))

message("Reading AgeSex workbook...")
agesex_years <- c("2030", "2040", "2050")

age_sex <- map(agesex_years, \(yr) {
  read_excel(
    file.path(raw_dir, "VAPopProjections_AgeSex_2030-2050_1July2025.xlsx"),
    sheet     = yr,
    skip      = 4,
    col_names = agesex_col_names
  ) |>
    mutate(geoid = as.character(fips), year = as.integer(yr)) |>
    filter(geoid %in% rr) |>
    select(geoid, name, year, all_of(age_cols)) |>
    pivot_longer(
      cols         = all_of(age_cols),
      names_to     = c("sex", "age_group"),
      names_pattern = "^(total|female|male)_(.+)$",
      values_to    = "estimate"
    )
}) |>
  list_rbind() |>
  mutate(
    series = "age_sex",
    sex    = str_to_title(sex)   # "total" -> "Total", matching the workbook's own labels
  )

# Open question closed: AgeSex resolves to state + county rows only, no town rows, so
# it covers all 8 rr localities but never Ashland. Not the "state-level only" risk the
# phase file flagged -- county detail is present, just no town breakout.
stopifnot(setequal(unique(age_sex$geoid), rr))
message("AgeSex workbook: all 8 rr localities resolved by FIPS across ",
        n_distinct(age_sex$year), " years. No town-level rows (Ashland not covered).")

## 5. Combine into one tidy long frame ----
wcoop <- bind_rows(total_pop, ashland_pop, age_sex) |>
  relocate(geoid, name, year, series, sex, age_group, estimate) |>
  arrange(geoid, series, year, sex, age_group)

## 6. Write output ----
write_rds(wcoop, "data/wcoop.rds")
export_csv(wcoop, "wcoop")   # -> data-out/wcoop.csv
message("Wrote data/wcoop.rds + data-out/wcoop.csv (", nrow(wcoop), " rows)")

## 7. Validate ----
d <- read_rds("data/wcoop.rds")

# Structure only -- row counts, expected geographies present, no all-NA estimate column.
stopifnot(
  nrow(d) > 0,
  all(rr %in% d$geoid[d$series == "total_population"]),
  all(ashland %in% d$geoid[d$series == "total_population"]),
  all(rr %in% d$geoid[d$series == "age_sex"]),
  setequal(unique(d$year), c(2030L, 2040L, 2050L)),
  !anyNA(d$estimate)
)

# No same-vintage published benchmark applies -- these are 2030-2050 model projections,
# not a current-count series, so there is nothing to stopifnot() against. 2022 baseline
# comparisons for the demand section's projection metrics (e.g. population_projection_2050,
# population_projection_pct_chg) belong in the session log, not here, because the 2022
# figures are a different Weldon Cooper release projecting from a different base year.

message("wcoop.R validation passed: ", nrow(d), " rows, ",
        n_distinct(d$geoid), " geographies, years ",
        paste(sort(unique(d$year)), collapse = ", "), ".")
