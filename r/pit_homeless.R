# pit_homeless.R ----
# What:   Transcribed HUD Point-in-Time (PIT) homeless person counts for the Greater
#         Richmond CoC (VA-500), 2020-2025. Feeds burden.qmd's homelessness figure,
#         updating the 2022 Framework's 2019/2021 pit_count series (data/baseline_2022.rds).
#         This is a DATA DROP, not a computation: every value below is read off the "Total
#         Homeless Persons" row of each year's HUD PopSub PDF and typed in as an R literal --
#         the same approach as baseline.R, chosen because the pinned renv library has no PDF
#         text-extraction package (pdftools) installed. If the region adds a program-level
#         extraction pipeline later, this script can be replaced without changing its output
#         shape.
# Source: HUD CoC Program PopSub reports, VA-500 Richmond/Henrico, Chesterfield, Hanover
#         Counties CoC, one PDF per year, data/raw/coc/CoC_PopSub_CoC_VA-500-<year>_VA_<year>.pdf.
#         2021's unsheltered count is HUD-flagged: COVID-era guidance let CoCs skip the
#         in-person unsheltered survey, so 2021's unsheltered figure may undercount.
# Output: data/pit_homeless.rds  (+ data-out/pit_homeless.csv)

## 1. Setup ----
library(tidyverse)
source("_common.R") # export_csv()

## 2. Transcribed PIT counts, Total Homeless Persons row ----
pit_homeless <- tribble(
  ~year, ~pit_date,    ~sheltered, ~unsheltered, ~total_persons, ~note,
  2020,  "2020-01-22", 416,        130,          546,            NA_character_,
  2021,  "2021-01-27", 736,        98,           834,            "unsheltered count COVID-flagged by HUD; may undercount",
  2022,  "2022-01-26", 612,        85,           697,            NA_character_,
  2023,  "2023-01-25", 502,        188,          690,            NA_character_,
  2024,  "2024-01-24", 475,        206,          681,            NA_character_,
  2025,  "2025-01-22", 516,        143,          659,            NA_character_
) |>
  mutate(pit_date = as.Date(pit_date))

## 3. Write output ----
write_rds(pit_homeless, "data/pit_homeless.rds")
export_csv(pit_homeless, "pit_homeless")
message("Wrote data/pit_homeless.rds + data-out/pit_homeless.csv (", nrow(pit_homeless), " rows)")

## 4. Validate ----
d <- read_rds("data/pit_homeless.rds")
stopifnot(
  nrow(d) == 6,
  setequal(d$year, 2020:2025),
  !anyNA(d$total_persons),
  all(d$sheltered + d$unsheltered == d$total_persons)
)

message("PIT total persons by year:")
print(d |> select(year, sheltered, unsheltered, total_persons))
message("pit_homeless.R validation passed.")
