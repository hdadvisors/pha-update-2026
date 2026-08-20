# mls_clean.R ----
# What:   Merge, clean, and dedupe the 80 raw MLS transaction-level exports into one
#         analysis-ready dataset. No geocoding here -- see mls_geocode.R.
# Source: Bright MLS (CVR MLS) closed-sale exports, manual drop, 2019-12-23 - 2026-07-23.
#         Input: data/raw/mls/mls_rr_*.csv (80 files)
#         Methodology: data/raw/mls/data-notes.md (PID+date dedupe investigation).
# Output: data/mls_transactions.rds
#         (+ data-out/mls_transactions.csv, data-out/mls_manual_review.csv -- private, gitignored)

## 1. Setup ----
library(tidyverse)
library(janitor)
source("_common.R")   # export_csv()

dir.create("data", showWarnings = FALSE, recursive = TRUE)

# Placeholder PID values that are not usable for matching (data-notes.md).
pid_placeholders <- c("NO TAX RECORD", "TBD", "NOT YET ASSIGNED")

# The three outside-tolerance cross-MLS pairs data-notes.md confirmed by hand as the
# same sale -- drop the REIN/BRT twin even though price/sqft fall outside the auto-resolve
# tolerance.
confirmed_outside_tolerance <- c("REIN10401157", "BRTVAHA2000158", "REIN10611370")

# Address-less BRTVA records confirmed as duplicates of a CVR record (data-notes.md
# manual-research table). Everything else in that address-less bucket (same-property-
# not-duplicate, or genuinely unrecoverable) needs no action -- it's kept by default.
addressless_confirmed_duplicates <- c(
  "BRTVAGO2000096", "BRTVANK2000050", "BRTVACF2000588", "BRTVACF2000976",
  "BRTVARC2000104", "BRTVACF2000312", "BRTVAHA2000768", "BRTVAHA2000808",
  "BRTVAHN2000180"
)

## 2. Read and combine ----
# Every column comes in as character -- raw price/sqft fields carry "$", commas, and
# quoting varies by export batch. Numeric coercion happens explicitly in step 3.
mls_files <- list.files(
  "data/raw/mls",
  pattern = "^mls_rr_[0-9]{4}_[0-9]{2}\\.csv$",
  full.names = TRUE
)

mls_raw <- map(mls_files, \(f) {
  read_csv(f, col_types = cols(.default = "c")) |>
    clean_names() |>
    mutate(source_file = basename(f))
}) |>
  list_rbind()

message("Combined ", length(mls_files), " files: ", nrow(mls_raw), " rows")

## 3. Canonical address + numeric fields ----
mls0 <- mls_raw |>
  mutate(
    address_raw = coalesce(address, address_line),
    street      = str_squish(str_split_i(address_raw, ",", 1)),
    sales_date  = mdy(sales_date),
    list_price  = parse_number(list_price),
    sales_price = parse_number(sales_price),
    # 0 is not a valid sqft/bed/bath count for a completed residential sale -- treat as
    # missing rather than real (acres is left alone: 0 is a legitimate value for a condo
    # with no dedicated land).
    sqft_total  = na_if(parse_number(sq_ft_total), 0),
    acres       = parse_number(acres),
    beds        = na_if(parse_number(number_bedrooms), 0),
    baths_total = na_if(parse_number(total_baths), 0),
    days_on_market = parse_number(days_on_market),
    year_built  = parse_number(year_built),
    is_cross_mls = !str_detect(ml_number, "^[0-9]+$"),
    row_id      = row_number()
  ) |>
  select(
    row_id, ml_number, pid, status, street, county = county_city, zip,
    property_type = type, sales_date, list_price, sales_price, days_on_market,
    new_resale, year_built, subdivision, sqft_total, acres, beds, baths_total,
    water, sewer, sold_terms, owned_by, is_cross_mls, source_file
  )

## 4. Dedupe ----

# 4a. Drop the 42 exact full-row duplicate ML#s from the 2022-02-10 export-boundary
#     overlap (mls_rr_2022_01 / mls_rr_2022_02).
n_before_exact <- nrow(mls0)
mls1 <- mls0 |> distinct(ml_number, .keep_all = TRUE)
message("Dropped ", n_before_exact - nrow(mls1), " exact-duplicate ML# rows")

# 4b. Normalize PID. Check the placeholder exclusion list on the RAW string first --
#     stripping punctuation before checking turns "Not Yet Assigned" into
#     "NOTYETASSIGNED", which escapes the exclusion list and creates false joins.
mls1 <- mls1 |>
  mutate(
    pid_norm = if_else(
      str_to_upper(str_trim(pid)) %in% pid_placeholders,
      NA_character_,
      str_to_upper(str_remove_all(pid, "[^A-Za-z0-9]"))
    ),
    pid_norm   = na_if(pid_norm, ""),
    street_norm = na_if(str_to_upper(str_remove_all(street, "[^A-Za-z0-9]")), "")
  )

cvr   <- mls1 |> filter(!is_cross_mls)
cross <- mls1 |> filter(is_cross_mls)

# Candidate CVR match columns, reused across passes. Renamed away from `ml_number` up
# front so the join never has to disambiguate two same-named columns.
cvr_keyed <- cvr |>
  select(cvr_row_id = row_id, cvr_ml_number = ml_number, pid_norm, street_norm, zip,
         sales_date, cvr_price = sales_price, cvr_sqft = sqft_total)

within_tolerance <- function(price, cvr_price, sqft, cvr_sqft) {
  abs(price - cvr_price) <= 1000 & abs(sqft - cvr_sqft) <= 100
}

# Pass 1: PID + date (primary key).
pass1 <- cross |>
  filter(!is.na(pid_norm)) |>
  inner_join(
    cvr_keyed |> filter(!is.na(pid_norm)) |> select(-street_norm, -zip),
    by = join_by(pid_norm, sales_date),
    relationship = "many-to-many"
  ) |>
  mutate(matched_on = "pid_date")

# Pass 2: street + date + price safety net -- catches cross-MLS pairs where the two
# source systems disagree on PID (confirmed by investigation: every address+date+price
# match with disagreeing PIDs found in this dataset is a cross-MLS pair, never a same-MLS
# coincidence -- safe to run unconditionally, not just when PID is missing/placeholder).
pass2 <- cross |>
  filter(!is.na(street_norm)) |>
  inner_join(
    cvr_keyed |> select(-pid_norm, -zip),
    by = join_by(street_norm, sales_date),
    relationship = "many-to-many"
  ) |>
  # price equality is enforced by filter(), not join_by() -- join_by(a == b) between
  # differently-named columns collapses them into one column and drops the other, which
  # would silently lose cvr_price for every row here.
  filter(sales_price == cvr_price) |>
  mutate(matched_on = "street_date_price")

# Pass 3: address-less cross-MLS rows -- match on date + price + zip instead of street
# (data-notes.md: 14 of the 36 address-less BRTVA rows resolve this way).
pass3 <- cross |>
  filter(is.na(street_norm), !is.na(zip)) |>
  inner_join(
    cvr_keyed |> select(-pid_norm, -street_norm),
    by = join_by(zip, sales_date),
    relationship = "many-to-many"
  ) |>
  filter(sales_price == cvr_price) |>
  mutate(matched_on = "zip_date_price")

matches <- bind_rows(pass1, pass2, pass3) |>
  mutate(
    within_tol = within_tolerance(sales_price, cvr_price, sqft_total, cvr_sqft)
  ) |>
  # keep one match per cross-MLS row: prefer pid_date, then an in-tolerance match
  arrange(row_id, matched_on != "pid_date", desc(within_tol)) |>
  distinct(row_id, .keep_all = TRUE)

message(
  "Cross-MLS matches found: ", nrow(matches),
  " (", sum(matches$matched_on == "pid_date"), " by PID+date, ",
  sum(matches$matched_on == "street_date_price"), " by street+date+price, ",
  sum(matches$matched_on == "zip_date_price"), " by zip+date+price)"
)

auto_drop_ml <- matches |>
  filter(within_tol | ml_number %in% confirmed_outside_tolerance) |>
  pull(ml_number) |>
  unique()

# 4c. Address-less BRTVA records confirmed as duplicates by manual research, independent
#     of the pass 1-3 matching above (some of these have no CVR match at all to key off).
auto_drop_ml <- union(auto_drop_ml, addressless_confirmed_duplicates)

manual_review_matches <- matches |>
  # NA within_tol (missing sqft on one side) can't be confirmed either way -- route to
  # review rather than letting it silently pass through as a non-duplicate. Exclude any
  # row already force-resolved above (hardcoded confirmed pairs) so it isn't flagged for
  # review and dropped from the output at the same time.
  filter(!(within_tol %in% TRUE), !(ml_number %in% auto_drop_ml))

n_before_cross <- nrow(mls1)
mls2 <- mls1 |> filter(!(ml_number %in% auto_drop_ml))
message(
  "Dropped ", n_before_cross - nrow(mls2), " cross-MLS duplicate rows (",
  length(auto_drop_ml), " ML#s)"
)

## 5. Analysis-window filter ----
# Combine on actual Sales Date (not each file's declared export window) -- 103 boundary
# rows depend on being included here rather than filtered by file.
mls3 <- mls2 |>
  filter(sales_date >= ymd("2020-01-01"), sales_date <= ymd("2026-06-30"))
message("Filtered to analysis window: ", nrow(mls3), " rows")

## 6. Final columns ----
mls_transactions <- mls3 |>
  select(
    ml_number, pid, status, street, county, zip, property_type, sales_date,
    list_price, sales_price, days_on_market, new_resale, year_built, subdivision,
    sqft_total, acres, beds, baths_total, water, sewer, sold_terms, owned_by,
    is_cross_mls
  )

mls_manual_review <- manual_review_matches |>
  select(
    ml_number, cvr_ml_number, street, zip, sales_date, sales_price,
    cvr_price, sqft_total, cvr_sqft, matched_on
  )

## 7. Write output ----
write_rds(mls_transactions, "data/mls_transactions.rds")
export_csv(mls_transactions, "mls_transactions")
export_csv(mls_manual_review, "mls_manual_review")
message(
  "Wrote data/mls_transactions.rds + data-out/mls_transactions.csv",
  " + data-out/mls_manual_review.csv"
)

## 8. Validate ----
d <- read_rds("data/mls_transactions.rds")
stopifnot(
  nrow(d) > 100000, nrow(d) < 110450,
  !anyNA(d$sales_date),
  !anyNA(d$sales_price),
  min(d$sales_date) >= ymd("2020-01-01"),
  max(d$sales_date) <= ymd("2026-06-30"),
  all(c("2128471", "2209684", "202500335") %in% d$ml_number),
  !any(c("REIN10401157", "BRTVAHA2000158", "REIN10611370") %in% d$ml_number)
)
message(
  "mls_clean.R validation passed. Rows: ", nrow(d),
  " | date range: ", format(min(d$sales_date)), " - ", format(max(d$sales_date)),
  " | cross-MLS share: ", scales::label_percent(accuracy = 0.1)(mean(d$is_cross_mls)),
  " | manual review rows: ", nrow(mls_manual_review)
)
