# decennial.R ----
# What:   Decennial Census population, housing units, and tenure for 2000, 2010,
#         and 2020, for the 8 `rr` localities and the Ashland place (sumlev 160).
# Source: tidycensus::get_decennial() — 2000 SF1, 2010 SF1, 2020 PL (pop/units) +
#         2020 DHC (tenure). The three vintages come from different summary files;
#         variable codes do NOT carry across years, hence the explicit per-year map
#         in Section 2 rather than one reused code vector.
# Output: data/decennial.rds  (+ data-out/decennial.csv)
#
# NOTE ON VARIABLE CODES: the population and housing-unit codes in Section 2 are the
# long-standing published codes for those files. Tenure is NOT hardcoded — Section 2b
# resolves it per vintage from load_variables(), because the owner side of every tenure
# table splits into "Owned with a mortgage or a loan" and "Owned free and clear", which
# makes a plausible-looking hardcoded offset produce a silently wrong number rather than
# an error. If a get_decennial() call below fails on an unrecognized variable, look the
# code up with tidycensus::load_variables(year, sumfile) — never guess a replacement.

## 1. Setup ----
library(tidyverse)
library(tidycensus)
library(janitor)
source("_common.R")   # rr, ashland geography constants; export_csv()

# .Renviron fallback — R's HOME may not be ~/Documents, so the key file isn't
# always auto-loaded (CLAUDE.md API-keys gotcha). Load it only if the key is unset.
if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- file.path(Sys.getenv("USERPROFILE"), "Documents", ".Renviron")
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}
message("CENSUS_API_KEY visible: ", Sys.getenv("CENSUS_API_KEY") != "")

dir.create("data", showWarnings = FALSE, recursive = TRUE)

## 2. Explicit year-to-variable map ----
# One row per (year, sumfile, variable). UNVERIFIED against a live pull — see the
# header note. `table` is the published table ID; `concept` keys the tidy reshape
# in Section 4; `label` is the human-readable value used in the output frame.
#
# 2000 & 2010 SF1: P001 = total population; H001 = total housing units;
#   H004 = tenure (001 total occupied, 002 owner-occupied, 003 renter-occupied).
# 2020 PL: P1 = total population (P1_001N); H1 = total housing units (H1_001N).
# 2020 DHC tenure is resolved in Section 2b, not hardcoded here — the DHC renumbered
# tenure away from SF1's H004 and this script does not assume what it renumbered to.
decennial_vars <- tribble(
  ~year, ~sumfile, ~variable,   ~table, ~concept,        ~label,
  2000L, "sf1",    "P001001",   "P001", "population",    "Total population",
  2000L, "sf1",    "H001001",   "H001", "units",         "Total housing units",
  2010L, "sf1",    "P001001",   "P001", "population",    "Total population",
  2010L, "sf1",    "H001001",   "H001", "units",         "Total housing units",
  2020L, "pl",     "P1_001N",   "P1",   "population",    "Total population",
  2020L, "pl",     "H1_001N",   "H1",   "units",         "Total housing units"
)

## 2b. Resolve the tenure table for each vintage from its published variable list ----
# Tenure is NOT hardcoded, for a specific reason. In all three summary files the owner
# side of the tenure table is split into "Owned with a mortgage or a loan" and "Owned
# free and clear", so the table's second variable is NOT owner-occupied — it is
# mortgage-holders alone. Those are valid codes, so a hardcoded H004002/H004003 pair
# would have run clean and written silently wrong numbers. Every tenure variable is
# therefore resolved from load_variables() and classified by its own label.
#
# The frame keeps the published rows verbatim rather than pre-summing the two owner
# categories: it stays a faithful transcription of published counts, and the labels say
# exactly what each row is. A chapter wanting an owner-occupied total sums the two
# "Owned ..." rows — filtering on one of them alone is the trap this section exists to
# make visible.
resolve_tenure <- function(yr, sf) {
  message("Resolving ", yr, " tenure variables from load_variables(", yr, ", \"", sf, "\")...")

  tv <- load_variables(yr, sf) |>
    clean_names() |>
    # 2000 SF1 suffixes its concepts with a bracketed variable count ("TENURE [3]");
    # 2010 SF1 and 2020 DHC do not. Strip it, then match the concept exactly. An exact
    # match is what separates the base table from every near-miss in one rule: the
    # cross-tabs ("TENURE BY AGE OF HOUSEHOLDER"), the race iterations ("TENURE (WHITE
    # ALONE HOUSEHOLDER)"), and the two that trip a keyword search — 2000's H020
    # "IMPUTATION OF TENURE" and 2010's H022 "ALLOCATION OF TENURE".
    mutate(concept = str_squish(str_remove(concept, "\\s*\\[\\d+\\]\\s*$"))) |>
    filter(str_detect(concept, regex("^tenure$", ignore_case = TRUE))) |>
    # SF1 names have no underscore (H004002 -> H004); PL/DHC names do (H4_004N -> H4).
    mutate(table = if_else(str_detect(name, "_"),
                           str_extract(name, "^[^_]+"), str_sub(name, 1, 4)))

  tables <- unique(tv$table)
  if (length(tables) != 1) {
    stop(
      "Expected exactly one base tenure table for ", yr, " ", sf, "; found ",
      length(tables), ": ", paste(tables, collapse = ", "),
      ". Inspect load_variables(", yr, ", \"", sf, "\") and tighten the concept filter ",
      "in Section 2b — do not hardcode a table number."
    )
  }

  out <- tv |>
    transmute(
      year     = as.integer(yr),
      sumfile  = sf,
      variable = name,
      table,
      # "owned|owner" both: 2000 says "Owner occupied", 2010 and 2020 say "Owned with a
      # mortgage or a loan" / "Owned free and clear". Matching only "owned" would drop
      # 2000's owner row into the total bucket.
      concept = case_when(
        str_detect(label, regex("owned|owner", ignore_case = TRUE)) ~ "tenure_owner",
        str_detect(label, regex("renter",      ignore_case = TRUE)) ~ "tenure_renter",
        .default = "tenure_total"
      ),
      # Keep the published wording, taking the deepest "!!" segment as the label.
      # 2020 DHC labels carry a trailing colon on the total row ("!!Total:"); drop it so
      # the three vintages read the same.
      label = str_squish(str_remove(str_remove(label, "^.*!!"), ":$"))
    )

  n_owner  <- sum(out$concept == "tenure_owner")
  n_renter <- sum(out$concept == "tenure_renter")
  if (n_owner < 1 || n_renter != 1) {
    stop(
      "Tenure table ", tables, " for ", yr, " ", sf, " resolved to ", n_owner,
      " owner row(s) and ", n_renter, " renter row(s); expected at least one owner and ",
      "exactly one renter. Variables matched: ", paste(out$variable, collapse = ", "), "."
    )
  }

  message("  ", yr, " tenure resolved: table ", tables, " — ",
          paste(out$variable, " (", out$concept, ")", sep = "", collapse = ", "))
  out
}

decennial_vars <- bind_rows(
  decennial_vars,
  resolve_tenure(2000, "sf1"),
  resolve_tenure(2010, "sf1"),
  resolve_tenure(2020, "dhc")
)

## 3. Pull helper ----
# One (year, sumfile) combination per call, across county (rr) and place (ashland)
# geography levels, imap() + list_rbind() per the purrr 1.2.2 house idiom.
pull_decennial <- function(yr, sf, vars) {
  geos <- list(county = unname(rr), place = unname(ashland))
  geos |>
    imap(\(ids, level) {
      d <- tryCatch(
        get_decennial(geography = level, variables = vars, year = yr,
                      sumfile = sf, state = "VA", cache_table = TRUE),
        error = function(e) {
          stop(
            "get_decennial() failed for year ", yr, ", sumfile '", sf, "', variables ",
            paste(vars, collapse = ", "), ": ", conditionMessage(e), "\n",
            "This is likely a wrong variable code in decennial_vars (Section 2) — ",
            "confirm with load_variables(", yr, ", \"", sf, "\", cache = TRUE) rather ",
            "than guessing a replacement."
          )
        }
      ) |>
        clean_names() |>
        mutate(geo_type = level)
      filter(d, geoid %in% ids)
    }) |>
    list_rbind()
}

## 4. Pull each year ----
message("Pulling 2000 decennial (SF1)...")
vars_2000 <- decennial_vars |> filter(year == 2000)
d_2000 <- pull_decennial(2000, "sf1", vars_2000$variable) |>
  left_join(vars_2000, by = "variable") |>
  mutate(year = 2000L)
message("2000 pulled: ", nrow(d_2000), " rows")

message("Pulling 2010 decennial (SF1)...")
vars_2010 <- decennial_vars |> filter(year == 2010)
d_2010 <- pull_decennial(2010, "sf1", vars_2010$variable) |>
  left_join(vars_2010, by = "variable") |>
  mutate(year = 2010L)
message("2010 pulled: ", nrow(d_2010), " rows")

message("Pulling 2020 decennial (PL: population, units)...")
vars_2020_pl <- decennial_vars |> filter(year == 2020, sumfile == "pl")
d_2020_pl <- pull_decennial(2020, "pl", vars_2020_pl$variable) |>
  left_join(vars_2020_pl, by = "variable") |>
  mutate(year = 2020L)
message("2020 PL pulled: ", nrow(d_2020_pl), " rows")

message("Pulling 2020 decennial (DHC: tenure)...")
vars_2020_dhc <- decennial_vars |> filter(year == 2020, sumfile == "dhc")
d_2020_dhc <- pull_decennial(2020, "dhc", vars_2020_dhc$variable) |>
  left_join(vars_2020_dhc, by = "variable") |>
  mutate(year = 2020L)
message("2020 DHC pulled: ", nrow(d_2020_dhc), " rows")

## 5. Combine into one tidy long frame ----
# geoid, name, year, table, variable, label, value — no moe/cv column, since
# decennial 100% counts carry no sampling error.
decennial <- bind_rows(d_2000, d_2010, d_2020_pl, d_2020_dhc) |>
  transmute(geoid, name, year, table, variable, label, value)

## 6. Write output ----
write_rds(decennial, "data/decennial.rds")
export_csv(decennial, "decennial")   # -> data-out/decennial.csv
message("Wrote data/decennial.rds + data-out/decennial.csv")

## 7. Validate ----
dec <- read_rds("data/decennial.rds")

expected_geoids <- unname(c(rr, ashland))

# Structure only — row counts, all expected geographies present for all 3 years,
# no all-NA value column. No baseline_2022 comparison in this stopifnot(): that
# delta is logged in the session log, never a hard gate.
stopifnot(
  nrow(dec) > 0,
  all(2000L %in% dec$year, 2010L %in% dec$year, 2020L %in% dec$year),
  all(expected_geoids %in% dec$geoid),
  !anyNA(dec$value)
)

# Every (geoid, year) combination should have all 3 years present.
by_geo_year <- dec |> distinct(geoid, year)
n_years_per_geo <- by_geo_year |> count(geoid)
stopifnot(all(n_years_per_geo$n == 3))

message("decennial.R validation passed.")
message("  Rows: ", nrow(dec), " | Geographies: ", n_distinct(dec$geoid),
        " | Years: ", paste(sort(unique(dec$year)), collapse = ", "))
