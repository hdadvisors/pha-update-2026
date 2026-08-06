# Phase 2: Demand data

## Read budget

`.planning/PLAN.md` Sections 1 through 4, this file, and the Section 5 rows for datasets 1 through 5 and 19. Each execution session also reads `_common.R` and invokes `/new-data-script`, which reads CLAUDE.md and PLAN.md on its own. Session 3A additionally reads `data/raw/wcoop/` file headers and `data/raw/README.md`. No session reads a reference repo; no session reads a completed phase file.

## Why this phase exists

The demand section is the first regional chapter and nothing in it can be written until its six source frames exist. This phase builds them: the study-area boundaries every later mapping or spatial join needs, the ACS demographic and income profile, the decennial and PEP population record, and the Weldon Cooper projections that carry the chapter forward past the estimates. It is also the first phase to exercise `/new-data-script` on real work, so the conventions the skill emits get their first test against live API output rather than a scratchpad smoke test.

Phase 2 is unblocked. Every input is either an approved package pull or a file already sitting in `data/raw/`.

## What is already done

- Phase 1 delivered the rendering scaffold, the locked renv environment, `_common.R` with the geography constants and helpers this phase calls, and both scaffolding skills.
- `data/baseline_2022.rds` holds the transcribed 2022 headline frame. Its `section == "demand"` rows are the comparison set for this phase's logged percentage changes.
- `CENSUS_API_KEY` is present in `%USERPROFILE%\Documents\.Renviron` on both machines. `FRED_API_KEY` is missing, which blocks Phase 3 and nothing here.
- Jonathan's manual drops for Weldon Cooper are already in `data/raw/wcoop/`: `VAPopProjections_Total_2030-2050_1July2025.xlsx`, `VAPopProjections_AgeSex_2030-2050_1July2025.xlsx`, `VAPopProjections_LargeTowns_2030-2050_1July2025.xlsx`, and the 2025 methodology docx.
- `r/baseline.R` is the only script in `r/`, so this phase sets the pattern the remaining data phases copy.

## Don't

- Build any figure, table, or chapter content. `demand.qmd` stays the Phase 1 stub until Phase 6.
- Pull any table assigned to a later phase — no B25 stock, tenure, or cost tables, no CHAS, no PUMS, no FRED, no HUD.
- Pull tract or block-group geographies. Section 5 row 19 says "tracts if needed" and no Phase 2 through 6 figure needs them.
- Build a map. The demand section's figure list carries none, and `leaflet` is barred project-wide.
- Recompute any 2022 number. Baselines are transcribed, per the PLAN.md decision of 2026-07-15.
- Run `Rscript` on a long pull. Claude writes the script; Jonathan runs it and pastes back the console output.
- Write the phase's data frames by hand. Every frame comes from a committed, re-runnable script in `r/`.

## Tasks

Phase 2 is Task 3 in the project's continuous numbering, split into three execution sessions of two scripts each. One focus per session, per the token-efficiency rule. Commit scopes are `task-3-s3a`, `task-3-s3b`, and `task-3-s3c`.

| Session | Scripts | Model | Why this grouping |
|---|---|---|---|
| 3A | `r/geo.R`, `r/wcoop.R` | Sonnet | Neither touches the ACS API. Both are self-contained reads — one from `tigris`, one from local xlsx — so they share no failure mode with the API sessions and can run first without blocking anything |
| 3B | `r/acs_demographics.R`, `r/acs_income.R` | Sonnet | Same API, same geographies, same `pull_acs()` helper, same label-lookup idiom. Writing them apart would duplicate every decision |
| 3C | `r/pep.R`, `r/decennial.R` | Sonnet | Both are population counts rather than survey estimates, both feed the same population-change figures, and the PEP Vintage 2025 base is cross-checkable against the 2020 decennial count only if one session holds both |

### Session 3A: Boundaries and projections

**`r/geo.R`** writes the study-area boundaries as `sf` objects. Three frames: the 8 `rr` counties and cities from `tigris::counties(state = "VA", cb = TRUE)`, the Ashland place from `tigris::places(state = "VA", cb = TRUE)` filtered to `ashland`, and the `puma_region` PUMAs from `tigris::pumas(state = "VA", year = 2022)`, which is the call Phase 1 used to resolve the 2020-vintage codes. Set `options(tigris_use_cache = TRUE)` at the top. Leave every frame in the CRS `tigris` returns and record that CRS in the validation block rather than reprojecting. Nothing in this cycle needs a projected CRS, and choosing one now would be a guess about a figure that does not exist yet.

**`r/wcoop.R`** reads the three 2025 Weldon Cooper xlsx files from `data/raw/wcoop/` into one long frame keyed by geography, year, and the projection series. The Total file carries the 8 `rr` localities, the LargeTowns file carries Ashland, and the AgeSex file carries the age and sex detail for the localities that have it. Do not fetch anything; every input is on disk. The published series runs 2030 through 2050, so the frame has no near-term column and the chapter compares projections against the ACS and PEP estimates rather than against an interpolated 2025 projection.

The 2025 release supersedes PLAN.md Section 4's "2024 official release" row and `_common.R`'s `wc_cap(release = 2024)` default. Both change in this session, per the Phase Decisions table below.

**Stop here if** the Total xlsx does not resolve all 8 `rr` localities by name or FIPS, or the LargeTowns xlsx has no Ashland row. Either means the drop is not the file this phase assumed, and the fix is a new drop from Jonathan rather than a workaround in the script.

### Session 3B: ACS demographics and income

**`r/acs_demographics.R`** pulls B01001 age, B01003 population, B03002 race and ethnicity, B11001 household type, B25010 average household size, and B11007 seniors living alone. **`r/acs_income.R`** pulls B19013 median household income, B19001 income distribution, and S1701 poverty status. The S1701 assignment is confirmed rather than changed; see the Phase Decisions table.

Both scripts pull for the 8 `rr` localities, Virginia, and the Ashland place at summary level 160, and both build their label lookups from `load_variables()` with `separate_wider_delim(label, "!!")` rather than hand-typing variable labels. Each writes one long frame with `geoid`, `name`, `year`, `table`, `variable`, `label`, `estimate`, `moe`, and `cv`, so the chapter filters rather than joins across shapes.

Two conventions bind both scripts and every later ACS pull in this repo. The CV column is computed as `moe / 1.645 / estimate * 100`, which is the 0-to-100 scale `flag_reliability()` expects. `flag_reliability()` is applied in the script, not in the chapter, so the reliability tier travels with the frame. Trend series use the three non-overlapping 5-year windows ending 2014, 2019, and 2024 rather than every available endpoint; overlapping 5-year samples are not independent and the Census Bureau advises against comparing them.

### Session 3C: Decennial and PEP

**`r/decennial.R`** pulls population, housing units, and tenure for 2000, 2010, and 2020, for the 8 `rr` localities and the Ashland place. The three vintages come from different summary files and their variable codes do not carry across, so the script builds an explicit year-to-variable map rather than reusing one code vector. Tenure in 2020 comes from the DHC file, not the PL file.

**`r/pep.R`** pulls county totals and components of change through `get_estimates()` with an explicit `vintage = 2025` argument. `year =` alone misbehaves silently on the post-2020 API. If the API has not published Vintage 2025 by the time this session runs, fall back to the Census FTP tables, per the PLAN.md decision of 2026-07-15, and log which route was taken.

Running both in one session makes the cross-check possible: PEP's estimates base is the 2020 decennial count, so each locality's PEP base must equal that locality's 2020 population in `decennial.rds`. That is a same-vintage published-benchmark check and it is a `stopifnot()`, not a logged variance.

**Stop here if** the PEP API returns Vintage 2025 for some localities and not others. A partial vintage is worse than a clean fallback, and the choice between waiting and switching to the FTP tables is Jonathan's.

## Verify

- [x] `r/geo.R`, `r/wcoop.R`, `r/acs_demographics.R`, `r/acs_income.R`, `r/decennial.R`, and `r/pep.R` all exist and are tracked by git.
- [x] Each of the six scripts carries the anatomy `/new-data-script` emits: a header stating what, source, and output; numbered `## N. Setup ----` sections; the `.Renviron` fallback in each script that needs a key; and a validation block.
- [x] Each of the six scripts runs clean end to end under the locked renv environment, and re-running it produces the same output — Jonathan runs them and pastes back the console output. All six re-run as one batch on 2026-08-06 with identical row counts and validation output.
- [x] `data/` holds `geo_localities.rds`, `geo_ashland.rds`, `geo_pumas.rds`, `acs_demographics.rds`, `acs_income.rds`, `decennial.rds`, `pep.rds`, and `wcoop.rds`.
- [x] `data-out/` holds `acs_demographics.csv`, `acs_income.csv`, `decennial.csv`, `pep.csv`, and `wcoop.csv`, and `git check-ignore` exits 1 for each of the five.
- [x] Session 3A's Verify: `geo_localities.rds` has 8 rows, `geo_ashland.rds` has 1, and `geo_pumas.rds` has 9 rows matching `puma_region`.
- [x] Session 3A's Verify: `wcoop.rds` covers all 8 `rr` localities plus Ashland, and the log entry names the projection years present in the frame.
- [x] Session 3B's Verify: `acs_demographics.rds` and `acs_income.rds` each contain rows for all 8 `rr` GEOIDs, Virginia, and place 5103368, with no all-NA column.
- [x] Session 3B's Verify: every row for a `secondary` locality or Ashland **whose CV is computable** carries a non-NA `reliability` value, and the log entry reports how many of those rows are Low and how many are NA by cause. A row whose estimate is absent or zero has no defined CV and is permitted to be NA; both scripts assert that nothing else is. — **amended 2026-08-06** after profiling showed three unrelated causes. Demographics: 218 High, 133 Medium, 101 Low, 18 NA (all zero-estimate). Income: 252 High, 295 Medium, 332 Low, 151 NA (101 absent, 50 zero).
- [x] Session 3B's Verify: `grep -n "moe / 1.645" r/acs_demographics.R r/acs_income.R` matches in both files.
- [x] Session 3C's Verify: `decennial.rds` has rows for 2000, 2010, and 2020 for all 8 `rr` localities and Ashland.
- [x] ~~Session 3C's Verify: the PEP-base-equals-2020-decennial-count `stopifnot()` passes for all 8 localities~~, and the log entry states whether PEP came from the API or the FTP fallback. — **superseded 2026-08-06.** The equality half is void: the estimates base is not the decennial count, and no census-count column exists in this vintage to substitute. `r/pep.R` gates on structure and logs the difference as a published adjustment. The route half is satisfied and logged: API for the series, FTP for the base.
- [x] Each script's `stopifnot()` block asserts structure only, plus any same-vintage published benchmark it uses; no `stopifnot()` compares against `baseline_2022`.
- [x] The `.planning/LOG.md` entry for each session records a percentage change against every `section == "demand"` metric in `baseline_2022` that the session's frames reproduce, and names any that were not reproduced and why.
- [x] PLAN.md Section 4's Weldon Cooper vintage row reads 2025, and `grep -n "release = 2024" _common.R` returns nothing.
- [x] PLAN.md Section 5 row 2 is unchanged, confirming S1701 for `r/acs_income.R`.
- [x] `phases/02-demand-data.md` updated with ticked Verify lines.

## Phase Decisions

Phase-local. A decision that constrains work outside this phase moves to PLAN.md's Decisions table the first time a later phase depends on it.

| Date | Decision | Why | Status |
|---|---|---|---|
| 2026-08-06 | Weldon Cooper is the 2025 release, not the 2024 release PLAN.md Section 4 named. PLAN.md Section 4 and `wc_cap()`'s default both move to 2025 | The 2025 files are what Jonathan dropped in `data/raw/wcoop/`, and a caption naming the wrong release year would appear on every projection figure | active |
| 2026-08-06 | `r/acs_income.R` pulls B19013, B19001, and S1701 as PLAN.md Section 5 already states. B25074 is not added | Poverty belongs to the demand chapter's household profile. B25074 is rent burden, which Section 7 assigns to `burden.qmd` through B25070 in `r/acs_costs.R`. Closes the question open since 2026-07-15 | active |
| 2026-08-06 | ACS trend series use the three non-overlapping 5-year windows ending 2014, 2019, and 2024, not every available endpoint | Overlapping 5-year samples are not independent, so a 15-point series would read as trend where much of the movement is shared sample | active — promote if Phase 3 adopts it for the rent and value trends |
| 2026-08-06 | The CV column is computed in the script as `moe / 1.645 / estimate * 100`, and `flag_reliability()` is applied in the script rather than in the chapter | One formula in one place, and the reliability tier travels with the frame so no chapter can forget to apply it | active — promote when Phase 3 writes its first ACS script |
| 2026-08-06 | `r/geo.R` writes `.rds` only, with no paired `export_csv()` | A CSV of an `sf` geometry column is not usable in Azure or PowerBI, which is the reason the pairing rule exists. This is the one documented exception to it | active |
| 2026-08-06 | Boundaries stay in the CRS `tigris` returns; no reprojection | No figure in this cycle needs a projected CRS, and picking one now would be a guess about a figure that does not exist | active |
| 2026-08-06 | The PEP estimates base is **not** asserted to equal the 2020 decennial count. `r/pep.R` gates on structure only and logs the base-versus-count difference as a published adjustment. Supersedes this phase's PEP Verify line | The premise was factually wrong: Census revises the base for Count Question Resolution, legal boundary updates, and geographic program changes, so the two are different quantities by definition (+572 Henrico, -464 Chesterfield, +44 across the 8). The Vintage 2025 county file ships no census-count column to substitute, so Phase 2 has no valid same-vintage published benchmark at all. Ruled by Jonathan in session | active |
| 2026-08-06 | `r/pep.R` reads the 4/1/2020 estimates base from the Census FTP county file, and carries it in the frame as variable `ESTIMATESBASE` | Vintage 2025's API exposes `POPESTIMATE` and `NPOPCHG` only; its year-2020 row is the 7/1/2020 estimate. The base is the anchor every 2020-2025 change figure counts forward from. This is the FTP fallback the PLAN.md decision of 2026-07-15 anticipated, applied to the one column the API omits | active |
| 2026-08-06 | The CV guard treats a missing or zero MOE on a positive estimate as CV 0, tiering to High. NA reliability is reserved for an absent or zero estimate, and both ACS scripts `stopifnot()` that nothing else produces it | ACS controls table totals to independent population estimates, so they carry no sampling error and Census publishes no MOE. The original guard checked the estimate but not the MOE, so `NA / 1.645 / 26410` propagated to NA and flagged the four secondary counties' total population as unrated -- the most reliable cells in the frame. A chart filtering on reliability would have silently dropped them | active -- promote when Phase 3 writes its first ACS script, alongside the CV-formula row above |
| 2026-08-06 | `r/decennial.R` resolves tenure variables per vintage from `load_variables()` rather than hardcoding codes, and keeps the published rows verbatim rather than pre-summing owner | 2010 and 2020 split owner into "Owned with a mortgage or a loan" and "Owned free and clear"; 2000 does not. A hardcoded offset is valid syntax and silently wrong data — it labelled mortgage-holders "owner" and free-and-clear owners "renter" for 2010. Consequence for Phase 6: a 2000-to-2020 owner series is one row in 2000 and the sum of two rows in 2010 and 2020 | active — promote if Phase 3 pulls decennial tenure |

## Open questions

- The `demand.qmd` figure list is not fixed by this phase. PLAN.md Section 7 fixes the themes; the figure list is drafted in the Phase 6 phase file, once the actual numbers are in hand.
- ~~Whether the AgeSex Weldon Cooper file resolves to individual localities or only to larger aggregates.~~ **Closed 2026-08-06:** county-level, all 8 `rr` localities across 2030/2040/2050, 18 age bands × Total/Female/Male. No town rows, so Ashland has no age detail — the demand chapter uses B01001 for Ashland.
- ~~Whether `get_estimates(vintage = 2025)` exposes components of change at the county level for Virginia.~~ **Closed 2026-08-06:** it does — 576 rows across the 8 localities, counts plus the R-prefixed per-1,000 rates, 2020 through 2025.
- ~~The reliability Verify line requires a non-NA `reliability` on every secondary-locality and Ashland row, but a zero estimate leaves the CV undefined.~~ **Closed 2026-08-06 by Jonathan's ruling,** after profiling showed the NAs had three unrelated causes rather than one. Both halves applied: the CV guard now treats a missing MOE as zero sampling error, and the Verify line permits NA only where the CV is genuinely undefined.
