# mls_stats.R ----
# What:   Summarizes MLS closed-sale transactions by month, locality, and new/resale status
# Source: data/mls.rds  (r/mls_clean.R → r/mls_geocode.R; Bright MLS closed sales 2020-2026)
# Output: data/mls_stats.rds  (+ data-out/mls_stats.csv)
#
# Output shape: one row per month × county (10 levels) × new_resale (All/New/Resale).
# County levels: 8 individual RR localities + "PHA Primary" (4-locality aggregate)
# + "Richmond Region" (all-8 aggregate).
#
# Columns: n_sales, med_sales_price, med_price_per_sqft, med_dom, pct_under_7_dom,
#          pct_cash, pct_new (NA for new_resale != "All").

## 1. Setup ----
library(tidyverse)
library(lubridate)
library(here)
source("_common.R") # export_csv()

dir.create("data", showWarnings = FALSE, recursive = TRUE)
dir.create("data-out", showWarnings = FALSE, recursive = TRUE)

## 2. Load and inspect sold_terms ----
d <- read_rds(here("data/mls.rds"))
message("Loaded mls.rds: ", nrow(d), " rows")

# Print sold_terms distribution before writing the cash regex (Section 3).
# Confirm the cash value string matches the pattern below; adjust if needed.
message("\n--- sold_terms counts (verify cash pattern) ---")
print(count(d, sold_terms, sort = TRUE), n = 25)
message("-----------------------------------------------\n")

## 3. Derive helper columns ----

# MLS county strings (raw from Bright MLS; not recoded in mls_clean.R)
pha_primary <- c(
  "Richmond City",
  "Henrico",
  "Chesterfield",
  "Hanover"
)

rr_all <- c(
  pha_primary,
  "Goochland",
  "Powhatan",
  "New Kent",
  "Charles City County"
)

# Cash regex: adjust to match actual values from the printout above.
# Expected MLS sold_terms values include strings like "Cash", "Conventional",
# "FHA", "VA Loan", "Conventional w/ Seller Assist", etc.
cash_pattern <- regex("^cash", ignore_case = TRUE)

d <- d |>
  filter(county %in% rr_all) |>
  mutate(
    month = floor_date(sales_date, "month"),
    price_per_sqft = if_else(
      sqft_total > 0,
      sales_price / sqft_total,
      NA_real_
    ),
    is_cash = str_detect(sold_terms, cash_pattern)
  )

## 4. Summarize helper ----
# .by_cols: character vector of grouping columns.
# pct_new is computed for all rows; callers set it NA for non-"All" cuts.
summarize_stats <- function(df, by_cols) {
  df |>
    summarize(
      n_sales = n(),
      med_sales_price = median(sales_price, na.rm = TRUE),
      med_price_per_sqft = median(price_per_sqft, na.rm = TRUE),
      med_dom = median(days_on_market, na.rm = TRUE),
      pct_under_7_dom = mean(days_on_market <= 7, na.rm = TRUE),
      pct_cash = mean(is_cash, na.rm = TRUE),
      pct_new = mean(new_resale == "New", na.rm = TRUE),
      .by = all_of(by_cols)
    )
}

## 5. Build three new_resale cuts ----
# Prefiltered data frames for each cut; used by both individual and aggregate sections.
cuts <- list(
  All = d,
  New = filter(d, new_resale == "New"),
  Resale = filter(d, new_resale == "Resale")
)

## 6. Per-locality rows (8 individual counties) ----
stats_individual <- imap(cuts, \(df, label) {
  df |>
    summarize_stats(by_cols = c("county", "month")) |>
    mutate(new_resale = label)
}) |>
  list_rbind()

## 7. Aggregate rows (PHA Primary + Richmond Region) ----
build_agg <- function(locality_set, agg_label) {
  imap(cuts, \(df, nr_label) {
    df |>
      filter(county %in% locality_set) |>
      summarize_stats(by_cols = "month") |>
      mutate(county = agg_label, new_resale = nr_label)
  }) |>
    list_rbind()
}

stats_pha <- build_agg(pha_primary, "PHA Primary")
stats_region <- build_agg(rr_all, "Richmond Region")

## 8. Bind, complete grid, finalize ----
county_levels <- c(rr_all, "PHA Primary", "Richmond Region")

mls_stats <- bind_rows(stats_individual, stats_pha, stats_region) |>
  tidyr::complete(
    month = seq(min(month), max(month), by = "month"),
    county,
    new_resale,
    fill = list(n_sales = 0L) # stat cols default to NA; n_sales = 0 for empty cells
  ) |>
  mutate(
    # pct_new is only meaningful on the "All" cut; NA on "New"/"Resale" rows avoids triviality
    pct_new = if_else(new_resale != "All", NA_real_, pct_new),
    county = factor(county, levels = county_levels),
    n_sales = as.integer(n_sales)
  ) |>
  arrange(month, county, new_resale)

## 9. Write output ----
write_rds(mls_stats, here("data/mls_stats.rds"))
export_csv(mls_stats, "mls_stats") # → data-out/mls_stats.csv (mls_ prefix: gitignored)
message("Wrote data/mls_stats.rds + data-out/mls_stats.csv")

## 10. Validate ----
stopifnot(
  "wrong month count" = n_distinct(mls_stats$month) == 78L,
  "wrong locality count" = n_distinct(mls_stats$county) == 10L,
  "wrong new_resale vals" = setequal(
    unique(mls_stats$new_resale),
    c("All", "New", "Resale")
  ),
  "price floor failed" = min(mls_stats$med_sales_price, na.rm = TRUE) > 50000
)

# 2022 baseline: log as percentage-change reference; never stopifnot() (vintages differ).
baseline_2022 <- mls_stats |>
  filter(
    as.character(county) == "Richmond Region",
    new_resale == "All",
    year(month) == 2022
  ) |>
  pull(med_sales_price) |>
  median(na.rm = TRUE)

message(sprintf(
  "2022 Richmond Region median sales price (baseline): $%s",
  format(round(baseline_2022), big.mark = ",")
))

message("mls_stats.R validation passed.")
