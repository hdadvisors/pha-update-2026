# fred.R ----
# What:   30-year fixed mortgage rate (Freddie Mac PMMS), weekly resampled to a monthly
#         average. Feeds ownership.qmd's rate-vs-price affordability chart.
# Source: FRED via fredr, series MORTGAGE30US, national, weekly, 2000-01-01 through
#         latest available.
# Output: data/fred.rds  (+ data-out/fred.csv)

## 1. Setup ----
library(tidyverse)
library(fredr)
source("_common.R")   # pmms_cap(); export_csv()

# .Renviron fallback (R's HOME may not be ~/Documents on this machine)
if (Sys.getenv("FRED_API_KEY") == "") {
  renviron_path <- file.path(Sys.getenv("USERPROFILE"), "Documents", ".Renviron")
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}
stopifnot(Sys.getenv("FRED_API_KEY") != "")
fredr_set_key(Sys.getenv("FRED_API_KEY"))

dir.create("data", showWarnings = FALSE, recursive = TRUE)

## 2. Pull the weekly PMMS series ----
message("Pulling FRED MORTGAGE30US...")
pmms_weekly <- fredr(
  series_id = "MORTGAGE30US",
  observation_start = as.Date("2000-01-01")
) |>
  select(date, value) |>
  rename(rate = value) |>
  filter(!is.na(rate))
message("PMMS weekly observations pulled: ", nrow(pmms_weekly))

## 3. Resample to a monthly average, to align with the MLS monthly series ----
pmms <- pmms_weekly |>
  mutate(month = floor_date(date, "month")) |>
  summarise(rate = mean(rate), .by = month) |>
  arrange(month)

## 4. Write output ----
write_rds(pmms, "data/fred.rds")
export_csv(pmms, "fred")
message("Wrote data/fred.rds + data-out/fred.csv (", nrow(pmms), " rows)")

## 5. Validate ----
d <- read_rds("data/fred.rds")
stopifnot(
  nrow(d) > 0,
  !anyNA(d$rate),
  all(d$rate > 0, d$rate < 25)   # structural sanity bound, not a benchmark
)

message("Latest PMMS monthly average: ", round(d$rate[which.max(d$month)], 2),
        "% as of ", format(max(d$month), "%B %Y"))
message("fred.R validation passed.")
