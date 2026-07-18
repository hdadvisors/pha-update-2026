# baseline.R ----
# What:   Transcribed 2022 headline figures from the 2022 Richmond Regional Housing
#         Framework (rrh-framework) predecessor report, keyed by metric x geography.
#         Feeds each chapter's "Since 2022" callout (PLAN.md S6) and the Task 12 local
#         summaries. This is a DATA DROP, not a computation: every value below was read
#         by hand off the rendered site and typed in as an R literal -- never recomputed,
#         never re-fetched (decision 4, PLAN.md S1). If a number looks odd, it is
#         transcribed faithfully from the source page; see the `note` column and the
#         Task 2 Session 2B S11 log entry for flagged inconsistencies.
# Source: <hda>\rrh-framework\docs\ (rendered HTML, confirmed reachable at
#         R:\hda\rrh-framework\docs\ this session) --
#           part-1-1..4 = S1 Housing demand
#           part-2-1    = S2 Homeownership market
#           part-2-2..4 = S3 Rental market (incl. housing assistance, NOAH)
#           part-3-1    = S4 Housing gap
#           part-3-2    = S5 Cost burden & instability
#           part-4-1..9 = 9 local summaries (Richmond, Chesterfield, Henrico, Hanover,
#                         Ashland, Charles City, Goochland, New Kent, Powhatan)
# Output: data/baseline_2022.rds (+ data-out/baseline_2022.csv)
#
# IMPORTANT geography note: the 2022 rrh report defines "the region" as the 4 primary
# localities only (Chesterfield, Hanover, Henrico, Richmond city) -- it predates this
# update's 8-locality + Ashland PlanRVA study area (PLAN.md S1/S4). Region-wide rows below
# use geography = "region" and mean rrh's 4-locality scope, NOT the 8-locality `rr` set.
# This distinction belongs in data-notes.qmd's vintage-comparison caveats (Task 14).

## 1. Setup ----
library(tidyverse)
source("_common.R")

dir.create("data", showWarnings = FALSE, recursive = TRUE)

# No API keys / .Renviron fallback needed -- this script makes no external calls.

## 2. Demand (part-1-1..4) ----

demand_rows <- tribble(
  ~metric,                          ~geography, ~value,    ~unit,    ~source_page, ~source_fig,   ~note,
  "population_change_net",          "region",   41457,     "count",  "part-1-1",   "Fig 1.1",     "2016-2020 net residents added, rrh 4-locality region",
  "population_projection_2050",     "region",   1338306,   "count",  "part-1-3",   "Fig 1.3",     "2020-2050 regional projection (Weldon Cooper)",
  "population_projection_pct_chg",  "region",   29,        "percent","part-1-3",   "Fig 1.3",     "2020-2050 projected growth, rrh 4-locality region",
  "population_projection_pct_chg",  "chesterfield", 38,    "percent","part-1-3",   "Fig 1.4",     "2020-2050 projected growth; county expected to surpass 500,000",
  "population_projection_pct_chg",  "hanover",  27,        "percent","part-1-3",   "Fig 1.4",     "2020-2050 projected growth",
  "population_projection_pct_chg",  "henrico",  26,        "percent","part-1-3",   "Fig 1.4",     "2020-2050 projected growth (+88,565)",
  "population_projection_net_chg",  "henrico",  88565,     "count",  "part-1-3",   "Fig 1.4",     "2020-2050 projected net change",
  "population_projection_pct_chg",  "richmond", 20,        "percent","part-1-3",   "Fig 1.4",     "2020-2050 projected growth",
  "household_owner_change_net",     "region",   17436,     "count",  "part-1-2",   "Fig 2.1",     "2016-2020, new owner-occupied households",
  "household_renter_change_net",    "region",   -609,      "count",  "part-1-2",   "Fig 2.1",     "2016-2020 net loss (COVID-era ACS response-rate caveat noted in source)",
  "subfamilies_count",              "region",   9850,      "count",  "part-1-2",   "S2.7",        "as of 2020, 'approximately'; stable since 2016",
  "multigenerational_hh_share_start","region",  7,         "percent","part-1-2",   "Fig 2.8",     "2016, share of persons in multigenerational households",
  "multigenerational_hh_share_end", "region",   8,         "percent","part-1-2",   "Fig 2.8",     "2020, share of persons in multigenerational households",
  "adult_children_with_parents",    "region",   75800,     "count",  "part-1-2",   "S2.9",        "18-34 year olds living with parents, 'more than'; about one-in-three",
  "wage_transportation_2019",       "richmond_msa", 30250, "dollars","part-1-3",   "Fig 3.6",     "May 2019 avg annual wage, Transportation & Material Moving",
  "wage_transportation_2021",       "richmond_msa", 36370, "dollars","part-1-3",   "Fig 3.6",     "May 2021, >20 pct increase from 2019",
  "wage_avg_pct_chg_top5_common",   "richmond_msa", 13.3,  "percent","part-1-3",   "Fig 3.6",     "May 2019-2021 avg increase, most common occupations (excl. office/admin)",
  "wage_office_admin_pct_chg",      "richmond_msa", -0.2,  "percent","part-1-3",   "Fig 3.6",     "May 2019-2021, nearly flat",
  "ilw_difficulty_change",          "region",   2600,      "count",  "part-1-4",   "Fig 4.1",     "2016-2020 net change, 'almost'",
  "veterans_disability_change",     "region",   2800,      "count",  "part-1-4",   "S4.2",        "2016-2020 net change, 'more than'"
)

## 3. Ownership market (part-2-1) ----

ownership_rows <- tribble(
  ~metric,                            ~geography,              ~value,  ~unit,    ~source_page, ~source_fig, ~note,
  "owner_occupied_change_net",        "region",                17436,   "count",  "part-2-1",   "S5.1.1",    "2016-2020, +7 pct; 93 pct of growth in single-family",
  "owner_occupied_pct_chg",           "region",                7,       "percent","part-2-1",   "S5.1.1",    "2016-2020",
  "owner_occupied_sf_change_net",     "chesterfield",          7184,    "count",  "part-2-1",   "S5.1.1",    "2016-2020, net gain single-family owner-occupied homes",
  "sf_building_permits_annual",       "chesterfield",          545,     "count",  "part-2-1",   "Fig 5.4",   "2010 annual single-family permits",
  "sf_building_permits_annual",       "chesterfield",          2202,    "count",  "part-2-1",   "Fig 5.4",   "2020 annual single-family permits, 300 pct increase from 2010",
  "homeownership_rate_under35",       "region",                30,      "percent","part-2-1",   "Fig 5.6",   "2016, under-35 households",
  "homeownership_rate_under35",       "region",                35,      "percent","part-2-1",   "Fig 5.6",   "2020, under-35 households",
  "homeownership_rate_white_min",      "region",                70,     "percent","part-2-1",   "S5.2.3",    "white households, only group above 70 pct; exact rate not given, stated as 'above'",
  "home_sales_monthly_peak",          "chesterfield",          809,     "count",  "part-2-1",   "Fig 5.9",   "June 2021 monthly peak",
  "median_home_price_2022",           "hanover",               423250,  "dollars","part-2-1",   "Fig 5.10",  "September 2022, most expensive locality in region",
  "median_home_price_2022",           "chesterfield",          371273,  "dollars","part-2-1",   "Fig 5.10",  "September 2022",
  "median_home_price_2022",           "henrico",               349950,  "dollars","part-2-1",   "Fig 5.10",  "September 2022",
  "median_home_price_2022",           "richmond",              325500,  "dollars","part-2-1",   "Fig 5.10",  "September 2022",
  "median_home_price_2022_feb",       "richmond",              303941,  "dollars","part-2-1",   "S5.3.2",    "February 2022",
  "median_home_price_2022_jun",       "richmond",              389950,  "dollars","part-2-1",   "S5.3.2",    "June 2022, 28 pct increase from February 2022",
  "starter_home_share_sold",          "chesterfield",          63,      "percent","part-2-1",   "Fig 5.12",  "2013, VAR/HousingForward VA analysis (80 pct AMI afford.)",
  "starter_home_share_sold",          "chesterfield",          46,      "percent","part-2-1",   "Fig 5.12",  "mid-2021, greatest regional decrease",
  "starter_home_share_decline_pp",     "henrico",               8,      "percentage_points","part-2-1","Fig 5.12","2013-mid2021 decrease, smallest in region",
  "new_construction_resale_price_gap","region",                89127,   "dollars","part-2-1",   "Fig 5.13",  "avg difference, new construction vs resale sales price"
)

## 4. Rental market: supply/rents, assistance, NOAH (part-2-2..4) ----

rental_rows <- tribble(
  ~metric,                              ~geography,              ~value, ~unit,    ~source_page, ~source_fig,  ~note,
  "rental_share_single_family",         "region",                37,     "percent","part-2-2",   "Fig 6.1",    "2020, share of rental housing",
  "rental_share_5plus_units",           "region",                49,     "percent","part-2-2",   "Fig 6.1",    "2020, share of rental housing",
  "avg_asking_rent_regional_peak",      "region",                1395,   "dollars","part-2-2",   "Fig 6.5",    "Q1 2022, two-decade high",
  "avg_asking_rent_submarket",          "richmond_northside",    1037,   "dollars","part-2-2",   "Fig 6.7",    "Q2 2022, least expensive submarket in region",
  "avg_asking_rent_submarket",          "chesterfield_midlothian",1655,  "dollars","part-2-2",   "Fig 6.7",    "Q2 2022, most expensive submarket in region",
  "avg_asking_rent_new_construction",   "region",                1614,   "dollars","part-2-2",   "Fig 6.9",    "built 2010 or later",
  "rental_vacancy_rate",                "region",                5,      "percent","part-2-2",   "Fig 6.10",   "2022 regional avg to-date",
  "rental_vacancy_rate",                "hanover",               1,      "percent","part-2-2",   "Fig 6.10",   "2022, lowest submarket in region",
  "affordable_rental_units_total",      "region",                25969,  "count",  "part-2-3",   "S7.1",       "dedicated affordable rental homes, across 240 properties",
  "affordable_rental_properties_total", "region",                240,    "count",  "part-2-3",   "S7.1",       NA_character_,
  "lihtc_only_share",                   "region",                51,     "percent","part-2-3",   "S7.1.1",     "of all affordable rental homes",
  "layered_subsidy_share",              "region",                31,     "percent","part-2-3",   "S7.1.1",     "of all affordable rental homes, multiple subsidies layered",
  "public_housing_units",               "region",                3600,   "count",  "part-2-3",   "S7.1.1",     "RRHA-managed, 'more than'",
  "affordable_units_share",             "richmond",              60,     "percent","part-2-3",   "S7.1.3",     "share of regional affordable rentals, 'about'",
  "affordable_units_count",             "richmond",              15200,  "count",  "part-2-3",   "S7.1.3",     "'more than'",
  "subsidy_net_change_units_since2020", "region",                2760,   "count",  "part-2-3",   "Table 7.2",  "Jan 2020-Oct 2022 net addition",
  "subsidy_added_units_since2020",      "region",                4393,   "count",  "part-2-3",   "Table 7.2",  "57 new subsidies added",
  "subsidy_removed_units_since2020",    "region",                -1633,  "count",  "part-2-3",   "Table 7.2",  "17 subsidies ended",
  "lihtc_units_beyond_commitment_2040", "region",                13000,  "count",  "part-2-3",   "Fig 7.6",    "'just over', by 2040; over half of active LIHTC units",
  "noah_units_total",                   "region",                25000,  "count",  "part-2-4",   "S8.1.1",     "'nearly', across 194 properties",
  "noah_properties_total",              "region",                194,    "count",  "part-2-4",   "S8.1.1",     NA_character_,
  "noah_units_locality",                "richmond",              11253,  "count",  "part-2-4",   "S8.1.1",     "45 pct of all regional NOAH units; cf. lower per-property count on the Richmond local page (data surprise, S11)",
  "noah_units_locality",                "henrico",               8983,   "count",  "part-2-4",   "S8.1.1",     NA_character_,
  "noah_units_locality",                "chesterfield",          3667,   "count",  "part-2-4",   "S8.1.1",     NA_character_,
  "noah_avg_asking_rent",               "region",                1173,   "dollars","part-2-4",   "Fig 8.7",    "Q3 2022, ~$200 below all-rental avg",
  "noah_rent_change_since_pandemic",    "region",                104,    "dollars","part-2-4",   "Fig 8.7",    "pandemic start to Q3 2022, 10 pct increase",
  "noah_avg_price_per_unit_peak",       "region",                221534, "dollars","part-2-4",   "Fig 8.11",   "end of 2020, ~$44,000 above all multifamily sales avg",
  "mhc_units_msa_2016",                 "region",                4735,   "count",  "part-2-4",   "S8.2.1",     "2016 MHCCV assessment, 54 communities, greater Richmond MSA",
  "mhc_units_pha_area_2016",            "region",                2742,   "count",  "part-2-4",   "S8.2.1",     "within primary 4-locality PHA area, 24 communities, 'at least'",
  "mhc_units_locality",                 "chesterfield",          1543,   "count",  "part-2-4",   "S8.2.1",     "largest MHC supply in region"
)

## 5. Housing gap (part-3-1) ----

gaps_rows <- tribble(
  ~metric,                            ~geography,      ~value, ~unit,    ~source_page, ~source_fig, ~note,
  "rental_gap_80ami",                 "region",        38778,  "count",  "part-3-1",   "S9.1",      "2015 gap; NOTE source text states 2019 total is ALSO 38,778 despite a stated +1,220 increase -- internal inconsistency in the rrh source, transcribed verbatim (data surprise, S11)",
  "rental_gap_80ami",                 "region",        38778,  "count",  "part-3-1",   "S9.1",      "2019 gap as stated (+1,220 from 2015 per source text, though both totals given as 38,778 -- see 2015-row note)",
  "rental_gap_30ami",                 "region",        24000,  "count",  "part-3-1",   "S9.1",      "2018, extremely low-income (<=30 pct AMI) shortage, 'over'",
  "rental_affordability_gap_monthly", "henrico",       20,     "dollars","part-3-1",   "S9.2.2",    "2016-2020 avg, avg rent minus rent affordable to median renter income",
  "rental_affordability_gap_monthly", "richmond",      218,    "dollars","part-3-1",   "S9.2.2",    "2016-2020 avg",
  "wage_max_annual_top_occupation",   "richmond_msa",  75800,  "dollars","part-3-1",   "Fig 9.6",   "Business & Financial Operations, May 2021 (5 most common occupations)",
  "wage_min_annual_bottom_occupation","richmond_msa",  23650,  "dollars","part-3-1",   "Fig 9.6",   "Food Preparation & Serving Related, May 2021",
  "max_affordable_home_price_by_wage","richmond_msa",  140000, "dollars","part-3-1",   "Fig 9.8",   "most common occupations excl. Business & Financial Operations, 'below'"
)

## 6. Cost burden & instability (part-3-2) ----

burden_rows <- tribble(
  ~metric,                                  ~geography,           ~value, ~unit,    ~source_page, ~source_fig, ~note,
  "cost_burdened_owners_change",            "region",             -7200,  "count",  "part-3-2",   "Fig 10.1",  "since 2015, decline 'exceeded' this total",
  "cost_burdened_renters_change",           "region",             1900,   "count",  "part-3-2",   "Fig 10.1",  "since 2015, increase 'almost'",
  "cost_burdened_renters_50ami_change",     "region",             4000,   "count",  "part-3-2",   "Fig 10.2",  "<=50 pct AMI, since 2015, 'nearly'",
  "cost_burdened_small_family_owner_change","region",             -6525,  "count",  "part-3-2",   "S10.1.3",   "since 2015",
  "cost_burdened_small_family_renter_change","region",            -765,   "count",  "part-3-2",   "S10.1.3",   "since 2015",
  "cost_burdened_elderly_change",           "region",             4600,   "count",  "part-3-2",   "S10.1.3",   "net increase, elderly non-family + family HH, 'more than'",
  "mortgage_delinquency_rate_2021",         "hanover",            0.2,    "percent","part-3-2",   "Fig 10.6",  "December 2021, lowest in region",
  "eviction_filings_pct_chg",               "richmond",           -14,    "percent","part-3-2",   "S10.3",     "avg annual filings, 2017-2019",
  "eviction_judgements_pct_chg",            "richmond",           -8,     "percent","part-3-2",   "S10.3",     "avg annual judgements, 2017-2019",
  "housing_resource_line_calls_total",      "region",             17000,  "count",  "part-3-2",   "S10.4",     "as of Nov 2022, 'nearly', since Sept 2020 launch",
  "hrl_calls_share_rental",                 "region",             36,     "percent","part-3-2",   "Fig 10.10", "largest call topic share",
  "hrl_calls_share_financial_assistance",   "region",             21,     "percent","part-3-2",   "Fig 10.10", NA_character_,
  "hrl_calls_share_other",                  "region",             17,     "percent","part-3-2",   "Fig 10.10", NA_character_,
  "hrl_calls_share_homelessness",           "region",             12,     "percent","part-3-2",   "Fig 10.10", NA_character_,
  "pit_count",                              "greater_richmond_coc",497,   "count",  "part-3-2",   "Fig 10.11", "2019",
  "pit_count",                              "greater_richmond_coc",834,   "count",  "part-3-2",   "Fig 10.11", "2021, 68 pct increase from 2019 (COVID-era)",
  "student_homelessness_pct_chg",           "richmond",           -40,    "percent","part-3-2",   "Fig 10.12", "Richmond Public Schools, 2017-18 to 2019-20 school years"
)

## 7. Local summaries -- 2-3+ signature figures per locality (part-4-1..9) ----

local_rows <- tribble(
  ~metric,                              ~geography,     ~value,  ~unit,    ~source_page, ~source_fig, ~note,
  # Richmond city (part-4-1)
  "population_change_pct_2010_2020",   "richmond",     11,      "percent","part-4-1",   "Fig 11.1",  "2010-2020",
  "population_change_net_2010_2020",   "richmond",     22396,   "count",  "part-4-1",   "Fig 11.1",  "2010-2020",
  "median_household_income_owner",     "richmond",     79858,   "dollars","part-4-1",   "Fig 11.5",  "2020",
  "median_household_income_renter",    "richmond",     36249,   "dollars","part-4-1",   "Fig 11.5",  "2020; 16 pct increase 2016-2020",
  "rental_gap_80ami",                  "richmond",     17834,   "count",  "part-4-1",   "Fig 11.12", "2020 shortage (up 300 from 17,534 in 2015)",
  "noah_properties_locality",          "richmond",     128,     "count",  "part-4-1",   "S11.3.4",   "'more than 9,100' apartments, ~25 pct of city multifamily rental stock; cf. higher unit count on the regional NOAH page (data surprise, S11)",
  # Chesterfield County (part-4-2)
  "population_change_pct_2016_2020",   "chesterfield", 8,       "percent","part-4-2",   "Fig 12.1",  "2016-2020, 4th-most-populous VA locality as of 2020 Census",
  "population_change_net_2016_2020",   "chesterfield", 26000,   "count",  "part-4-2",   "Fig 12.1",  "'just over'",
  "rental_gap_80ami",                  "chesterfield", 7569,    "count",  "part-4-2",   "Fig 12.13", "2018 shortage (+204 from 2015)",
  "avg_asking_rent_2022q3",            "chesterfield", 1504,    "dollars","part-4-2",   "S12.3.2",   "Q3 2022",
  # Henrico County (part-4-3)
  "population_change_pct_2010_2020",   "henrico",      9,       "percent","part-4-3",   "Fig 13.1",  "2010-2020",
  "population_change_net_2010_2020",   "henrico",      27454,   "count",  "part-4-3",   "Fig 13.1",  "2010-2020",
  "median_household_income_owner",     "henrico",      93965,   "dollars","part-4-3",   "Fig 13.5",  "2020",
  "median_household_income_renter",    "henrico",      48081,   "dollars","part-4-3",   "Fig 13.5",  "2020",
  "rental_gap_80ami",                  "henrico",      12184,   "count",  "part-4-3",   "Fig 13.12", "2018 shortage (up from 12,030 in 2015)",
  "avg_asking_rent_submarket",         "henrico_west", 1327,    "dollars","part-4-3",   "S13.3.2",   "Q3 2022, Western Henrico",
  "avg_asking_rent_submarket",         "henrico_east", 1225,    "dollars","part-4-3",   "S13.3.2",   "Q3 2022, Eastern Henrico",
  # Hanover County (part-4-4)
  "population_change_pct_2010_2020",   "hanover",      10,      "percent","part-4-4",   "Fig 14.1",  "2010-2020",
  "population_change_net_2010_2020",   "hanover",      10116,   "count",  "part-4-4",   "Fig 14.1",  "2010-2020",
  "median_household_income_renter",    "hanover",      53832,   "dollars","part-4-4",   "S14.4.1",   "2020",
  "rental_gap_80ami",                  "hanover",      1705,    "count",  "part-4-4",   "Fig 14.13", "2018 shortage (down from 1,840 in 2015)",
  # Town of Ashland (part-4-5)
  "population_change_net_2019_2020",   "ashland",      -310,    "count",  "part-4-5",   "Fig 15.2",  "2019-2020 estimated decline",
  "population_projection_2050",        "ashland",      10000,   "count",  "part-4-5",   "Fig 15.3",  "'nearly', 27 pct increase over 30 years (Weldon Cooper)",
  "median_home_price_2020",            "ashland",      305000,  "dollars","part-4-5",   "S15.4.1",   NA_character_,
  "cost_burdened_renters_count",       "ashland",      690,     "count",  "part-4-5",   "Fig 15.12", "2015",
  "cost_burdened_renters_count",       "ashland",      580,     "count",  "part-4-5",   "Fig 15.12", "2019, 16 pct decrease from 2015",
  # Charles City County (part-4-6)
  "population_total",                  "charles_city", 7256,    "count",  "part-4-6",   "Fig 16.1",  "2010 Census",
  "population_total",                  "charles_city", 6773,    "count",  "part-4-6",   "Fig 16.1",  "2020 Census (loss of 483 since 2010)",
  "median_household_income_renter",    "charles_city", 33661,   "dollars","part-4-6",   "Fig 16.5",  "2020, 22 pct decrease from 2016",
  "rental_gap_80ami",                  "charles_city", 83,      "count",  "part-4-6",   "Fig 16.10", "2018 shortage (down from 104 in 2015)",
  "cost_burdened_owner_share_2019",    "charles_city", 24,      "percent","part-4-6",   "S16.4.2",   "largely unchanged since 2015",
  "cost_burdened_renter_share_2019",   "charles_city", 44,      "percent","part-4-6",   "S16.4.2",   "increased since 2015",
  # Goochland County (part-4-7)
  "population_total_2020",             "goochland",    24727,   "count",  "part-4-7",   "Fig 17.1",  "16 pct increase since 2012",
  "median_home_price_2022",            "goochland",    567980,  "dollars","part-4-7",   "Fig 17.7",  "September 2022 (19 pct increase from $476,293 in Jan 2017)",
  "avg_asking_rent_2022q3",            "goochland",    2208,    "dollars","part-4-7",   "S17.3.2",   "Q3 2022",
  "rental_gap_80ami",                  "goochland",    160,     "count",  "part-4-7",   "Fig 17.12", "2018 shortage (down from 274 in 2015)",
  "cost_burdened_owner_share_2019",    "goochland",    17,      "percent","part-4-7",   "Fig 17.13", "down from 22 pct in 2015",
  "cost_burdened_renter_share_2019",   "goochland",    27,      "percent","part-4-7",   "Fig 17.13", "down from 32 pct in 2015",
  # New Kent County (part-4-8)
  "population_total_2020",             "new_kent",     22945,   "count",  "part-4-8",   "S18.1",     "24 pct increase since 2010",
  "median_home_price_2022",            "new_kent",     409286,  "dollars","part-4-8",   "Fig 18.7",  "May 2022 high (from $296,207 in Sept 2017, ~40 pct increase)",
  "rental_gap_80ami",                  "new_kent",     255,     "count",  "part-4-8",   "Fig 18.11", "2018 shortage (up from 135 in 2015)",
  "cost_burdened_owner_share_2019",    "new_kent",     20,      "percent","part-4-8",   "S18.4.2",   "down from 22 pct in 2015",
  "cost_burdened_renter_share_2019",   "new_kent",     41,      "percent","part-4-8",   "S18.4.2",   "up from 26 pct in 2015",
  # Powhatan County (part-4-9)
  "population_total_2020",             "powhatan",     30333,   "count",  "part-4-9",   "Fig 19.1",  "8 pct increase since 2010",
  "median_home_price_2022",            "powhatan",     522181,  "dollars","part-4-9",   "Fig 19.7",  "May 2022 high (from $283,507 in March 2017, ~84 pct increase)",
  "rental_gap_80ami",                  "powhatan",     70,      "count",  "part-4-9",   "Fig 19.11", "2018 shortage (down from 215 in 2015)",
  "cost_burdened_owner_share",         "powhatan",     16,      "percent","part-4-9",   "Fig 19.12", "down from 24 pct over four years",
  "cost_burdened_renter_share",        "powhatan",     26,      "percent","part-4-9",   "Fig 19.12", "down from ~38 pct"
)

## 8. Assemble tidy frame ----

baseline_2022 <- list(
  demand    = demand_rows    |> mutate(section = "demand"),
  ownership = ownership_rows |> mutate(section = "ownership"),
  rental    = rental_rows    |> mutate(section = "rental"),
  gaps      = gaps_rows      |> mutate(section = "gaps"),
  burden    = burden_rows    |> mutate(section = "burden"),
  local     = local_rows     |> mutate(section = "local")
) |>
  list_rbind() |>
  relocate(metric, geography, value, unit, section, source_page, source_fig, note) |>
  mutate(
    source_page = paste0("rrh-framework/docs/", source_page, ".html"),
    across(c(metric, geography, unit, source_page, source_fig), as.character)
  )

## 9. Write output ----

write_rds(baseline_2022, "data/baseline_2022.rds")
export_csv(baseline_2022, "baseline_2022")
message("Wrote data/baseline_2022.rds + data-out/baseline_2022.csv (", nrow(baseline_2022), " rows)")

## 10. Validate ----
# Structural stopifnot() only -- this frame IS the 2022 vintage, so no same-vintage
# benchmark applies, and 2022 numbers are never a stopifnot() gate regardless (PLAN.md S3).

expected_sections <- c("demand", "ownership", "rental", "gaps", "burden", "local")
expected_local_geos <- c(names(pha), names(secondary), names(ashland))

stopifnot(
  nrow(baseline_2022) > 0,
  setequal(unique(baseline_2022$section), expected_sections),
  !anyNA(baseline_2022$value),
  !anyNA(baseline_2022$metric),
  !anyNA(baseline_2022$geography),
  all(expected_local_geos %in% baseline_2022$geography[baseline_2022$section == "local"]),
  all(baseline_2022$unit %in% c("count", "percent", "dollars", "percentage_points"))
)

message(
  "baseline_2022.R validation passed: ", nrow(baseline_2022), " rows across ",
  n_distinct(baseline_2022$section), " sections, ",
  n_distinct(baseline_2022$geography), " distinct geographies."
)
