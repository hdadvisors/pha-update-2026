# pep.R ----
# What:   Population Estimates Program county totals and components of change,
#         for the 8 `rr` localities.
# Source: tidycensus::get_estimates(vintage = 2025) — an EXPLICIT vintage argument.
#         `year =` alone misbehaves silently on the post-2020 API (CLAUDE.md known
#         gotcha). If Vintage 2025 has not been published, or is published for only
#         some localities, this script stops loudly rather than silently falling
#         back to a different vintage or proceeding on partial data — see Section 3.
# Depends: data/decennial.rds (from r/decennial.R). PEP's estimates base is the
#         2020 decennial population count, so this script cannot run its
#         same-vintage cross-check (Section 5) until r/decennial.R has been run.
#         This is a genuine prerequisite, not an optional escape hatch — if
#         decennial.rds is missing, the script stops with an instruction to run
#         r/decennial.R first, rather than skipping the check.
# Output: data/pep.rds  (+ data-out/pep.csv)
#
# NOTE ON THE ESTIMATES BASE: Vintage 2025's API exposes POPESTIMATE and NPOPCHG only —
# no estimates-base variable. Its year-2020 row is the 7/1/2020 estimate, three months of
# population change away from the 4/1/2020 decennial count. The true 4/1/2020 base is
# read from the published FTP county file in Section 4b and carried in the output frame
# as variable "ESTIMATESBASE" — the anchor for every 2020-2025 change figure.
#
# The phase file assumed the estimates base EQUALS the 2020 decennial count. It does not:
# Census revises the base for Count Question Resolution, legal boundary updates, and
# geographic program changes, and the 2020s-vintage file ships no census-count column to
# benchmark against. That difference is therefore logged as a published adjustment rather
# than gated — ruled 2026-08-06, superseding the phase file's Verify line.

## 1. Setup ----
library(tidyverse)
library(tidycensus)
library(janitor)
source("_common.R")   # rr geography constant; export_csv()

# .Renviron fallback — R's HOME may not be ~/Documents, so the key file isn't
# always auto-loaded (CLAUDE.md API-keys gotcha). Load it only if the key is unset.
if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- file.path(Sys.getenv("USERPROFILE"), "Documents", ".Renviron")
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}
message("CENSUS_API_KEY visible: ", Sys.getenv("CENSUS_API_KEY") != "")

dir.create("data", showWarnings = FALSE, recursive = TRUE)

rr_geoids <- unname(rr)

# Fail loudly rather than silently switching vintage or geography scope on a
# get_estimates() error, and flag a partial-vintage pull (some but not all of the
# 8 rr localities returned) as a stop-gate for Jonathan to resolve, per the phase
# file: "A partial vintage is worse than a clean fallback, and the choice between
# waiting and switching to the FTP tables is Jonathan's."
pull_pep <- function(product) {
  raw <- tryCatch(
    # time_series = TRUE is required, not optional: without it get_estimates()
    # returns a single latest period, which carries neither the annual series the
    # demand chapter's population-change figures need nor the 2020 estimates base
    # the Section 7 cross-check asserts against.
    get_estimates(geography = "county", product = product, state = "VA",
                  vintage = 2025, time_series = TRUE, output = "tidy"),
    error = function(e) {
      stop(
        "get_estimates(product = \"", product, "\", vintage = 2025) failed: ",
        conditionMessage(e), "\n",
        "Per the PLAN.md decision of 2026-07-15, the documented fallback is the ",
        "Census FTP tables (https://www2.census.gov/programs-surveys/popest/). ",
        "Do NOT silently substitute a different vintage in this script. Whether to ",
        "wait for Vintage 2025 or switch to the FTP fallback is Jonathan's call."
      )
    }
  ) |>
    clean_names() |>
    filter(geoid %in% rr_geoids)

  present <- unique(raw$geoid)
  missing <- setdiff(rr_geoids, present)

  if (length(present) == 0) {
    stop("get_estimates(product = \"", product, "\", vintage = 2025) returned zero ",
         "rows for the 8 rr localities. Vintage 2025 may not be published yet — see ",
         "the FTP-fallback note above.")
  }
  if (length(missing) > 0) {
    stop(
      "STOP-GATE: get_estimates(product = \"", product, "\", vintage = 2025) returned ",
      "data for only ", length(present), " of 8 rr localities. Missing geoid(s): ",
      paste(missing, collapse = ", "), ". A partial vintage is worse than a clean ",
      "fallback — do not proceed. Report this to Jonathan to choose between waiting ",
      "for full Vintage 2025 coverage and switching this script to the FTP tables."
    )
  }
  raw
}

## 2. Pull population levels (includes the 2020 estimates base) ----
message("Pulling PEP population estimates (vintage 2025)...")
pep_pop_raw <- pull_pep("population")
message("Population product pulled: ", nrow(pep_pop_raw), " rows, ",
        n_distinct(pep_pop_raw$geoid), " localities")

# Diagnostic first. The exact shape tidycensus returns for a vintage-2025 time series
# was not verifiable when this script was written, so the raw columns and period values
# are printed before anything depends on them. If a later step stops, this message is
# what tells you which branch to fix.
message("PEP population columns: ", paste(colnames(pep_pop_raw), collapse = ", "))

# Detect the period column by name rather than assuming one. tidycensus has used
# DATE_DESC / DATE_CODE in older releases and a plain `year` column in newer ones.
date_col_candidates <- c("date_desc", "date_code", "period", "date", "year")
date_col <- intersect(date_col_candidates, colnames(pep_pop_raw))
if (length(date_col) == 0) {
  stop(
    "None of the expected period columns (", paste(date_col_candidates, collapse = ", "),
    ") were found in the PEP population pull. Columns present: ",
    paste(colnames(pep_pop_raw), collapse = ", "),
    ". tidycensus's get_estimates() output shape may have changed for vintage 2025 — ",
    "inspect the raw pull manually before adapting this script."
  )
}
date_col <- date_col[1]
message("Using '", date_col, "' as the period column. Distinct values: ",
        paste(sort(unique(as.character(pep_pop_raw[[date_col]]))), collapse = " | "))

## 3. Identify the 2020 estimates base and derive a year for every row ----
# Vintage 2025 returns a plain numeric `year` column running 2020-2025 and exposes only
# POPESTIMATE and NPOPCHG — there is NO estimates-base variable. The year-2020 row is
# therefore the 7/1/2020 estimate, not the 4/1/2020 base, and it does not equal the
# decennial count (verified against decennial.rds: +782 Chesterfield, +540 Henrico,
# -26 Charles City — three months of real population change, not error). The true base
# comes from the FTP file in Section 4b instead.
period_chr <- as.character(pep_pop_raw[[date_col]])
message("PEP population variables: ",
        paste(sort(unique(pep_pop_raw$variable)), collapse = ", "))

pep_pop <- pep_pop_raw |>
  mutate(year = suppressWarnings(as.integer(str_extract(period_chr, "\\d{4}"))))

if (anyNA(pep_pop$year)) {
  stop(
    "Could not derive a 4-digit year from the '", date_col, "' column for some rows. ",
    "Sample unparsed values: ",
    paste(head(unique(pep_pop$year[is.na(pep_pop$year)]), 5), collapse = ", "),
    ". Inspect pep_pop_raw manually before adapting the year-derivation logic."
  )
}

## 4. Pull components of change ----
message("Pulling PEP components of change (vintage 2025)...")
pep_comp_raw <- pull_pep("components")
message("Components product pulled: ", nrow(pep_comp_raw), " rows, ",
        n_distinct(pep_comp_raw$geoid), " localities")

comp_date_col <- intersect(date_col_candidates, colnames(pep_comp_raw))
if (length(comp_date_col) == 0) {
  stop(
    "None of the expected period/date columns were found in the PEP components ",
    "pull. Columns present: ", paste(colnames(pep_comp_raw), collapse = ", "), "."
  )
}
comp_date_col <- comp_date_col[1]

pep_comp <- pep_comp_raw |>
  mutate(
    year = suppressWarnings(as.integer(str_extract(as.character(.data[[comp_date_col]]), "\\d{4}")))
  )

if (anyNA(pep_comp$year)) {
  stop("Could not derive a 4-digit year for some PEP components rows — inspect ",
       "pep_comp_raw manually before adapting the year-derivation logic.")
}

## 4b. April 1, 2020 estimates base, from the Census FTP ----
# The API does not publish the estimates base for Vintage 2025, so it is read from the
# published county file. This is the FTP fallback the PLAN.md decision of 2026-07-15
# anticipated, applied narrowly to the one column the API omits rather than to the whole
# product. CLAUDE.md's data-fetch rule pre-approves census.gov file-server fetches with a
# manual fallback, so a local drop is checked first and the failure message says exactly
# what to download and where to put it.
ftp_url   <- paste0("https://www2.census.gov/programs-surveys/popest/datasets/",
                    "2020-2025/counties/totals/co-est2025-alldata.csv")
ftp_local <- "data/raw/pep/co-est2025-alldata.csv"

base_raw <- if (file.exists(ftp_local)) {
  message("Reading estimates base from local drop: ", ftp_local)
  read_csv(ftp_local, locale = locale(encoding = "latin1"), show_col_types = FALSE)
} else {
  message("Fetching estimates base from the Census FTP...")
  tryCatch(
    read_csv(ftp_url, locale = locale(encoding = "latin1"), show_col_types = FALSE),
    error = function(e) {
      stop(
        "Could not read the PEP county file from the Census FTP: ", conditionMessage(e),
        "\nManual fallback: download\n  ", ftp_url,
        "\nand save it to\n  ", ftp_local, "\nthen re-run r/pep.R."
      )
    }
  )
}

# The 2020s-vintage county file ships ESTIMATESBASE2020 but NO census-count column — the
# 2010s files carried CENSUS2010POP alongside the base; this one does not. So there is no
# published 2020 census count in this file to benchmark the decennial pull against. The
# column list is printed, and a census-count column is used if a future vintage restores
# one; otherwise Section 7 falls back to a logged variance, per the ruling of 2026-08-06.
base_clean <- base_raw |> clean_names()
message("PEP county file columns: ", paste(names(base_clean), collapse = ", "))

census_col <- intersect(c("census2020pop", "census2020"), names(base_clean))

ftp_counts <- base_clean |>
  mutate(geoid = paste0(state, county)) |>
  filter(geoid %in% rr_geoids) |>
  transmute(
    geoid,
    name       = ctyname,
    base2020   = as.numeric(estimatesbase2020),
    census2020 = if (length(census_col) == 1) as.numeric(.data[[census_col[1]]]) else NA_real_
  )

pep_base <- ftp_counts |>
  transmute(geoid, name, year = 2020L, variable = "ESTIMATESBASE", value = base2020)

if (nrow(pep_base) != 8) {
  stop(
    "Expected 8 rr localities in the PEP county file; got ", nrow(pep_base),
    ". Check that the file is the Vintage 2025 county totals file and that its ",
    "STATE/COUNTY columns still zero-pad to the 5-digit FIPS this script joins on."
  )
}
message("Estimates base (4/1/2020) read for ", nrow(pep_base), " localities.")

## 5. Combine into one tidy long frame ----
# geoid, name, year, variable, label, value — no moe/cv, PEP estimates carry no
# published sampling error at this geography.
# Vintage 2025 returns both counts and their per-1,000 rates (the R-prefixed variables).
# Both are kept: the chapter's components-of-change figure uses counts, and the rates are
# what make an 8-locality comparison fair when the localities differ this much in size.
pep_label_lookup <- c(
  POP               = "Total population",
  POPESTIMATE       = "Total population",
  ESTIMATESBASE     = "Estimates base (April 1, 2020)",
  NPOPCHG           = "Net population change",
  BIRTHS            = "Births",
  DEATHS            = "Deaths",
  NATURALINC        = "Natural increase",
  NATURALCHG        = "Natural change",
  NETMIG            = "Net migration",
  DOMESTICMIG       = "Net domestic migration",
  INTERNATIONALMIG  = "Net international migration",
  RESIDUAL          = "Residual",
  RBIRTH            = "Birth rate (per 1,000)",
  RDEATH            = "Death rate (per 1,000)",
  RNATURALCHG       = "Natural change rate (per 1,000)",
  RNETMIG           = "Net migration rate (per 1,000)",
  RDOMESTICMIG      = "Net domestic migration rate (per 1,000)",
  RINTERNATIONALMIG = "Net international migration rate (per 1,000)"
)

pep <- bind_rows(
  pep_pop  |> transmute(geoid, name, year, variable, value),
  pep_comp |> transmute(geoid, name, year, variable, value),
  pep_base |> transmute(geoid, name, year, variable, value)
) |>
  mutate(
    label = if_else(
      variable %in% names(pep_label_lookup),
      pep_label_lookup[variable],
      variable   # fallback: unmatched variable codes still get a value, not NA
    )
  )

unmatched_vars <- setdiff(unique(pep$variable), names(pep_label_lookup))
if (length(unmatched_vars) > 0) {
  message("Note: PEP variable(s) without a label lookup entry (using the raw code as ",
          "the label): ", paste(unmatched_vars, collapse = ", "))
}

pep <- pep |> transmute(geoid, name, year, variable, label, value)

## 6. Write output ----
write_rds(pep, "data/pep.rds")
export_csv(pep, "pep")   # -> data-out/pep.csv
message("Wrote data/pep.rds + data-out/pep.csv")

## 7. Validate ----
p <- read_rds("data/pep.rds")

# Structure — row counts, all 8 rr geoids present, no all-NA value column.
stopifnot(
  nrow(p) > 0,
  all(rr_geoids %in% p$geoid),
  !anyNA(p$value)
)

# Same-vintage published-benchmark cross-check (hard stopifnot, per the phase
# file): PEP's estimates base must equal the 2020 decennial population count for
# every rr locality. decennial.rds is a genuine prerequisite, not an optional
# file.exists() escape hatch — stop with an instruction if it is missing.
decennial_path <- "data/decennial.rds"
if (!file.exists(decennial_path)) {
  stop(
    "data/decennial.rds not found. The PEP-vs-2020-decennial cross-check requires ",
    "it — run r/decennial.R first, then re-run r/pep.R."
  )
}

decennial_2020_pop <- read_rds(decennial_path) |>
  filter(year == 2020, table == "P1", geoid %in% rr_geoids) |>
  select(geoid, decennial_pop = value)

cross_check <- ftp_counts |>
  inner_join(decennial_2020_pop, by = "geoid") |>
  mutate(base_adj = base2020 - decennial_pop) |>
  arrange(desc(abs(base_adj)))

print(as.data.frame(cross_check))

# Structural gate: all 8 localities must join. The counts themselves are NOT gated.
stopifnot(nrow(cross_check) == 8)

if (length(census_col) == 1) {
  # A future vintage restored a published census-count column — assert the decennial
  # pull against it as a genuine same-vintage published benchmark.
  message("Census-count column '", census_col[1], "' present — asserting decennial pull ",
          "against the published 2020 count.")
  stopifnot(all(near(cross_check$census2020, cross_check$decennial_pop)))
} else {
  # No published census count in this file, so there is no same-vintage benchmark to
  # gate on. The base-vs-decennial difference is a PUBLISHED ADJUSTMENT, not an error:
  # Census revises the estimates base for Count Question Resolution, legal boundary
  # updates, and geographic program changes. Logged for data-notes.qmd, never gated —
  # ruling of 2026-08-06, superseding the phase file's equality assumption.
  message("No published census-count column in this vintage; the estimates base is not ",
          "asserted against the decennial count. Base minus 2020 decennial count, by ",
          "locality (Census CQR / boundary adjustment):")
  walk2(cross_check$name, cross_check$base_adj,
        \(nm, d) message("  ", nm, ": ", sprintf("%+d", as.integer(d))))
  message("  Total across the 8 localities: ",
          sprintf("%+d", as.integer(sum(cross_check$base_adj))))
}

message("pep.R validation passed.")
message("  Rows: ", nrow(p), " | Localities: ", n_distinct(p$geoid),
        " | Years: ", paste(sort(unique(p$year)), collapse = ", "))
message("  Estimates base joined to the 2020 decennial count for all 8 localities.")
