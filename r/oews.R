# oews.R ----
# What:   BLS OEWS 2024 wage data for the Richmond MSA. Annual median and
#         percentile wages by occupation, cross-industry. The wage columns
#         feed r/affordcalc.R's income_needed / max_affordable functions via
#         downstream scripts (e.g. gaps.R) -- join on annual_wage_median as
#         the annual household income input.
# Source: BLS Occupational Employment and Wage Statistics (OEWS), May 2024
#         release, MSA-level file (manual download).
#         File: data/raw/oews/MSA_M2025_dl.xlsx
#         All 621 rows in this file are Richmond MSA (area = "40060",
#         area_title = "Richmond, VA") -- no area filtering required.
#         All rows are cross-industry (i_group = "cross-industry").
# Note:   BLS suppresses some wages as "*" (confidentiality) or "#" (wage
#         exceeds the $239,200 annual cap). Both are converted to NA_real_.
#         o_group levels: "total" (1 row, all occupations), "major" (22 rows,
#         SOC major groups), "detailed" (598 rows, 6-digit SOC codes).
#         Hourly wage columns (h_*) are retained in the raw read but not
#         written to the output -- annual wages (a_*) are the unit this
#         project uses for affordability comparisons.
# Output: data/oews.rds       (+ data-out/oews.csv)

## 1. Setup ----
library(tidyverse)
library(readxl)
library(janitor)
source("_common.R")  # export_csv(), oews_cap()

oews_path <- "data/raw/oews/MSA_M2025_dl.xlsx"
stopifnot(file.exists(oews_path))
dir.create("data", showWarnings = FALSE, recursive = TRUE)

# BLS OEWS special codes that appear in wage columns
WAGE_SUPPRESSED <- c("*", "#")

## 2. Read ----
message("Reading OEWS MSA file...")
raw <- read_excel(oews_path) |>
  clean_names()
message("Rows read: ", nrow(raw))

## 3. Recode wage columns and select output fields ----
# Wage columns arrive as character because of the "*" and "#" codes.
# parse_number() silently drops those non-numeric strings; they become NA.
oews <- raw |>
  mutate(
    across(
      c(a_median, a_pct10, a_pct25, a_pct75, a_pct90),
      \(x) suppressWarnings(as.numeric(x))
    )
  ) |>
  select(
    area,
    area_title,
    occ_code,
    occ_title,
    o_group,
    tot_emp,
    annual_wage_median = a_median,
    annual_wage_p10    = a_pct10,
    annual_wage_p25    = a_pct25,
    annual_wage_p75    = a_pct75,
    annual_wage_p90    = a_pct90
  )

message("Wage NAs after special-code conversion (median / p10 / p25 / p75 / p90):")
message(paste(
  sapply(c("annual_wage_median","annual_wage_p10","annual_wage_p25",
           "annual_wage_p75","annual_wage_p90"),
         \(col) sum(is.na(oews[[col]]))),
  collapse = " / "
))

## 4. Write output ----
write_rds(oews, "data/oews.rds")
export_csv(oews, "oews")
message("Wrote data/oews.rds + data-out/oews.csv (", nrow(oews), " rows)")

## 5. Validate ----
d <- read_rds("data/oews.rds")

stopifnot(
  # Richmond MSA rows present
  "40060" %in% d$area,
  # All-occupations median wage is non-NA (structural: the one o_group == "total" row)
  !is.na(d$annual_wage_median[d$o_group == "total"]),
  # At least 50 detailed-occupation rows (guards against a silent empty filter)
  sum(d$o_group == "detailed") >= 50
)

all_occ_median <- d$annual_wage_median[d$occ_code == "00-0000"]
message("Richmond MSA -- All Occupations annual median wage: ",
        scales::dollar(all_occ_median))
message("Detailed occupations: ", sum(d$o_group == "detailed"))
message("Suppressed median wages (NA): ",
        sum(is.na(d$annual_wage_median)))
message("oews.R validation passed.")
