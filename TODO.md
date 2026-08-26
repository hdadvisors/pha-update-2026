# TODO.md — punch list

What's left to finish the report. Start every session here. See [LOG.md](LOG.md) for the history behind any line and [METHODOLOGY.md](METHODOLOGY.md) for the data/scope rules that bound the work.

## Data scripts still missing

- [x] `r/acs_stock.R` — housing stock (B25001, B25002/04, B25024, B25034-36, B25041/42): units, occupancy/vacancy, structure type, year built, bedrooms.
- [ ] `r/fmr.R` — HUD FY2026 FMR and SAFMR by locality/zip. Files already staged under `data/raw/`.
- [ ] `r/oews.R` — OEWS wage affordability, Richmond MSA, latest (2024) release.
- [ ] `r/pums/*` (`pums_collect`, `pums_prep`, `pums_ami`, `pums_gap`, `pums_labels`, `rva_puma`) — the PUMS engine. Blocks `gaps.qmd` sections 1-2 (AMI-banded rental gap, renter-competition table) and the race/ethnicity cost-burden cut in `burden.qmd`. The single biggest remaining build.
- [ ] Consolidated rental assistance (LIHTC piece) — blocked on Jonathan sourcing a LIHTC database file. `r/psh.R` already covers the voucher/public-housing program-mix half.

## MLS pipeline — needs a live run

- [ ] `renv::install("tidygeocoder"); renv::snapshot()`
- [ ] Review `data-out/mls_manual_review.csv` (237 unresolved cross-MLS pairs)
- [ ] Run `Rscript r/mls_geocode.R`
- [ ] Once geocoded, `ownership.qmd`'s "Sales inventory and months of supply" callout still needs an active-listings source — the closed-sales MLS export doesn't carry it.

## Chapter gaps

- [ ] `gaps.qmd` sections 1-2 — depend on the PUMS engine above.
- [ ] `ownership.qmd` — "Sales inventory and months of supply" callout, depends on an active-listings source.
- [ ] `rental.qmd` — "Submarket rents and vacancy" callout, needs CoStar submarket-level detail.
- [ ] `burden.qmd` — "Cost burden by race and ethnicity (CHAS Table 9)" callout, not yet built.
- [ ] `r/affordcalc.R`'s ownership assumptions (10% down, 30-year term, 1.0% property tax, \$1,500/year insurance, no PMI) are explicit placeholders — need PHA review before treating as final.

## Not started

- [ ] 9 local summaries (`local-*.qmd`) — currently 28-line stubs.
- [ ] `tracker.qmd` — regional progress tracker.
- [ ] `exec-sum.qmd` — executive summary, derived from `archive/soh-2026/`.

## Final assembly

- [ ] `data-notes.qmd` sweep — trim to what's relevant for public/PHA consumption; move technical/internal notes to `METHODOLOGY.md`.
- [ ] Decide whether the repo gets a LICENSE file before final publish.
- [ ] Full `quarto render` completes with no errors, every page written to `docs/`.
- [ ] PDF output renders and lands in `docs/`.
- [ ] Remove the `noindex` robots meta tag from `_quarto.yml`.
- [ ] `grep -rln "@fig-\|@tbl-\|@sec-" *.qmd` shows no match inside a `labs(caption=)` or a `footnote()` call.
- [ ] Every `#| label: fig-` chunk has a matching `#| fig-alt:` line.
- [ ] `git ls-files data-out/` lists no file matching `mls_*` or `costar_*`.
- [ ] Every headline number in the rendered book traces to a `data/*.rds` file — a final number sweep.
- [ ] README.md status line names the report as final rather than in progress.
