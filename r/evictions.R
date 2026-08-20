# evictions.R ----
# What:   Monthly eviction filing counts for the 4 primary localities. Feeds burden.qmd's
#         eviction-filings figure, updating the 2022 Framework's pre-pandemic filings trend
#         (S10.3 in data/baseline_2022.rds).
# Source: Eviction-tracking CSVs, one file per locality, manual download to
#         data/raw/evictions/*.csv. Monthly filings_count, percent_of_historical_average
#         (locality-specific pre-pandemic baseline), and defaults_count, Jan 2016-Jun 2026.
# Output: data/evictions.rds  (+ data-out/evictions.csv)

## 1. Setup ----
library(tidyverse)
library(janitor)
source("_common.R") # pha; export_csv()

raw_dir <- "data/raw/evictions"
files <- list.files(raw_dir, pattern = "\\.csv$", full.names = TRUE)
stopifnot(length(files) == 4)

## 2. Read and bind the 4 locality files ----
raw <- files |>
  map(\(f) read_csv(f, show_col_types = FALSE)) |>
  list_rbind() |>
  clean_names()

message("Eviction filing rows read: ", nrow(raw))

## 3. Map jurisdiction to geoid and tidy ----
# jurisdiction strings are the CSV source's own locality labels; mapped to `pha` geoids
# and to the locality label convention used elsewhere in this repo (chas.R, burden.qmd's
# fig-severe-trend: "Richmond city", "Chesterfield", "Henrico", "Hanover").
jurisdiction_map <- c(
  "Richmond City, Virginia" = "richmond",
  "Chesterfield, Virginia"  = "chesterfield",
  "Henrico, Virginia"       = "henrico",
  "Hanover, Virginia"       = "hanover"
)
locality_labels <- c(
  richmond = "Richmond city", chesterfield = "Chesterfield",
  henrico = "Henrico", hanover = "Hanover"
)

evictions <- raw |>
  mutate(
    locality_key = jurisdiction_map[jurisdiction],
    geoid = pha[locality_key],
    locality = locality_labels[locality_key],
    month = as.Date(month_start_date),
    year = year(month)
  ) |>
  select(geoid, locality, month, year, filings_count, percent_of_historical_average, defaults_count)

## 4. Write output ----
write_rds(evictions, "data/evictions.rds")
export_csv(evictions, "evictions")
message("Wrote data/evictions.rds + data-out/evictions.csv (", nrow(evictions), " rows)")

## 5. Validate ----
d <- read_rds("data/evictions.rds")
stopifnot(
  nrow(d) > 0,
  setequal(unique(d$geoid), unname(pha)),
  !anyNA(d$geoid),
  !anyNA(d$filings_count),
  min(d$year) == 2016
)

message("Localities represented: ", n_distinct(d$geoid), " of ", length(pha))
message("Year range: ", min(d$year), "-", max(d$year))
annual_2025 <- d |> filter(year == 2025) |> summarise(total = sum(filings_count), .by = locality)
print(annual_2025)
message("evictions.R validation passed.")
