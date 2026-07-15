# R-standards & validation digest (data scripts)

Condensed from the HDA project conventions (PLAN.md §3 / CLAUDE.md). Read this when you
need the full idiom; the SKILL.md body covers the common path. `references/exemplar-script.R`
is a complete real fhfh script demonstrating all of it.

## Code style

- **Native pipe `|>`**; tidyverse style. `janitor::clean_names()` on all imported raw data.
- **dplyr ≥ 1.2 idioms:** `.by=` over `group_by()` for one-off grouping; `across()`;
  `join_by()`; `reframe()` for multi-row summaries.
- **Variable→label recoding uses `case_when()`** — the pinned dplyr is 1.2.1, where
  `recode_values()` is unavailable and `case_match()` is soft-deprecated. (The exemplar
  script predates this standardization and still uses `case_match()`; **new scripts use
  `case_when()`**.)
- `purrr::map()`/`map_dfr()` over `for` loops. Year-trend pattern:
  `map_dfr(years, \(yr) get_acs(..., year = yr) |> mutate(year = yr))`.
- **tidycensus:** `get_acs(geography, state = "VA", table = "BXXXXX", year, survey =
  "acs5", cache_table = TRUE)`. Pull whole tables; build label lookups from
  `load_variables()` + `separate_wider_delim(label, "!!")`.

## Script anatomy (mandatory order)

1. **Header comment** — what / source (+ vintage) / tables / output.
2. `## 1. Setup ----` — libraries, `source("_common.R")`, `.Renviron` fallback for keys,
   `dir.create("data")`.
3. **Numbered pull sections** (`## 2.`, `## 3.`, …), one per table/source, each with a
   `message()` progress line and a `nrow()` confirmation.
4. `write_rds()` to `data/<name>.rds` **paired with** `export_csv()` to `data-out/`.
5. **Validation block** (see below).

Idempotent — safe to re-run. **No inline `install.packages()`.**

## Reliability CV convention

Carry a **0–100** CV column: `cv = if_else(estimate > 0, (moe / 1.645) / estimate * 100,
NA_real_)`. Chapters tier it with `_common.R`'s `flag_reliability()` (High ≤15 / Medium ≤30
/ Low >30). **Not** `hdatools::add_reliability()` — that assumes a 0–1 scale and mislabels
small-geography cells. Secondary-locality + Ashland (place, sumlev 160) estimates always
get reliability treatment downstream, so always emit the `cv` column for them.

## Validation semantics (locked)

- `stopifnot()` fires **only** on: (a) **structure** — row counts > 0, all expected
  geographies present, no all-NA columns; and (b) **same-vintage** published benchmarks —
  a Census-published table total, HUD-published MFI, or the **SOH deck** numbers (current,
  Jan 2026).
- **2022 baselines** (transcribed from the predecessor's rendered site) are compared as a
  **logged % change** in the progress log — **never** a `stopifnot()` gate. 2020-2024 ACS
  vs 2016-2020 ACS differ by construction; implausible swings get flagged for human review,
  not a failed build.
- Every data task logs its benchmark results (pass + variance + 2022 deltas) to the §11 log.

## API keys

Env vars (`CENSUS_API_KEY`, `FRED_API_KEY`) live in a `.Renviron` outside the project.
**HOME gotcha:** R's HOME may be `C:\Users\JTK`, so `~/Documents/.Renviron` isn't
auto-loaded — every script includes the fallback:
`if (Sys.getenv("KEY") == "") readRenviron("C:/Users/JTK/Documents/.Renviron")`.
Never print or commit key values; verify visibility with a TRUE/FALSE check only.

## Data-fetch rule

tidycensus / tigris / fredr package downloads are approved. Census file servers (BPS, PEP
FTP) and huduser.gov (CHAS, Income Limits) are approved **with manual fallback** — huduser
soft-blocks bare user-agents (send a full browser UA + Referer). Anything else on a
government host (esp. BLS OEWS) needs the user's OK or a manual download.

## Known gotchas

- **PEP:** post-2020 API needs an explicit `vintage=` arg (`year=` alone misbehaves); FTP
  fallback if the API lags.
- **huduser.gov:** browser User-Agent + Referer or returns 202/empty. CHAS data dictionary
  is a **separate** download.
- **Windows:** never run R inline; write the script, run via `Rscript`. Ad-hoc checks →
  scratchpad, not the repo.

## data-out/ commit policy

`export_csv(df, name)` writes `data-out/<name>.csv`. **Naming enforces commit policy via
.gitignore:** name public-source exports plainly (`acs_tenure`); prefix MLS/CoStar-derived
ones `mls_` / `costar_` so they stay out of the public repo and are delivered privately.
