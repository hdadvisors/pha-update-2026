# METHODOLOGY.md — internal data and methodology reference

Internal reference for sessions. Not for public consumption — the PHA-facing methodology (AMI bands, gap definitions, reliability policy, source vintages) lives in `data-notes.qmd`. This file holds the scope and geography calls behind the numbers that don't belong in a public appendix.

## Geography and PUMS

- PUMS regional default is core-3 (Chesterfield, Henrico, Richmond city). Hanover cannot be isolated from the mixed outer PUMAs (08501, 14501), so it never gets a PUMS-based locality estimate — it enters only through county-level ACS tables. Both PUMA sets (`puma_core3`, `puma_region`) are encoded in `_common.R`.
- PUMS locality estimates are core-3 only. Never build one for Hanover or the secondary counties (Charles City, Goochland, New Kent, Powhatan).
- Ashland keeps place-level (sumlev 160) handling in the ACS scripts, not county-level. It's a town, not a county, so it has no county-level record to substitute.

## CHAS (`r/chas.R`)

- Vintage is 2018-2022 5-year estimates throughout. Table variable positions
  (`T7_est*`, `T8_est*`, `T18C_est*`, `T17B_est*`) are resolved from
  `data/raw/chas/CHAS-data-dictionary-18-22.xlsx` at run time, never
  hardcoded — re-verify the dictionary's sheet/column structure before
  reusing this pattern against a different CHAS vintage.
- Geography is the 8 `rr` counties plus `ashland`, same as the rest of
  `chas.R` — not the primary/secondary split used in regional narrative
  chapters.
- `chas_cb` (Table 7) is unchanged cost burden by AMI band and tenure.
  `chas_gap` (Tables 8, 18C, 17B) is the renter-shortage and burden-rate data
  behind a fact-sheet infographic, long/tidy (one row per `geoid` x
  `measure`).
- **"Not computed" households** (Table 8's zero/negative-income category) are
  excluded from every `chas_gap` denominator — shortage, occupant split, and
  burden rate all use only households with a computed burden status. Reported
  as its own `renters_income_not_computed` measure for transparency, never
  summed into anything else.
- **`homes_lowest_rent_tier` includes vacant-for-rent units** (Table 17B), not
  occupied units only. This matches HUD's own published affordability-stock
  convention — Joice, "Measuring Housing Affordability," *Cityscape* 16:1
  (2014), reports "renter-occupied or vacant-for-rent" as the affordability
  denominator, not occupied-only. The occupant-income split
  (`homes_occupied_lowest_income` / `homes_occupied_higher_income`)
  necessarily covers occupied units only, since a vacant unit has no occupant
  to classify.
- `chas_gap` reports both a simple stock-count shortage (`shortage_homes`)
  and an availability-adjusted shortage (`shortage_homes_available`). This is
  HUD's own standard distinction, not a novel addition: the same Joice (2014)
  article's Exhibits 6-7 compute "affordable" vs. "affordable **and
  available**" units, where available means vacant or occupied by a
  household at or below the income threshold in question.
- Table 8 and Table 18C renter-household totals will not match exactly — they
  are correct within their own tabulation universe (Table 8: all occupied
  units; Table 18C: renter-occupied only), and `chas.R`'s validation block
  logs this rather than treating it as an error.
- **Known, unresolved limitation:** HUD's RHUD30/50/80 rent-affordability
  thresholds (Table 18C/17B's rent tiers) are pegged to a *generic* household
  sized to the unit's bedroom count — HUD's own bedroom-based adjustment
  factors run from 0.70x for a studio up to 1.16x+ for 4+ bedrooms (Joice
  2014) — not to the actual size of the household compared against in Table
  8's HAMFI income bands. A small and a large household in the same "≤30%
  HAMFI" band are measured against the same rent threshold even though their
  real affordability constraint differs by family size. This is inherent to
  how CHAS defines RHUD and is not something `chas.R` can correct; it is
  stated as a caveat in `data-notes.qmd` instead.

## Baselines

- 2022 baselines are transcribed from the rendered `rrh-framework` site (`<hda>\rrh-framework\docs\`) only. Never recompute them from raw data and never re-fetch them. The 2022 numbers are the published record; recomputing them would produce a different report than the one being compared against.

## Chart and deliverable scope

- Static ggplot only. No ggiraph, girafe, plotly, or leaflet interactivity. The 2022 report's ggiraph interactivity is not carried forward, and this cycle's deliverable includes a PDF.
- Print fact sheets are produced in Canva. The Quarto locality pages (`local-*.qmd`) are source reference for that process, not the print deliverable itself.

## Out of scope this cycle

Don't build these without a new decision from Jonathan:

- LODES/commuting analysis, QCEW wage analysis (OEWS covers wages this cycle)
- Any interactivity — see Chart and deliverable scope above
- PUMS locality estimates for Hanover or the secondary counties
- Re-computing the 2022 baselines
- Fetching a reference repo, prior-cycle source, or methodology document from the live web — every reference is local. (This is separate from CLAUDE.md's Data-fetch rule, which governs approved API and manual-download sources for report data itself.)

Rule of thumb: if it doesn't serve a chapter figure, a documented method, or a planned data output, it's scope creep.
