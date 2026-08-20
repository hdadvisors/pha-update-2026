# Phase 3: Market data

## Read budget

`.planning/PLAN.md` Sections 1 through 4, this file, and the Section 5 rows for datasets 6 through 13, 20, 21, and 24. Each execution session also reads `_common.R` and invokes `/new-data-script`, which reads CLAUDE.md and PLAN.md on its own. Session 4A additionally reads `data-notes.qmd`'s current "Estimate reliability" section before drafting the race/ethnicity crosswalk. No session reads a reference repo; no session reads a completed phase file.

## Why this phase exists

Four sanctioned deviations (2026-08-06 through 2026-08-20, all run at Jonathan's direction ahead of this file) already built most of Phase 3's dataset inventory: tenure and value/rent medians, cost burden, BPS permits, FRED mortgage rates, NHPD preservation risk, PSH assistance, CHAS Table 7, and the full MLS transaction pipeline. This phase file exists to reconcile that work rather than re-plan it, and to scope what is genuinely still missing — chief among it PLAN.md Section 5 row 7's racial and ethnic homeownership breakdown (B25003A–I), which PLAN.md Section 7 calls out as net-new against the 2022 report and which no script or chapter section covers yet.

Phase 3 is unblocked for everything scoped below. Row 24 (consolidated rental assistance) is not scoped into a session — see "Don't."

## What is already done

- `r/acs_tenure_value.R` → `data/acs_tenure.rds` (B25003 overall tenure: Total/Owner/Renter, no race dimension) and `data/acs_value_rent.rds` (B25077 median home value, B25064 median gross rent). Trend years 2014/2019/2022/2024; geography is the 8 `rr` localities plus Virginia — no Ashland.
- `r/acs_burden.R` → `data/acs_burden.rds` (B25070 renter rent burden, B25091 owner cost burden), pulled ahead for `burden.qmd` but validated and usable now.
- `r/bps.R`, `r/fred.R`, `r/nhpd.R`, `r/psh.R` — building permits, PMMS mortgage rate, NHPD preservation risk, and HUD PSH program mix, all run clean and already feeding `ownership.qmd` and `rental.qmd` figures.
- `r/chas.R` — CHAS Table 7 (income × burden by tenure) only. Tables 8/9/14/15/18 remain unbuilt; Table 9 (race) is Phase 5 scope for `burden.qmd`'s race-and-burden cut, not this phase.
- `r/mls.R` (monthly summary), `r/mls_clean.R` (transaction-level merge/dedupe, run and validated: 110,450 raw rows → 108,430 final), `r/mls_geocode.R` (written, not yet run — needs `tidygeocoder` installed and Jonathan's Geocodio run).
- `r/costar_rental.R` — quarterly locality asking-rent series.
- `ownership.qmd` already has 5 figures (owner-share dumbbell, MLS price trend, home-value bars, BPS permits, PMMS-vs-price) and one open "To be added" callout for sales inventory/months-of-supply.
- `data/raw/hud/hud_fmr_fy2026.xlsx` and `hud_safmr_fy2026.xlsx` are staged (row 12), unprocessed.

None of the above is rebuilt or re-verified by this phase; sessions below build only what's listed as missing.

## Don't

- Rebuild or re-verify any script in "What is already done" — reopen only if a session below finds it insufficient for a specific new figure.
- Scope a session for row 24 (consolidated rental assistance). No LIHTC database file exists anywhere under `data/raw/` — `r/psh.R` covers program-mix and voucher/public-housing counts only, and Section 5 row 24's "consolidated" scope needs LIHTC production data this repo does not have. Blocked on a manual drop from Jonathan; do not substitute PSH alone for it.
- Pull CHAS Tables 8, 9, 14, 15, or 18, or B25106 (tenure × income × burden). Both are Phase 5 scope for `burden.qmd`.
- Build the sales-inventory/months-of-supply figure. It needs an active-listings source the closed-sales MLS export doesn't carry; still open per `ownership.qmd`'s existing callout.
- Guess at a numeric Since-2022 percentage change for racial homeownership. The only 2022 baseline race figure is qualitative ("white households... above 70 pct," no exact value) — the callout in Session 4A is narrative, not a computed delta.
- Pull Ashland into the racial-homeownership script. Its small population suppresses nearly every race category on CV alone; see Session 4A's Phase Decisions row.

## Tasks

Phase 3 is Task 4 in the project's continuous numbering. Commit scopes are `task-4-s4a`, `task-4-s4b`, `task-4-s4c`.

| Session | Scripts / output | Model | Why this grouping |
|---|---|---|---|
| 4A | `r/acs_tenure_race.R` → `data/acs_tenure_race.rds`; `ownership.qmd` racial-homeownership section; `data-notes.qmd` crosswalk | Opus | The reliability design (region-pooled vs. locality-level cut) and the chapter narrative are judgment calls, not a mechanical pull — matches the model policy for gap analysis and chapter-adjacent work |
| 4B | `r/acs_stock.R` → `data/acs_stock.rds` | Sonnet | A mechanical multi-table ACS pull following the same trend-year and CV conventions as every prior Phase 2/3 ACS script |
| 4C | `r/fmr.R` → `data/fmr.rds` | Sonnet | Processes two already-staged local xlsx files; no API call, no CV (administrative figures, not survey estimates) |

### Session 4A: Racial and ethnic homeownership (B25003A–I)

**`r/acs_tenure_race.R`** pulls B25003A through B25003I — White alone, Black alone, American Indian/Alaska Native alone, Asian alone, Native Hawaiian/Pacific Islander alone, other race alone, two or more races, White alone not Hispanic, and Hispanic or Latino — each carrying the same `_001`/`_002`/`_003` total/owner/renter structure as B25003 itself. Resolve each table's variable labels from `load_variables()` rather than hardcoding, the same fix `r/decennial.R` needed for its tenure codes: don't assume the letter-suffix tables share B25003's exact variable numbering without checking.

**Geography:** the 8 `rr` localities plus Virginia — no Ashland (see Phase Decisions). **Years:** 2014/2019/2024 non-overlapping windows, matching `acs_tenure_value.R`'s existing grid so a locality-level owner-rate series can be computed consistently across both frames. **Reliability:** compute the CV (`moe / 1.645 / estimate * 100`) and `flag_reliability()` for every geography × race-category × year cell, in-script, per the standing convention — but do not suppress or pool in the script itself. Export every cell with its tier; the region-pooled-vs-locality cut for the chapter figure is a presentation decision made once the real CV values are in hand, not assumed here.

**`ownership.qmd`** gains one new H2 between the owner-share dumbbell and the MLS price section. Build the primary figure as a region-pooled (8-locality-summed), 2024, direct-labeled bar chart of homeownership rate by race/ethnicity, ordered by rate — no legend needed for a single categorical axis. Add a locality-level second figure only if at least 3 of the 9 categories clear CV-30 at that grain (expected candidates: White alone, Black alone, Hispanic or Latino — confirm empirically, don't assume). The "Since 2022" callout for this section is narrative: state that racial homeownership disaggregation is net-new this cycle and that the 2022 report gave only a qualitative claim (white households above 70 percent, no exact figure) with no computable comparison point.

**`data-notes.qmd`** gains a new subsection after "Estimate reliability" giving the race/ethnicity crosswalk: which B25003 letter suffix maps to which published label, with an explicit note that B25003A (White alone) and B25003H (White alone, not Hispanic or Latino) are different populations and both appear in the export. Update the ACS row in the sources-and-vintages table to mention race/ethnicity homeownership is now loaded.

**Stop here if** fewer than 3 of the 9 categories clear CV-30 even at the region-pooled level. That means the regional figure as designed is too thin to publish — flag it to Jonathan for a scope call rather than shipping a mostly-suppressed chart.

### Session 4B: ACS housing stock

**`r/acs_stock.R`** pulls B25001 (total units), B25002/B25004 (occupancy/vacancy status), B25024 (units in structure), B25034–36 (year built), and B25041/42 (bedrooms). Geography is the 8 `rr` localities, Virginia, and the Ashland place (summary level 160) — these are total-housing-stock tables, not a race breakdown, so Ashland's cells should mostly survive CV-30 unlike Session 4A's. Same trend-year windows and CV/`flag_reliability()` convention as every prior ACS script in this repo.

### Session 4C: HUD FMR and SAFMR

**`r/fmr.R`** reads the two staged xlsx files (`data/raw/hud/hud_fmr_fy2026.xlsx`, `hud_safmr_fy2026.xlsx`) into one tidy frame: region-level FMR by bedroom count and zip-level SAFMR. No API call, no CV — these are administrative HUD figures, not ACS survey estimates, so the validation block checks structure (all 8 localities present in the FMR frame, no all-NA SAFMR column) rather than reliability.

## Verify

- [ ] `r/acs_tenure_race.R`, `r/acs_stock.R`, and `r/fmr.R` exist, are git-tracked, and follow the `/new-data-script` anatomy (header, numbered setup sections, `.Renviron` fallback, `write_rds()` + `export_csv()`, validation block).
- [ ] Each of the three scripts runs clean end to end under the locked renv environment — Jonathan runs them and pastes back console output.
- [ ] `data/acs_tenure_race.rds` covers all 9 B25003A–I categories × 8 `rr` localities × Virginia × 3 years (2014/2019/2024), with every cell carrying a computed reliability tier or a logged reason it's genuinely NA (absent/zero estimate only).
- [ ] `data/acs_stock.rds` covers all 5 table groups × 8 `rr` localities × Virginia × Ashland, no all-NA estimate column.
- [ ] `data/fmr.rds` covers all 8 `rr` localities at the region-FMR grain and all region zip codes at the SAFMR grain.
- [ ] `ownership.qmd` gains the racial-homeownership H2 with its region-pooled figure, a locality-level figure only if ≥3 categories clear CV-30 there, and a narrative (not computed) Since-2022 callout.
- [ ] `data-notes.qmd` gains the race/ethnicity crosswalk subsection and an updated ACS sources-table status row.
- [ ] `quarto render` still exits 0 after the `ownership.qmd` and `data-notes.qmd` edits.
- [ ] Row 24 (consolidated rental assistance) is recorded in this file as blocked on a missing LIHTC data drop, not silently dropped from scope.
- [ ] `.planning/PLAN.md` Section 9's Phase 3 row moves `not planned` → `planned`, linking this file.
- [ ] The `.planning/LOG.md` entry for each session records any `section == "ownership"` `baseline_2022` metric the session's frames reproduce, and states plainly that racial homeownership has no computable 2022 comparison.

## Phase Decisions

Phase-local. A decision that constrains work outside this phase moves to PLAN.md's Decisions table the first time a later phase depends on it.

| Date | Decision | Why | Status |
|---|---|---|---|
| 2026-08-20 | `r/acs_tenure_race.R` pulls `rr` + Virginia only, no Ashland place | Ashland's ~7,500 population suppresses nearly every B25003A–I race category on CV-30 alone; pulling it would add rows the reliability rule immediately drops, matching `acs_tenure_value.R`'s existing geography choice | active |
| 2026-08-20 | The region-pooled-vs-locality-level cut for the racial-homeownership figure is decided at execution from the real CV values, not assumed at planning time | Which of the 9 categories clear CV-30 at the locality grain can't be known before the script runs; scoping a fixed figure list now risks committing to a chart the data can't support | active |
| 2026-08-20 | Racial homeownership's Since-2022 callout is narrative, never a computed percentage change | The only 2022 baseline race figure is qualitative with no exact value ("white households... above 70 pct"); this cycle's disaggregation is genuinely net-new per PLAN.md Section 7, not a trend continuation | active |
| 2026-08-20 | Row 24 (consolidated rental assistance) is not scoped into a Phase 3 session | No LIHTC database file exists under `data/raw/`; `r/psh.R` alone does not satisfy Section 5 row 24's "consolidated" scope, which needs LIHTC production data | active — revisit once Jonathan drops a LIHTC source |

## Open questions

- Which of the 9 B25003A–I categories clear CV-30 at the locality level, once `r/acs_tenure_race.R` actually runs. Fixes Session 4A's second-figure scope; not knowable before the pull.
- Whether `r/acs_stock.R`'s five table groups belong in one output frame or split by concept (occupancy vs. structure vs. age vs. bedrooms) — deferred to the session that writes it, once the actual `load_variables()` output is in hand.
- Where the LIHTC source for row 24 will come from (HUD's public LIHTC database vs. a state QAP list) — Jonathan's call once he's ready to unblock it.
