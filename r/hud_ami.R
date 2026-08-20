# hud_ami.R ----
# What:   HUD FY2026 Section 8 Income Limits for the region's HUD area, extended to
#         100% and 120% of the area median family income (AMI/MFI is not published by
#         HUD past 80%, so 100/120% are derived from the published household-size
#         scaling factor embedded in the 50% limits). Feeds the gaps.qmd affordability
#         cuts (r/gaps.R) with dollar thresholds for the 30/50/80/100/120% AMI bands.
# Source: HUD FY2026 Income Limits, manual download (data/raw/README.md does not yet
#         cover this drop -- see data/raw/hud/hud_il_fy2026.xlsx, sheet "Section8-FY26").
# Note:   All 8 rr counties (and the Ashland/Hanover place) share one HUD area --
#         "Richmond, VA HUD Metro FMR Area" -- confirmed here rather than assumed, per
#         the Section 8 methodology spec. One income-limit table serves the whole
#         region; there is no locality-level variation to carry.
# Output: data/hud_ami.rds  (+ data-out/hud_ami.csv)

## 1. Setup ----
library(tidyverse)
library(readxl)
source("_common.R") # rr; export_csv()

path <- "data/raw/hud/hud_il_fy2026.xlsx"
stopifnot(file.exists(path))

## 2. Read and confirm the HUD area assignment ----
il <- read_excel(path, sheet = "Section8-FY26")

rr_rows <- il |> mutate(fips5 = paste0(state, county)) |> filter(fips5 %in% rr)

stopifnot(
  nrow(rr_rows) == length(rr),
  n_distinct(rr_rows$hud_area_name) == 1,
  n_distinct(rr_rows$median2026) == 1
)
message("HUD area for all 8 rr counties: ", unique(rr_rows$hud_area_name))

## 3. Build the household-size income-limit table ----
# 50% limits already embed HUD's household-size scaling factor (70/80/90/100/108/
# 116/124/132% of the 4-person figure) relative to the county median family income.
# 100% and 120% are not published, so they are derived by applying that same factor
# to median2026 -- the extension the methodology spec calls calc_ami() ported from
# faar. 30% and 80% come straight from HUD's own published ELI_ and l80_ columns.
one <- rr_rows |> slice(1)
mfi_4p <- one$median2026

hud_ami <- map(1:8, \(sz) {
  factor <- one[[paste0("l50_", sz)]] / one[[paste0("l50_", 4)]]
  tibble(
    household_size = sz,
    pct_ami = c(30, 50, 80, 100, 120),
    income_limit = c(
      one[[paste0("ELI_", sz)]],
      one[[paste0("l50_", sz)]],
      one[[paste0("l80_", sz)]],
      mfi_4p * factor,
      mfi_4p * factor * 1.2
    )
  )
}) |>
  list_rbind() |>
  mutate(hud_area = unique(rr_rows$hud_area_name), mfi_4person = mfi_4p)

## 4. Write output ----
write_rds(hud_ami, "data/hud_ami.rds")
export_csv(hud_ami, "hud_ami")
message("Wrote data/hud_ami.rds + data-out/hud_ami.csv (", nrow(hud_ami), " rows)")

## 5. Validate ----
d <- read_rds("data/hud_ami.rds")
stopifnot(
  nrow(d) == 8 * 5, # 8 household sizes x 5 AMI bands
  !anyNA(d$income_limit),
  all(d$income_limit > 0),
  # 100% AMI at household size 4 must reproduce HUD's published median2026 exactly.
  d |> filter(household_size == 4, pct_ami == 100) |> pull(income_limit) == mfi_4p,
  # Income limits are strictly increasing across bands within a household size.
  all(d |> arrange(household_size, pct_ami) |> summarise(ok = all(diff(income_limit) > 0), .by = household_size) |> pull(ok))
)
message("4-person MFI (100% AMI): ", scales::dollar(mfi_4p))
message("hud_ami.R validation passed.")
