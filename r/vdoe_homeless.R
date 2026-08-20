# vdoe_homeless.R ----
# What:   McKinney-Vento (MV) homeless student counts by school division, 4 primary
#         localities, 2020-21 through 2024-25. Feeds burden.qmd's student-homelessness
#         figure, updating the 2022 Framework's Richmond MV trend (data/baseline_2022.rds,
#         metric "student_homelessness_pct_chg").
# Source: Virginia Department of Education (VDOE) LEA-level MV/homeless child count
#         releases, one file per school year, manual download to data/raw/vdoe/*.xlsx.
#         Column layout and header names vary release to release (LEA number, division
#         name, count are always columns 1-3, in that order) -- read by position, not name.
# Output: data/vdoe_homeless.rds  (+ data-out/vdoe_homeless.csv)

## 1. Setup ----
library(tidyverse)
library(readxl)
library(janitor)
source("_common.R") # pha; export_csv()

# One row per school year: file path, sheet to read (2020-21 ships 3 sheets; the others
# ship 1), and the school-year label to stamp on the tidied rows.
releases <- tribble(
  ~school_year, ~path,                                              ~sheet,
  "2020-21",    "data/raw/vdoe/2020-21-child-count.xlsx",           "Total VA Child Counts",
  "2021-22",    "data/raw/vdoe/LEA-totals-2021-22.xlsx",            "1",
  "2022-23",    "data/raw/vdoe/LEA-totals-to-post-2022-23.xlsx",    "1",
  "2023-24",    "data/raw/vdoe/LEA-totals-to-post-2023-24.xlsx",    "1",
  "2024-25",    "data/raw/vdoe/2024-25-LEA-MV-Counts-for-posting.xlsx", "1"
)
stopifnot(all(file.exists(releases$path)))

## 2. Read each release, keep the 4 primary localities ----
# Division names carry footnote asterisks that vary by release ("Chesterfield County
# Public Schools*", "**"); matched with str_detect rather than exact equality.
locality_pattern <- c(
  chesterfield = "^Chesterfield County",
  hanover      = "^Hanover County",
  henrico      = "^Henrico County",
  richmond     = "^Richmond City"
)

read_release <- function(path, sheet, yr) {
  sheet_arg <- if (sheet == "1") 1L else sheet
  read_excel(path, sheet = sheet_arg, col_names = c("lea_number", "division_name", "mv_count"), skip = 1) |>
    mutate(school_year = yr)
}

vdoe_homeless <- releases |>
  pmap(\(school_year, path, sheet) read_release(path, sheet, school_year)) |>
  list_rbind() |>
  mutate(
    mv_count = as.numeric(mv_count),
    locality_key = case_when(
      str_detect(division_name, locality_pattern["chesterfield"]) ~ "chesterfield",
      str_detect(division_name, locality_pattern["hanover"])      ~ "hanover",
      str_detect(division_name, locality_pattern["henrico"])      ~ "henrico",
      str_detect(division_name, locality_pattern["richmond"])     ~ "richmond",
      .default = NA_character_
    )
  ) |>
  filter(!is.na(locality_key)) |>
  mutate(
    geoid = pha[locality_key],
    locality = c(
      chesterfield = "Chesterfield", hanover = "Hanover",
      henrico = "Henrico", richmond = "Richmond city"
    )[locality_key]
  ) |>
  select(geoid, locality, school_year, mv_count) |>
  arrange(school_year, locality)

message("VDOE MV rows kept: ", nrow(vdoe_homeless), " (5 school years x 4 localities expected)")

## 3. Write output ----
write_rds(vdoe_homeless, "data/vdoe_homeless.rds")
export_csv(vdoe_homeless, "vdoe_homeless")
message("Wrote data/vdoe_homeless.rds + data-out/vdoe_homeless.csv (", nrow(vdoe_homeless), " rows)")

## 4. Validate ----
d <- read_rds("data/vdoe_homeless.rds")
stopifnot(
  nrow(d) == 20,
  setequal(unique(d$geoid), unname(pha)),
  setequal(unique(d$school_year), releases$school_year),
  !anyNA(d$mv_count)
)

message("VDOE MV counts, 2024-25:")
print(d |> filter(school_year == "2024-25"))
message("vdoe_homeless.R validation passed.")
