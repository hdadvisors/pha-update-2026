# mls.R ----
# What:   Prep monthly MLS median sale and list prices for the PHA region.
#         Values are NOMINAL dollars (not inflation-adjusted).
# Source: Bright MLS summary export (manual drop), Jan 2016 - latest month.
#         Input: data/raw/mls/mls_pha_summary_price.csv
# Output: data/mls_monthly.rds  (+ data-out/mls_monthly_price.csv — private, gitignored)

## 1. Setup ----
library(tidyverse)
library(janitor)
source("_common.R")   # export_csv(), mls_cap()

dir.create("data", showWarnings = FALSE, recursive = TRUE)

## 2. Read and tidy ----
mls_monthly <- read_csv("data/raw/mls/mls_pha_summary_price.csv") |>
  clean_names() |>
  mutate(
    month = my(month),
    across(c(sale_price_median, list_price_median), parse_number)
  ) |>
  pivot_longer(
    cols = c(sale_price_median, list_price_median),
    names_to = "metric",
    values_to = "price"
  ) |>
  mutate(
    metric = recode_values(
      metric,
      "sale_price_median" ~ "Median sale price",
      "list_price_median" ~ "Median list price"
    )
  )

message("MLS monthly prices tidied: ", nrow(mls_monthly), " rows")

## 3. Write output ----
write_rds(mls_monthly, "data/mls_monthly.rds")
export_csv(mls_monthly, "mls_monthly_price")
message("Wrote data/mls_monthly.rds + data-out/mls_monthly_price.csv")

## 4. Validate ----
d <- read_rds("data/mls_monthly.rds")
stopifnot(
  !anyNA(d$month),
  !anyNA(d$price),
  nrow(d) >= 100,                      # ~consecutive months x 2 metrics
  year(max(d$month)) == 2026
)
message(
  "mls.R validation passed. Range: ",
  format(min(d$month), "%b %Y"), " - ", format(max(d$month), "%b %Y"),
  " | rows: ", nrow(d),
  " | latest median sale price: ",
  scales::label_dollar()(d$price[d$month == max(d$month) & d$metric == "Median sale price"])
)
