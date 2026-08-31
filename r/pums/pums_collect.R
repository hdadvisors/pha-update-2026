# pums_collect.R ----
# What:   Downloads ACS PUMS person + housing records for Virginia, then filters to the
#         Richmond-area PUMAs (`puma_region`). Two pulls: one for analysis variables,
#         one for replicate weights. Both are cached; re-running skips a completed
#         download unless PUMS_REFETCH=1 is set.
# Source: tidycensus::get_pums(), ACS 2020-2024 5-year PUMS, state = "VA".
# Note:   tidycensus has no PUMA-level filter argument for get_pums() — the whole state
#         comes down and PUMA is filtered after.
# Output: data/pums_raw.rds  (analysis variables, Richmond-area PUMAs)
#         data/pums_wgt.rds  (WGTP1-80 + PWGTP1-80 replicate weights, same rows)
#         data/pums_vars.rds (the requested variable vector, consumed by pums_labels.R)
# No CSV: raw microdata is not exported to data-out/. export_csv() pairs live on the
#         aggregated outputs downstream (pums_ami.R, pums_gap.R).

## 1. Setup ----

library(tidyverse)
library(tidycensus)
source("_common.R") # puma_region, puma_core3, puma_locality

# .Renviron fallback
if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- file.path(Sys.getenv("USERPROFILE"), "Documents", ".Renviron")
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}

message("CENSUS_API_KEY present: ", Sys.getenv("CENSUS_API_KEY") != "")
stopifnot(Sys.getenv("CENSUS_API_KEY") != "")

dir.create("data", showWarnings = FALSE, recursive = TRUE)

pums_year <- 2024 # 2020-2024 ACS 5-year PUMS
refetch <- Sys.getenv("PUMS_REFETCH") == "1"

## 2. Variable set ----
# Note: adding a variable later means re-running the whole state download.

# Housing record — geography, household size, and the dollar-adjustment factors
vars_hr_basic <- c(
  "PUMA", # PUMA (2020 definition; the 2020-2024 sample has no PUMA10/PUMA20 split)
  "NP", # Number of persons in household
  # A 5-year PUMS file mixes five survey years of dollars: HINCP, GRNTP, and SMOCP are
  # each reported in the dollars of that record's own survey year. These two factors put
  # them all in 2024 dollars, and they are the only thing in the file that encodes which
  # year a record came from. Without them, AMI banding against the FY2026 income limits
  # pushes early-year households into lower bands.
  "ADJINC", # Income adjustment factor (income variables -> 2024 dollars)
  "ADJHSG" # Housing cost adjustment factor (GRNTP, SMOCP -> 2024 dollars)
)

# Housing record — housing unit characteristics
vars_hr_hu <- c(
  "BDSP", # Number of bedrooms
  "BLD", # Units in structure
  "FS", # SNAP status
  "TEN", # Tenure
  "YRBLT" # When structure first built
)

# Housing record — household characteristics, income, and housing cost
vars_hr_hh <- c(
  "FINCP", # Family income
  "GRNTP", # Gross rent
  "GRPIP", # Gross rent as a percentage of household income
  "HHLDRHISP", # Householder Hispanic origin
  "HHLDRRAC1P", # Householder race
  "HHT2", # Household/family type (includes cohabiting)
  "HINCP", # Household income
  "MULTG", # Multigenerational household
  "MV", # When moved into home
  "NOC", # Number of own children
  "OCPIP", # Selected monthly owner costs as a percentage of household income
  "SMOCP", # Selected monthly owner costs
  "WIF" # Workers in family
)

# Person record — person characteristics and income sources
vars_pr_p <- c(
  "AGEP", # Age
  "COW", # Class of worker
  "HINS3", # Medicare
  "HINS4", # Medicaid
  "INTP", # Interest, dividends, and net rental income
  "JWMNP", # Travel time to work
  "JWRIP", # Carpool status
  "JWTRNS", # Means of transportation to work
  "OIP", # All other income
  "PAP", # Public assistance income
  "RELSHIPP", # Relationship to householder
  "RETP", # Retirement income
  "SCHL", # Educational attainment
  "SEMP", # Self-employment income
  "SEX", # Sex
  "SSIP", # Supplemental Security Income amount
  "SSP", # Social Security amount
  "WAGP", # Wages or salary income
  "WKL" # When last worked
)

# Person record — recoded/derived person variables
vars_pr_rcp <- c(
  "DIS", # Disability
  "ESR", # Employment status recode
  "NAICSP", # NAICS industry recode
  "POWPUMA", # Place of work PUMA
  "POWSP", # Place of work state
  "SOCP" # SOC occupation code
)

pums_vars_all <- c(vars_hr_basic, vars_hr_hu, vars_hr_hh, vars_pr_p, vars_pr_rcp)

message("Variables requested: ", length(pums_vars_all))

## 3. Pre-flight variable check ----
# Validate every name against the PUMS data dictionary BEFORE the download, so one run
# reports every bad name instead of failing on the first. Skipped if the pinned
# tidycensus dictionary has no rows for this vintage.

pums_dict <- pums_variables |>
  filter(year == pums_year, survey == "acs5")

if (nrow(pums_dict) == 0) {
  message(
    "No pums_variables rows for ", pums_year, " acs5 — skipping the pre-flight check."
  )
} else {
  missing_vars <- setdiff(pums_vars_all, unique(pums_dict$var_code))
  if (length(missing_vars) > 0) {
    stop(
      "Variables absent from the ", pums_year, " acs5 PUMS dictionary: ",
      paste(missing_vars, collapse = ", ")
    )
  }
  message("Pre-flight check passed: all ", length(pums_vars_all), " variables exist.")
}

write_rds(pums_vars_all, "data/pums_vars.rds")

## 4. Pull analysis variables ----
# Whole-state pull, then filter to the Richmond-area PUMAs. `puma_region` is the wider
# 9-PUMA set. Filtering to `puma_core3` happens downstream in pums_prep.R.

if (file.exists("data/pums_raw.rds") && !refetch) {
  message("data/pums_raw.rds exists — skipping the pull (set PUMS_REFETCH=1 to force).")
  pums_raw <- read_rds("data/pums_raw.rds")
} else {
  message("Pulling PUMS analysis variables for VA (this takes several minutes)...")
  pums_raw <- get_pums(
    variables = pums_vars_all,
    year = pums_year,
    state = "VA",
    survey = "acs5"
  ) |>
    filter(PUMA %in% puma_region)

  write_rds(pums_raw, "data/pums_raw.rds")
  message("Wrote data/pums_raw.rds")
}

message("pums_raw rows: ", nrow(pums_raw), " | columns: ", ncol(pums_raw))

## 5. Pull replicate weights ----
# Separate call with rep_weights = "both" — returns WGTP1-80 (housing) and PWGTP1-80
# (person). Kept apart from the variable pull so the wide weight columns do not have to
# be re-downloaded if the variable list changes.

if (file.exists("data/pums_wgt.rds") && !refetch) {
  message("data/pums_wgt.rds exists — skipping the pull (set PUMS_REFETCH=1 to force).")
  pums_wgt <- read_rds("data/pums_wgt.rds")
} else {
  message("Pulling PUMS replicate weights for VA (this takes several minutes)...")
  pums_wgt <- get_pums(
    variables = "PUMA",
    year = pums_year,
    state = "VA",
    survey = "acs5",
    rep_weights = "both"
  ) |>
    filter(PUMA %in% puma_region)

  write_rds(pums_wgt, "data/pums_wgt.rds")
  message("Wrote data/pums_wgt.rds")
}

message("pums_wgt rows: ", nrow(pums_wgt), " | columns: ", ncol(pums_wgt))

## 6. Validate ----

# Structural checks only.
stopifnot(
  nrow(pums_raw) > 0,
  nrow(pums_wgt) > 0,
  # Both pulls cover the same record universe
  nrow(pums_raw) == nrow(pums_wgt),
  # Every requested variable survived the pull
  all(pums_vars_all %in% names(pums_raw)),
  # get_pums() identifiers and default weights are present
  all(c("SERIALNO", "SPORDER", "WGTP", "PWGTP") %in% names(pums_raw)),
  # Dollar-adjustment factors arrived and cover more than one survey year, which is what
  # a 5-year file must look like. A single distinct ADJINC means a 1-year file.
  n_distinct(pums_raw$ADJINC) > 1,
  n_distinct(pums_raw$ADJHSG) > 1,
  # All 80 housing + 80 person replicate weights arrived
  sum(str_detect(names(pums_wgt), "^WGTP\\d+$")) == 80,
  sum(str_detect(names(pums_wgt), "^PWGTP\\d+$")) == 80,
  # Every PUMA in the region set is represented, and nothing outside it leaked in
  setequal(unique(pums_raw$PUMA), puma_region),
  all(puma_core3 %in% unique(pums_raw$PUMA))
)

# Record counts by PUMA and locality tiling, for the session log.
message("\nPerson records by PUMA:")
pums_raw |>
  count(PUMA, name = "persons") |>
  mutate(locality = coalesce(puma_locality[PUMA], "Mixed outer PUMA")) |>
  arrange(PUMA) |>
  as.data.frame() |>
  print(row.names = FALSE)

message("\nHousehold records (SPORDER == 1): ", sum(pums_raw$SPORDER == 1))
message("Vacant / group-quarters records (TEN == 'b'): ", sum(pums_raw$TEN == "b"))

# Weighted totals as an order-of-magnitude sanity read.
message(
  "\nWeighted persons (core-3): ",
  format(sum(pums_raw$PWGTP[pums_raw$PUMA %in% puma_core3]), big.mark = ",")
)
message(
  "Weighted households (core-3): ",
  format(
    sum(pums_raw$WGTP[pums_raw$SPORDER == 1 & pums_raw$PUMA %in% puma_core3]),
    big.mark = ","
  )
)

message("\npums_collect.R validation passed.")
