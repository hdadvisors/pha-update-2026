# nhpd.R ----
# What:   Federally assisted multifamily properties in the rr region, with a subsidy-
#         expiration preservation-risk cut. Feeds rental.qmd's assisted-stock figure.
# Source: National Housing Preservation Database (NHPD), Virginia property-level
#         extract, manual download (data/raw/README.md does not yet cover this drop --
#         see data/raw/nhpd/nhpd_virginia.xlsx). One row per property; county_code is
#         already a 5-digit county FIPS, confirmed to match rr directly (no join needed).
# Note:   Only 5 of the 8 rr counties have any NHPD-tracked property (Chesterfield,
#         Hanover, Henrico, Richmond city, Charles City) -- Goochland, New Kent, and
#         Powhatan have none in this extract, consistent with NHPD's multifamily-only
#         scope and those counties' small, mostly single-family assisted stock.
# Output: data/nhpd.rds  (+ data-out/nhpd.csv)

## 1. Setup ----
library(tidyverse)
library(readxl)
library(janitor)
library(lubridate)
source("_common.R")   # rr; export_csv()

path <- "data/raw/nhpd/nhpd_virginia.xlsx"
stopifnot(file.exists(path))

## 2. Read and filter to the rr region ----
raw <- read_excel(path, sheet = 1) |> clean_names()

message("NHPD Virginia rows: ", nrow(raw))

## 3. Build the preservation-risk cut ----
# latest_end_date is NHPD's own summary of the property's furthest-out known active
# subsidy end date -- the earliest a currently-assisted property could fully lose its
# affordability restriction. Active public housing and some HOME-assisted properties
# carry no listed end date; kept as its own bucket rather than dropped.
nhpd <- raw |>
  filter(county_code %in% rr, property_status == "Active") |>
  mutate(
    geoid = county_code,
    county = str_remove(county, " City$"),
    expire_window = case_when(
      is.na(latest_end_date)        ~ "No listed expiration",
      year(latest_end_date) <= 2030 ~ "2026-2030",
      year(latest_end_date) <= 2035 ~ "2031-2035",
      year(latest_end_date) <= 2040 ~ "2036-2040",
      .default                        = "2041 and later"
    ),
    expire_window = factor(expire_window, levels = c(
      "2026-2030", "2031-2035", "2036-2040", "2041 and later", "No listed expiration"
    )),
    lihtc = number_active_lihtc > 0
  ) |>
  select(
    nhpd_property_id, geoid, county, property_name, total_units,
    latest_end_date, expire_window, lihtc,
    number_active_section8, number_active_public_housing, number_active_home,
    number_active_hud_insured, number_active_section515, number_active_pbv,
    number_active_nhtf, number_active_section202, number_active_section538
  )

## 4. Write output ----
write_rds(nhpd, "data/nhpd.rds")
export_csv(nhpd, "nhpd")
message("Wrote data/nhpd.rds + data-out/nhpd.csv (", nrow(nhpd), " active rr properties)")

## 5. Validate ----
d <- read_rds("data/nhpd.rds")
stopifnot(
  nrow(d) > 0,
  all(d$geoid %in% rr),
  all(d$total_units >= 0, na.rm = TRUE),
  !anyNA(d$expire_window)
)

message("rr counties represented: ", n_distinct(d$geoid), " of ", length(rr))
message("Total active assisted units, rr region: ", scales::comma(sum(d$total_units, na.rm = TRUE)))
risk <- d |> summarise(units = sum(total_units, na.rm = TRUE), .by = expire_window) |> arrange(expire_window)
print(risk)
message("LIHTC-flagged properties: ", sum(d$lihtc), " of ", nrow(d),
        " (", scales::comma(sum(d$total_units[d$lihtc], na.rm = TRUE)), " units)")
message("nhpd.R validation passed.")
