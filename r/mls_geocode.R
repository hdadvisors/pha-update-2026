# mls_geocode.R ----
# What:   Geocode the cleaned, deduped MLS transactions (lat/long) and write the final
#         chapter-facing dataset. Run AFTER mls_clean.R and after reviewing its manual-
#         review export.
# Source: data/mls_transactions.rds (from mls_clean.R) + Geocodio, via tidygeocoder.
# Output: data/mls.rds  (+ data-out/mls_geocoded.csv -- private, gitignored)
#
# Prerequisites (one-time, before the first run):
#   renv::install("tidygeocoder"); renv::snapshot()
#
# This is a long-running, paid, external-API job across ~20-30k distinct addresses --
# per CLAUDE.md's model/session policy, Jonathan runs this script, not Claude. Results
# are cached by distinct address (data/mls_geocode_cache.rds), so a re-run only pays for
# addresses not already geocoded.

## 1. Setup ----
library(tidyverse)
library(tidygeocoder)
source("_common.R")   # export_csv()

if (Sys.getenv("GEOCODIO_API_KEY") == "") {
  renviron_path <- file.path(Sys.getenv("USERPROFILE"), "Documents", ".Renviron")
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}
stopifnot("GEOCODIO_API_KEY is not set -- add it to .Renviron before running" =
  Sys.getenv("GEOCODIO_API_KEY") != "")

cache_path <- "data/mls_geocode_cache.rds"

## 2. Build the geocoding input ----
mls_transactions <- read_rds("data/mls_transactions.rds")

# Skip a `city` argument entirely -- County/City holds a county name (not necessarily an
# incorporated place; Richmond city is the one exception), and Zip + county is enough for
# Geocodio to resolve without guessing a place name (data-notes.md).
distinct_addresses <- mls_transactions |>
  filter(!is.na(street)) |>
  distinct(street, county, zip) |>
  mutate(full_address = paste(street, county, "Virginia", zip, sep = ", "))

message(nrow(distinct_addresses), " distinct addresses across ", nrow(mls_transactions), " transactions")

## 3. Geocode only addresses not already cached ----
geocode_cache <- if (file.exists(cache_path)) {
  read_rds(cache_path)
} else {
  tibble(full_address = character(), lat = double(), long = double())
}

to_geocode <- distinct_addresses |>
  anti_join(geocode_cache, by = "full_address")

message(nrow(to_geocode), " new addresses to geocode (", nrow(geocode_cache), " already cached)")

if (nrow(to_geocode) > 0) {
  chunk_size   <- 9000L   # Geocodio batch limit is 10,000; stay comfortably under it
  chunks       <- split(to_geocode, ceiling(seq_len(nrow(to_geocode)) / chunk_size))
  n_chunks     <- length(chunks)
  running_total <- 0L

  for (i in seq_along(chunks)) {
    chunk <- chunks[[i]]
    message("Chunk ", i, " of ", n_chunks, ": geocoding ", nrow(chunk), " addresses ...")

    geocoded_chunk <- chunk |>
      geocode(address = full_address, method = "geocodio", lat = lat, long = long)

    geocode_cache <- bind_rows(geocode_cache, geocoded_chunk |> select(full_address, lat, long))
    write_rds(geocode_cache, cache_path)

    running_total <- running_total + nrow(chunk)
    message("  Chunk ", i, " done. Running total this run: ", running_total,
            " | Cache total: ", nrow(geocode_cache))
  }
}

## 4. Join lat/long back onto every transaction ----
mls <- mls_transactions |>
  mutate(full_address = if_else(
    is.na(street), NA_character_, paste(street, county, "Virginia", zip, sep = ", ")
  )) |>
  left_join(geocode_cache, by = "full_address") |>
  select(-full_address)

## 5. Write output ----
write_rds(mls, "data/mls.rds")
export_csv(mls, "mls_geocoded")
message("Wrote data/mls.rds + data-out/mls_geocoded.csv")

## 6. Validate ----
d <- read_rds("data/mls.rds")
pct_geocoded <- mean(!is.na(d$lat))
stopifnot(
  nrow(d) == nrow(mls_transactions),
  all(c("lat", "long") %in% names(d))
)
message(
  "mls_geocode.R validation passed. Rows: ", nrow(d),
  " | geocoded: ", scales::label_percent(accuracy = 0.1)(pct_geocoded),
  " (", sum(!is.na(d$lat)), " of ", nrow(d), ")"
)
