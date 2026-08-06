# geo.R ----
# What:   Study-area boundaries as sf objects -- the 8 rr counties/cities, the Ashland
#         place, and the puma_region PUMAs. No figure in this cycle needs a projected
#         CRS, so every frame stays in the CRS tigris returns (Phase 2 Decisions,
#         2026-08-06) -- that CRS is recorded below, never reprojected.
# Source: tigris (Census TIGER/Line, cb = TRUE generalized boundaries for counties and
#         places; year = 2022 for the 2020-vintage PUMA codes, per Phase 1's resolution)
# Output: data/geo_localities.rds, data/geo_ashland.rds, data/geo_pumas.rds
#         (no data-out/ CSV -- an sf geometry column isn't Azure/PowerBI-usable as CSV;
#         this is the one documented exception to the write_rds()/export_csv() pairing,
#         Phase 2 Decisions 2026-08-06)

## 1. Setup ----
library(tidyverse)
library(tigris)
library(sf)
library(janitor)
source("_common.R")   # rr, ashland, puma_region geography constants

options(tigris_use_cache = TRUE)

dir.create("data", showWarnings = FALSE, recursive = TRUE)

# No API key / .Renviron fallback needed -- tigris pulls TIGER/Line files with no key.

## 2. Localities: 8 rr counties/cities ----
message("Pulling VA counties (cb = TRUE)...")
geo_localities <- counties(state = "VA", cb = TRUE) |>
  clean_names() |>                 # GEOID -> geoid, NAME -> name, etc.
  filter(geoid %in% rr)
message("geo_localities pulled: ", nrow(geo_localities), " rows, CRS ",
        st_crs(geo_localities)$input)

## 3. Ashland place ----
message("Pulling VA places (cb = TRUE)...")
geo_ashland <- places(state = "VA", cb = TRUE) |>
  clean_names() |>
  filter(geoid %in% ashland)
message("geo_ashland pulled: ", nrow(geo_ashland), " rows, CRS ",
        st_crs(geo_ashland)$input)

## 4. puma_region PUMAs (2020-vintage, resolved via year = 2022) ----
# tigris's PUMA-code column carries a vintage suffix (e.g. "pumace20") that has shifted
# across TIGER releases. Match it by pattern rather than hardcode the suffix, so a
# tigris update that renames it doesn't silently break the filter -- fail loudly instead.
message("Pulling VA PUMAs (year = 2022, 2020-vintage codes)...")
pumas_raw <- pumas(state = "VA", year = 2022) |>
  clean_names()

puma_col <- names(pumas_raw) |> str_subset("^pumace") |> pluck(1)
if (is.null(puma_col)) {
  stop("geo.R: no column matching '^pumace' found in tigris::pumas() output -- ",
       "inspect names(pumas_raw) and update the pattern to match the current release.")
}
message("Matched PUMA code column: ", puma_col)

geo_pumas <- pumas_raw |>
  filter(.data[[puma_col]] %in% puma_region)
message("geo_pumas pulled: ", nrow(geo_pumas), " rows, CRS ", st_crs(geo_pumas)$input)

## 5. Write output ----
# .rds only -- no export_csv() for these sf frames (Phase 2 Decisions, 2026-08-06).
write_rds(geo_localities, "data/geo_localities.rds")
write_rds(geo_ashland,    "data/geo_ashland.rds")
write_rds(geo_pumas,      "data/geo_pumas.rds")
message("Wrote data/geo_localities.rds, data/geo_ashland.rds, data/geo_pumas.rds")

## 6. Validate ----
loc <- read_rds("data/geo_localities.rds")
ash <- read_rds("data/geo_ashland.rds")
pum <- read_rds("data/geo_pumas.rds")

# Structure only -- row counts, expected geographies present, no all-NA geoid column.
stopifnot(
  nrow(loc) == 8,
  all(rr %in% loc$geoid),
  !anyNA(loc$geoid),
  nrow(ash) == 1,
  all(ashland %in% ash$geoid),
  nrow(pum) == 9,
  all(puma_region %in% pum[[puma_col]])
)

message("geo.R validation passed.")
message("  geo_localities CRS: ", st_crs(loc)$input)
message("  geo_ashland CRS:    ", st_crs(ash)$input)
message("  geo_pumas CRS:      ", st_crs(pum)$input)
