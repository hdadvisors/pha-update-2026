# acs_tenure_race.R ----
# What:   ACS 5-year homeownership by householder race and ethnicity -- owner,
#         renter, and total occupied households for each of the nine B25003
#         letter tables, converted to an ownership rate per group per geography.
#         Net-new scope this cycle.
# Source: tidycensus ACS 5-year, three non-overlapping windows ending 2014,
#         2019, and 2024 (overlapping 5-year samples are not independent).
# Tables: B25003A White alone, B25003B Black alone, B25003C American Indian and
#         Alaska Native alone, B25003D Asian alone, B25003E Native Hawaiian and
#         Other Pacific Islander alone, B25003F some other race alone,
#         B25003G two or more races, B25003H White alone not Hispanic or Latino,
#         B25003I Hispanic or Latino. A and H are different populations and both
#         are exported; G, H, and I overlap the A-F single-race universe, so the
#         nine categories never sum to the B25003 total.
# Groups: the nine published categories collapse to the six the report uses --
#         White non-Hispanic (H), Black (B), Hispanic or Latino (I), Asian (D),
#         Multiracial (G), and Another race (C + E + F). See section 5.
# Geos:   the 8 rr localities + Virginia, plus a pooled "region4" row covering
#         the 4 primary localities, which is the grain every regional aggregate
#         in this report uses. No Ashland -- its population suppresses nearly
#         every race category on CV-30 alone (phase-file decision).
# Output: data/acs_tenure_race.rds        (+ data-out/acs_tenure_race.csv)
#           row-level, all 9 published categories
#         data/acs_tenure_race_group.rds  (+ data-out/acs_tenure_race_group.csv)
#           the 6 report groups, what the chapters read

## 1. Setup ----
library(tidyverse)
library(tidycensus)
library(janitor)
source("_common.R")   # rr / virginia; flag_reliability(); export_csv()

# .Renviron fallback -- R's HOME may not be ~/Documents, so the key file isn't
# always auto-loaded (CLAUDE.md API-keys gotcha). Load it only if unset.
if (Sys.getenv("CENSUS_API_KEY") == "") {
  renviron_path <- file.path(Sys.getenv("USERPROFILE"), "Documents", ".Renviron")
  if (file.exists(renviron_path)) readRenviron(renviron_path)
}
message("CENSUS_API_KEY present: ", Sys.getenv("CENSUS_API_KEY") != "")

dir.create("data", showWarnings = FALSE, recursive = TRUE)

years <- c(2014, 2019, 2024)

# Published label for each letter suffix, used for the chapter axis and the
# data-notes crosswalk. The tenure dimension itself is resolved from
# load_variables() below, never assumed from B25003's own numbering.
race_labels <- c(
  A = "White alone",
  B = "Black or African American alone",
  C = "American Indian and Alaska Native alone",
  D = "Asian alone",
  E = "Native Hawaiian and Other Pacific Islander alone",
  F = "Some other race alone",
  G = "Two or more races",
  H = "White alone, not Hispanic or Latino",
  I = "Hispanic or Latino"
)

tables <- paste0("B25003", names(race_labels))

# Report groups. The nine published categories collapse to the six the report
# uses: A drops out in favor of H, and C, E, and F combine into "Another race"
# because each is too small to report on its own at any grain. The six overlap
# by construction -- only H excludes Hispanic or Latino householders, so a
# Hispanic Black household appears in both "Black" and "Hispanic or Latino".
# B25003 has no race-alone-not-Hispanic tables, so the overlap cannot be
# removed here; data-notes.qmd carries the caveat.
race_groups <- c(
  A = NA_character_,
  B = "Black",
  C = "Another race",
  D = "Asian",
  E = "Another race",
  F = "Another race",
  G = "Multiracial",
  H = "White, non-Hispanic",
  I = "Hispanic or Latino"
)

# Display order for the six groups, largest population first within the report.
group_levels <- c("White, non-Hispanic", "Black", "Hispanic or Latino",
                  "Asian", "Multiracial", "Another race")

## 2. Resolve the tenure dimension from load_variables() ----
# r/decennial.R needed this same fix for its tenure codes: the letter-suffix
# tables are not guaranteed to share B25003's exact variable numbering, so the
# owner/renter/total assignment comes from the published label, not from the
# variable number. Labels are "Estimate!!Total:" / "...!!Owner occupied" /
# "...!!Renter occupied"; the trailing element after the last "!!" identifies it.
tenure_lookup <- function(yr) {
  load_variables(year = yr, dataset = "acs5", cache = TRUE) |>
    clean_names() |>
    filter(str_detect(name, "^B25003[A-I]_")) |>
    mutate(
      leaf = label |>
        str_remove("^Estimate!!") |>
        str_split("!!") |>
        map_chr(last) |>
        str_remove(":$"),
      tenure = recode_values(
        leaf,
        "Total"          ~ "Total",
        "Owner occupied" ~ "Owner",
        "Renter occupied" ~ "Renter",
        default = NA
      ),
      table = str_extract(name, "^B25003[A-I]"),
      year  = yr
    ) |>
    filter(!is.na(tenure)) |>
    select(variable = name, table, tenure, year)
}

message("Resolving B25003A-I variable labels from load_variables()...")
tenure_map <- map(years, tenure_lookup) |> list_rbind()
message("Resolved ", nrow(tenure_map), " table-variable-tenure pairs across ",
        length(years), " years")

## 3. Pull B25003A-I ----
# Same helper shape as r/acs_tenure_value.R: the 8 rr counties plus the
# Virginia state row, for each trend year. A zero or absent MOE on a positive
# estimate means a controlled estimate with no sampling error (CV 0 -> High);
# only an absent or zero estimate leaves the CV genuinely undefined.
pull_acs_trend <- function(table) {
  map(years, \(yr) {
    county <- get_acs(geography = "county", state = "VA", table = table,
                      year = yr, survey = "acs5", cache_table = TRUE) |>
      clean_names() |>
      filter(geoid %in% rr)

    state <- get_acs(geography = "state", state = "VA", table = table,
                     year = yr, survey = "acs5", cache_table = TRUE) |>
      clean_names() |>
      filter(geoid %in% virginia)

    bind_rows(county, state) |>
      mutate(year = yr)
  }) |>
    list_rbind() |>
    mutate(table = table)
}

message("Pulling B25003A-I (", paste(years, collapse = ", "), ")...")
race_raw <- map(tables, pull_acs_trend) |> list_rbind()
message("B25003A-I pulled: ", nrow(race_raw), " rows")

## 4. Label, tier reliability, and compute the ownership rate ----
# Join on the equal-named keys only, then confirm no row lost its tenure label:
# join_by(a == b) on differently-named columns silently drops one side
# (CLAUDE.md known gotcha), so both frames use `variable`, `table`, `year`.
acs_tenure_race <- race_raw |>
  left_join(tenure_map, by = join_by(variable, table, year)) |>
  filter(!is.na(tenure)) |>
  mutate(
    # Letter suffix -> published label and report group, straight off the
    # race_labels and race_groups lookups.
    race       = unname(race_labels[str_sub(table, -1L)]),
    race_group = unname(race_groups[str_sub(table, -1L)]),
    cv = case_when(
      is.na(estimate) | estimate <= 0 ~ NA_real_,
      is.na(moe) | moe == 0           ~ 0,
      .default = (moe / 1.645) / estimate * 100
    )
  ) |>
  flag_reliability() |>
  # Owner rate is owner-occupied over the same race group's total occupied
  # households in that geography-year. It is carried on every row of the group
  # so a figure can filter to tenure == "Owner" and read rate directly.
  mutate(
    total_hh   = estimate[tenure == "Total"],
    owner_rate = estimate[tenure == "Owner"] / estimate[tenure == "Total"],
    .by = c(geoid, table, year)
  ) |>
  select(geoid, name, year, table, race, race_group, variable, tenure,
         estimate, moe, cv, reliability, total_hh, owner_rate)

## 5. Collapse to the six report groups ----
# Counts add; MOEs of a sum combine in quadrature. Both operations run here
# rather than in the chapter, so the standard-error math lives in one place and
# the chapter only filters and plots (CLAUDE.md data-flow rule).
#
# Geography rows: each of the 8 rr localities, Virginia, and one pooled
# "region" row covering the 4 primary localities. The 2022 Framework and this
# cycle's regional aggregates are both the primary 4, so no 8-locality pooled
# row is written -- an 8-locality regional figure would not match the rest of
# the report's regional statistics.
collapse_groups <- function(df, geos, out_geoid, out_name) {
  df |>
    filter(geoid %in% geos, !is.na(race_group)) |>
    summarise(
      estimate = sum(estimate),
      moe      = sqrt(sum(moe^2)),
      .by = c(race_group, tenure, year)
    ) |>
    mutate(geoid = out_geoid, name = out_name)
}

# One entry per output geography: the pooled region plus every single locality
# and Virginia, each pulling its own member GEOIDs.
geo_units <- c(
  list(list(geos = unname(pha), id = "region4",
            nm = "Richmond region (4 primary localities)")),
  imap(c(unname(rr), virginia), \(g, i) {
    nm <- acs_tenure_race |> filter(geoid == g) |> slice_head(n = 1) |> pull(name)
    list(geos = g, id = g, nm = nm)
  })
)

acs_tenure_race_group <- geo_units |>
  map(\(u) collapse_groups(acs_tenure_race, u$geos, u$id, u$nm)) |>
  list_rbind() |>
  mutate(
    race_group = factor(race_group, levels = group_levels),
    cv = case_when(
      is.na(estimate) | estimate <= 0 ~ NA_real_,
      is.na(moe) | moe == 0           ~ 0,
      .default = (moe / 1.645) / estimate * 100
    )
  ) |>
  flag_reliability() |>
  # `reliability` tiers one cell; the owner *rate* rests on the owner and the
  # renter cell together, so carry the worse of the two as rate_reliability.
  # A figure plotting rates filters on that column, not on the cell tier --
  # Hanover's Asian owner count is High while its renter count is Low.
  mutate(
    total_hh   = estimate[tenure == "Total"],
    owner_rate = estimate[tenure == "Owner"] / estimate[tenure == "Total"],
    rate_reliability = {
      tiers <- reliability[tenure != "Total"]
      case_when(
        any(is.na(tiers) | tiers == "Low") ~ "Low",
        any(tiers == "Medium")             ~ "Medium",
        .default = "High"
      )
    },
    .by = c(geoid, race_group, year)
  ) |>
  select(geoid, name, year, race_group, tenure, estimate, moe, cv,
         reliability, rate_reliability, total_hh, owner_rate) |>
  arrange(geoid, year, race_group, tenure)

## 6. Write output ----
write_rds(acs_tenure_race, "data/acs_tenure_race.rds")
export_csv(acs_tenure_race, "acs_tenure_race")
message("Wrote data/acs_tenure_race.rds + data-out/acs_tenure_race.csv (",
        nrow(acs_tenure_race), " rows)")

write_rds(acs_tenure_race_group, "data/acs_tenure_race_group.rds")
export_csv(acs_tenure_race_group, "acs_tenure_race_group")
message("Wrote data/acs_tenure_race_group.rds + data-out/acs_tenure_race_group.csv (",
        nrow(acs_tenure_race_group), " rows)")

## 7. Validate ----
d <- read_rds("data/acs_tenure_race.rds")
g <- read_rds("data/acs_tenure_race_group.rds")

geos <- c(unname(rr), virginia)

# Structure only: all 9 geographies x 9 race tables x 3 years x 3 tenure rows,
# no all-NA estimate column, every row labeled, and owner + renter ~ total
# within each geography-table-year (exact in B25003, 1-household slack allowed).
cell_check <- d |>
  pivot_wider(id_cols = c(geoid, table, year), names_from = tenure,
              values_from = estimate) |>
  mutate(gap = abs(Owner + Renter - Total))

stopifnot(
  nrow(d) > 0,
  all(geos %in% d$geoid),
  setequal(unique(d$year), years),
  setequal(unique(d$table), tables),
  setequal(unique(d$race), unname(race_labels)),
  !anyNA(d$race),
  !anyNA(d$tenure),
  !all(is.na(d$estimate)),
  nrow(distinct(d, geoid, table, year)) == length(geos) * length(tables) * length(years),
  nrow(d) == length(geos) * length(tables) * length(years) * 3,
  all(cell_check$gap <= 1, na.rm = TRUE)
)

# The grouped frame: 8 localities + Virginia + the pooled region row, all six
# groups, all three years, three tenure rows each, and owner + renter = total
# after the quadrature collapse.
group_check <- g |>
  pivot_wider(id_cols = c(geoid, race_group, year), names_from = tenure,
              values_from = estimate) |>
  mutate(gap = abs(Owner + Renter - Total))

stopifnot(
  all(c(geos, "region4") %in% g$geoid),
  setequal(unique(as.character(g$race_group)), group_levels),
  setequal(unique(g$year), years),
  !anyNA(g$estimate),
  !anyNA(g$rate_reliability),
  nrow(g) == (length(geos) + 1) * length(group_levels) * length(years) * 3,
  all(group_check$gap <= 1, na.rm = TRUE)
)

# Same-vintage published benchmarks, both against the independently pulled
# B25003 total in data/acs_tenure.rds.
if (file.exists("data/acs_tenure.rds")) {
  overall <- read_rds("data/acs_tenure.rds") |>
    filter(tenure == "Total", year %in% years) |>
    select(geoid, year, total_all = estimate)

  # 1. A-G partition the household universe by race, so they sum to the B25003
  #    total within rounding of the separately published table.
  bench <- d |>
    filter(tenure == "Total",
           table %in% paste0("B25003", c("A", "B", "C", "D", "E", "F", "G"))) |>
    summarise(single_race_sum = sum(estimate), .by = c(geoid, year)) |>
    left_join(overall, by = join_by(geoid, year)) |>
    mutate(gap = single_race_sum - total_all)

  message("A-G sum vs B25003 total, max absolute gap: ",
          max(abs(bench$gap), na.rm = TRUE), " households")
  stopifnot(all(abs(bench$gap) <= pmax(50, 0.005 * bench$total_all), na.rm = TRUE))

  # 2. The pooled region row must equal the sum of the same group across the 4
  #    primary localities -- catches a wrong geography set in collapse_groups().
  #    Checked group by group rather than against the B25003 total, because the
  #    six groups do not partition the universe: only "White, non-Hispanic"
  #    excludes Hispanic householders, so the five race groups fall short of the
  #    total by the number of White-alone Hispanic households.
  pooled_check <- g |>
    filter(geoid == "region4", tenure == "Total") |>
    select(race_group, year, pooled = estimate) |>
    left_join(
      g |>
        filter(geoid %in% pha, tenure == "Total") |>
        summarise(from_localities = sum(estimate), .by = c(race_group, year)),
      by = join_by(race_group, year)
    ) |>
    mutate(gap = abs(pooled - from_localities))

  message("Pooled region row vs summed primary-4 localities, max gap: ",
          max(pooled_check$gap), " households")
  stopifnot(all(pooled_check$gap == 0))
}

## 8. Reliability and headline figures for the session log ----
# Everything below reads the grouped frame. The pooled region row is the 4
# primary localities, matching the rest of the report's regional aggregates.
region_2024 <- g |> filter(geoid == "region4", year == 2024)

message("\n-- Region (4 primary localities), 2024, owner and renter cells --")
region_2024 |>
  filter(tenure != "Total") |>
  arrange(race_group, tenure) |>
  mutate(out = paste0(race_group, " | ", tenure, ": ", scales::comma(estimate),
                      " (CV ", round(cv, 1), ", ", reliability, ")")) |>
  pull(out) |>
  walk(message)

message("\n-- Region (4 primary localities), 2024 owner rate by group --")
region_2024 |>
  filter(tenure == "Owner") |>
  arrange(desc(owner_rate)) |>
  mutate(out = paste0(race_group, ": ",
                      scales::percent(owner_rate, accuracy = 0.1),
                      " of ", scales::comma(total_hh), " households")) |>
  pull(out) |>
  walk(message)

# The figure decision: how many of the six groups clear CV-30 at each grain.
pooled_clear <- region_2024 |>
  filter(tenure == "Owner", rate_reliability != "Low")

# A locality counts as clearing only if both its owner and renter cells do --
# the owner rate needs both to be reportable.
locality_clear <- g |>
  filter(geoid %in% pha, year == 2024, tenure == "Owner") |>
  mutate(clears = rate_reliability != "Low") |>
  summarise(n_localities = sum(clears), clears_all = all(clears), .by = race_group)

message("\n-- Groups clearing CV-30 at the pooled region grain: ",
        nrow(pooled_clear), " of ", length(group_levels), " --")
message(paste(pooled_clear$race_group, collapse = "; "))

message("\n-- Primary-locality CV-30 coverage, 2024 (owner+renter cells) --")
locality_clear |>
  arrange(desc(n_localities)) |>
  mutate(out = paste0(race_group, ": ", n_localities, " of 4 localities clear",
                      if_else(clears_all, " (all)", ""))) |>
  pull(out) |>
  walk(message)

message("\n-- Groups clearing CV-30 in ALL 4 primary localities: ",
        sum(locality_clear$clears_all), " of ", length(group_levels), " --")

# Owner-rate trend on the pooled region row, for the log entry only.
message("\n-- Region (4 primary localities) owner rate by group, 2014 / 2019 / 2024 --")
g |>
  filter(geoid == "region4", tenure == "Owner") |>
  select(race_group, year, owner_rate) |>
  pivot_wider(names_from = year, values_from = owner_rate) |>
  arrange(desc(`2024`)) |>
  mutate(out = paste0(race_group, ": ",
                      scales::percent(`2014`, accuracy = 0.1), " / ",
                      scales::percent(`2019`, accuracy = 0.1), " / ",
                      scales::percent(`2024`, accuracy = 0.1))) |>
  pull(out) |>
  walk(message)

# 2022 baseline: none computable. The 2022 Framework's only race figure is
# qualitative ("white households above 70 percent," no exact value), so there is
# no percentage change to log here (phase-file decision, 2026-08-20).
message("\nNo 2022 baseline comparison: racial homeownership is net-new this cycle.")

message("\nacs_tenure_race.R validation passed.")
