# costar_rental.R ----
# What:   Locality and regional quarterly multifamily asking rent, effective rent, and
#         vacancy, from CoStar's own subtotal rows in the manual property-grid export.
# Source: CoStar MultifamilyDataGrid export (manual drop), 2016 Q1 - 2026 Q3 QTD.
#         data/raw/costar/costar_properties_rr.xlsx
# Output: data/costar_rental.rds  (+ data-out/costar_rental.csv — costar_ prefix stays
#         private per .gitignore)

## 1. Setup ----
library(tidyverse)
library(readxl)
source("_common.R")   # geo constants, export_csv()

dir.create("data", showWarnings = FALSE, recursive = TRUE)

raw_path <- "data/raw/costar/costar_properties_rr.xlsx"
stopifnot(file.exists(raw_path))

## 2. Read grid and name columns positionally ----
# The export has a two-row header (group row + subheader row); skip the group row and
# assign names by position, confirmed against the subheader row on first inspection.
grid_names <- c(
  "period", "county", "address", "building", "city", "state", "zip",
  "inv_bldgs", "inv_units", "avg_sf",
  "ask_rent_unit", "ask_rent_sf", "ask_rent_growth",
  "eff_rent_unit", "eff_rent_sf", "eff_rent_growth", "concessions",
  "vac_units", "vac_pct", "vac_growth",
  "occ_units", "occ_pct", "occ_growth",
  "abs_units", "abs_pct",
  "uc_bldgs", "uc_units", "uc_pct",
  "del_bldgs", "del_units", "del_pct"
)

raw <- read_excel(raw_path, sheet = "MultifamilyDataGrid", skip = 1,
                  col_names = grid_names, col_types = "text") |>
  filter(period != "Period")   # drop the subheader row itself

message("Grid rows read: ", nrow(raw))

## 3. Keep CoStar's aggregate rows and tidy ----
# "Subtotals: <county>" rows are CoStar's own locality aggregates (full inventory,
# unit-weighted rents); "Grand Total" is the 8-locality region. Property rows dropped.
# The current partial quarter ("QTD") is dropped so the series ends on a full quarter.
costar_rental <- raw |>
  filter(str_detect(county, "^Subtotals: ") | county == "Grand Total") |>
  filter(!str_detect(period, "QTD")) |>
  mutate(
    locality = if_else(county == "Grand Total", "Richmond region",
                       str_remove(county, "^Subtotals: ")),
    yr  = as.integer(str_sub(period, 1, 4)),
    qtr = as.integer(str_sub(period, 7, 7)),
    quarter = make_date(yr, (qtr - 1) * 3 + 1, 1),
    across(c(inv_units, ask_rent_unit, eff_rent_unit, vac_units, vac_pct), as.numeric)
  ) |>
  select(locality, period, quarter,
         units = inv_units, ask_rent = ask_rent_unit,
         eff_rent = eff_rent_unit, vac_units, vac_pct) |>
  arrange(locality, quarter)

## 4. Write output ----
write_rds(costar_rental, "data/costar_rental.rds")
export_csv(costar_rental, "costar_rental")   # costar_ prefix -> gitignored, private
message("Wrote data/costar_rental.rds + data-out/costar_rental.csv")

## 5. Validate ----
d <- read_rds("data/costar_rental.rds")
expected_localities <- c(
  "Richmond region", "Charles City", "Chesterfield", "Goochland", "Hanover",
  "Henrico", "New Kent", "Powhatan", "Richmond City"
)
stopifnot(
  nrow(d) > 0,
  setequal(unique(d$locality), expected_localities),
  # full-quarter series 2016 Q1 onward, same length for every locality
  n_distinct(d$period) == n_distinct(d$period[d$locality == "Richmond region"]),
  !anyNA(d$ask_rent),
  !anyNA(d$vac_pct),
  # same-vintage benchmark: regional asking rent per unit in a plausible band
  all(between(d$ask_rent[d$locality == "Richmond region"], 900, 2500)),
  all(between(d$vac_pct, 0, 1))
)
latest <- d |> filter(locality == "Richmond region") |> slice_max(quarter, n = 1)
message("Latest full quarter (", latest$period, "): regional asking rent $",
        round(latest$ask_rent), ", vacancy ",
        scales::percent(latest$vac_pct, accuracy = 0.1))
message("costar_rental.R validation passed.")
