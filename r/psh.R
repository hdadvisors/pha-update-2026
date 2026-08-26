# psh.R ----
# What:   Federal rental-assistance program mix and utilization by locality, annual,
#         2020-2024 -- HCV, public housing, project-based Section 8, 202/PRAC,
#         811/PRAC, Mod Rehab, and S236/BMIR. Net-new scope; see the 2026-08-06
#         LOG.md entry for the scoping decision. Feeds rental.qmd's
#         federal-assistance-utilization figure.
# Source: HUD Picture of Subsidized Households (PSH), county-level annual extracts,
#         manually dropped in data/raw/psh/ (not yet in data/raw/README.md). One file
#         per year-end quarter; 2022-2024 use the "_2020census" geography-vintage
#         re-release where both exist, for a consistent county boundary basis across
#         the panel. `code` is already a 5-digit county FIPS, matching rr directly.
# Output: data/psh.rds  (+ data-out/psh.csv)

## 1. Setup ----
library(tidyverse)
library(readxl)
library(janitor)
source("_common.R")   # rr; export_csv()

files <- c(
  "2020" = "data/raw/psh/COUNTY_2020.xlsx",
  "2021" = "data/raw/psh/COUNTY_2021.xlsx",
  "2022" = "data/raw/psh/COUNTY_2022_2020census.xlsx",
  "2023" = "data/raw/psh/COUNTY_2023_2020census.xlsx",
  "2024" = "data/raw/psh/COUNTY_2024_2020census.xlsx"
)
stopifnot(all(file.exists(files)))

## 2. Read each year's county extract and keep the rr region ----
read_psh_year <- function(path) {
  read_excel(path, sheet = 1) |>
    clean_names() |>
    filter(code %in% rr) |>
    mutate(
      year = year(quarter),
      # HUD PSH flags a suppressed cell (too few units to report a reliable rate)
      # with the sentinel -4, seen only on pct_occupied for the smallest county x
      # program cells (1-5 total units) -- convert to NA rather than a fake negative.
      pct_occupied = if_else(pct_occupied < 0, NA_real_, pct_occupied)
    ) |>
    select(year, geoid = code, name, program_label, total_units, pct_occupied, number_reported)
}

message("Pulling PSH county extracts, ", min(names(files)), "-", max(names(files)), "...")
psh <- map(files, read_psh_year) |> list_rbind()
message("PSH rr rows pulled: ", nrow(psh))

## 3. Write output ----
write_rds(psh, "data/psh.rds")
export_csv(psh, "psh")
message("Wrote data/psh.rds + data-out/psh.csv (", nrow(psh), " rows)")

## 4. Validate ----
d <- read_rds("data/psh.rds")
stopifnot(
  nrow(d) > 0,
  setequal(unique(d$year), 2020:2024),
  all(d$geoid %in% rr),
  all(d$total_units >= 0, na.rm = TRUE),
  all(d$pct_occupied >= 0 & d$pct_occupied <= 100, na.rm = TRUE)   # -4 sentinel cleaned to NA above
)

message("Program categories present: ", paste(sort(unique(d$program_label)), collapse = ", "))

reg_mix <- d |>
  filter(program_label != "Summary of All HUD Programs") |>
  summarise(units = sum(total_units, na.rm = TRUE), .by = c(year, program_label))
message("Regional assisted units by program, 2020 vs 2024:")
print(reg_mix |> filter(year %in% c(2020, 2024)) |> arrange(program_label, year))

reg_total <- reg_mix |> summarise(units = sum(units), .by = year) |> arrange(year)
message("Regional total assisted units (program rows summed) by year:")
print(reg_total)

message("psh.R validation passed.")
