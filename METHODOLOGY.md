# METHODOLOGY.md — internal data and methodology reference

Internal reference for sessions. Not for public consumption — the PHA-facing methodology (AMI bands, gap definitions, reliability policy, source vintages) lives in `data-notes.qmd`. This file holds the scope and geography calls behind the numbers that don't belong in a public appendix.

## Geography and PUMS

- PUMS regional default is core-3 (Chesterfield, Henrico, Richmond city). Hanover cannot be isolated from the mixed outer PUMAs (08501, 14501), so it never gets a PUMS-based locality estimate — it enters only through county-level ACS tables. Both PUMA sets (`puma_core3`, `puma_region`) are encoded in `_common.R`.
- PUMS locality estimates are core-3 only. Never build one for Hanover or the secondary counties (Charles City, Goochland, New Kent, Powhatan).
- Ashland keeps place-level (sumlev 160) handling in the ACS scripts, not county-level. It's a town, not a county, so it has no county-level record to substitute.

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
