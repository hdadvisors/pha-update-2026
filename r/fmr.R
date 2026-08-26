# fmr.R ----
# What:   HUD FY2026 Fair Market Rents (FMR) at the county level and Small Area
#         Fair Market Rents (SAFMR) at the ZIP-code level for the Richmond HUD
#         metro area. FMR is a single area-wide rate -- all 8 rr localities share
#         one HUD area ("Richmond, VA HUD Metro FMR Area"), so the locality frame
#         repeats the same rates across counties. SAFMR varies by ZIP code within
#         that area. Feeds the rental and burden chapters' affordability cuts.
# Source: HUD FY2026 FMR/SAFMR, manual download (data/raw/hud/).
#         FMR file:   data/raw/hud/hud_fmr_fy2026.xlsx, sheet "FY26_FMRs_revised"
#         SAFMR file: data/raw/hud/hud_safmr_fy2026.xlsx, sheet "SAFMRs"
# Note:   FMR column naming: fmr_0 ... fmr_4 (bedroom count, 0 = studio).
#         SAFMR column naming after clean_names(): safmr_0br ... safmr_4br.
#         90%/110% payment-standard variants are retained in the raw read but
#         dropped in the tidy long frame (not needed for this cycle's analysis).
#         SAFMR source carries no county FIPS -- ZIP-to-county attribution would
#         require a separate crosswalk (not built here). The SAFMR frame is
#         filtered by HUD area code derived from the FMR filter, not by county.
# Output: data/fmr.rds   -- locality-level FMR long frame (+ data-out/fmr.csv)
#         data/safmr.rds -- ZIP-level SAFMR long frame    (+ data-out/safmr.csv)

## 1. Setup ----
library(tidyverse)
library(readxl)
library(janitor)
source("_common.R")  # rr; export_csv()

fmr_path   <- "data/raw/hud/hud_fmr_fy2026.xlsx"
safmr_path <- "data/raw/hud/hud_safmr_fy2026.xlsx"

stopifnot(file.exists(fmr_path), file.exists(safmr_path))
dir.create("data", showWarnings = FALSE, recursive = TRUE)

## 2. Read and filter FMR to rr localities ----
# The fips column is 10 characters: 2-digit state + 3-digit county + "99999".
# Extract the first 5 characters to match the rr constant's 5-digit county FIPS.
message("Reading FMR file...")
fmr_raw <- read_excel(fmr_path, sheet = "FY26_FMRs_revised") |>
  clean_names()

rr_fmr_raw <- fmr_raw |>
  mutate(fips5 = str_sub(fips, 1, 5)) |>
  filter(fips5 %in% rr)

stopifnot(nrow(rr_fmr_raw) == length(rr))

# Confirm all 8 localities share one HUD area (the Richmond metro area rate is
# area-wide; no sub-county variation exists in this file).
stopifnot(n_distinct(rr_fmr_raw$hud_area_code) == 1)
message("HUD area: ", unique(rr_fmr_raw$hud_area_name))
message("FMR (0-4BR): ",
        paste(rr_fmr_raw[1, paste0("fmr_", 0:4)], collapse = " / "))

## 3. Reshape FMR to long frame ----
fmr <- rr_fmr_raw |>
  pivot_longer(
    cols      = paste0("fmr_", 0:4),
    names_to  = "bedroom_size",
    names_prefix = "fmr_",
    values_to = "fmr"
  ) |>
  mutate(bedroom_size = as.integer(bedroom_size)) |>
  select(fips5, countyname, hud_area_code, hud_area_name, bedroom_size, fmr)

## 4. Read and filter SAFMR to the Richmond HUD area ----
# Filter by hud_area_code derived from the FMR step rather than by county FIPS
# (the SAFMR file carries no county identifier).
message("Reading SAFMR file...")
safmr_raw <- read_excel(safmr_path) |>
  clean_names()

rr_area_codes <- unique(rr_fmr_raw$hud_area_code)

rr_safmr_raw <- safmr_raw |>
  filter(hud_area_code %in% rr_area_codes)

message("SAFMR ZIP codes in Richmond HUD area: ", nrow(rr_safmr_raw))

## 5. Reshape SAFMR to long frame ----
# Keep only the base SAFMR columns (drop 90%/110% payment-standard variants).
safmr <- rr_safmr_raw |>
  select(
    zip_code,
    hud_area_code,
    hud_area_name = hud_fair_market_rent_area_name,
    safmr_0br, safmr_1br, safmr_2br, safmr_3br, safmr_4br
  ) |>
  pivot_longer(
    cols      = starts_with("safmr_"),
    names_to  = "bedroom_size",
    names_prefix = "safmr_",
    values_to = "safmr"
  ) |>
  mutate(bedroom_size = as.integer(str_remove(bedroom_size, "br")))

## 6. Write outputs ----
write_rds(fmr, "data/fmr.rds")
export_csv(fmr, "fmr")
message("Wrote data/fmr.rds + data-out/fmr.csv (", nrow(fmr), " rows)")

write_rds(safmr, "data/safmr.rds")
export_csv(safmr, "safmr")
message("Wrote data/safmr.rds + data-out/safmr.csv (", nrow(safmr), " rows)")

## 7. Validate ----
fmr_v   <- read_rds("data/fmr.rds")
safmr_v <- read_rds("data/safmr.rds")

stopifnot(
  # FMR: all 8 localities, all 5 bedroom sizes, no NA
  all(rr %in% fmr_v$fips5),
  setequal(fmr_v$bedroom_size, 0:4),
  !anyNA(fmr_v$fmr),
  # SAFMR: at least 30 ZIP codes (Richmond metro has many more; this guards against
  # a silent empty-filter), all 5 bedroom sizes, no NA
  # Note: per-locality ZIP coverage cannot be validated here -- the SAFMR source
  # carries no county FIPS; county attribution requires a separate crosswalk.
  n_distinct(safmr_v$zip_code) >= 30,
  setequal(safmr_v$bedroom_size, 0:4),
  !anyNA(safmr_v$safmr)
)

message("FMR 2BR (Richmond HUD area): ",
        scales::dollar(fmr_v$fmr[fmr_v$bedroom_size == 2][1]))
message("SAFMR 2BR range across ", n_distinct(safmr_v$zip_code), " ZIPs: ",
        scales::dollar(min(safmr_v$safmr[safmr_v$bedroom_size == 2])), " - ",
        scales::dollar(max(safmr_v$safmr[safmr_v$bedroom_size == 2])))
message("fmr.R validation passed.")
