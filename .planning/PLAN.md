# PLAN.md — Richmond Regional Housing Framework 2026 Data Update: Build Plan

**This file is the source of truth for building the report.** Future Claude sessions execute this plan. They do not renegotiate decisions recorded here. Propose amendments to Jonathan and log them in the Decisions section.

**Read budget:** read Sections 1 through 4 (scope, architecture, and conventions), then only the phase file for the phase being run, plus the Section 5 through 8 rows that phase touches. Do not read the reference repos unless a task sends you there.

## 1. Project context

| | |
|---|---|
| Client | Partnership for Housing Affordability (PHA) |
| Study area | PlanRVA region — 8 localities plus the Town of Ashland (see Section 4) |
| Consultant | HDAdvisors (Jonathan Knopf) |
| Predecessor | 2022 Richmond Regional Housing Framework (`<hda>\rrh-framework`; see Section 2 for `<hda>`) — this repo is its data update |
| Deliverables | Public Quarto book rendered to a website (GitHub Pages) plus a PDF in Phase 7; 5 regional sections; 9 local summaries (web plus Canva print); a regional progress tracker; an executive summary; a complete public repo; Azure and PowerBI-ready CSV exports |
| Already delivered | State of Housing presentation (January 2026 pptx, archived) — seeds the executive summary |
| Explicitly out of scope | See Section 11 |

### Key references

These are local only. Never fetch them from the live web.

Sibling HDA repos live alongside this one under the same parent. `<hda>` is that parent — `C:\repos\hda` on the laptop, `R:\hda` on the desktop. Resolve `<hda>` to your local parent.

- `<hda>\fhfh` — methodology and scaffolding donor: PLAN and CLAUDE structure, `_common.R`, the `r/` script template, the chapter template, `.gitignore`, `.renvignore`, `.Rprofile`.
- `<hda>\rrh-framework` — the 2022 content predecessor: part and chapter organization, `rr` and `pha` FIPS sets, `rrh-framework.scss` and the PHA logo, book config. Its rendered site under `docs/` is the source for the 2022 baseline transcription. Its ggiraph interactivity is not carried forward; this cycle is static ggplot only.
- `<hda>\faar` — PUMS prior art: the `r/pums/` pipeline (`pums_collect`, `pums_prep`, `pums_ami`, `pums_gap`, `pums_labels`, `gwrc_puma`), `gaps-current.qmd` for the affordable-and-available rental gap, and the parameterized `local-*.qmd` fact-sheet chapters.
- `<hda>\hdatools` — `theme_pha()`, `scale_fill_pha()`, `scale_color_pha()`, `add_zero_line()`.
- `archive/soh-2026/` — the delivered State of Housing deck, its 3 R scripts, and stale data drops. The logic folds into `r/` scripts and the deck seeds the executive summary. **The data files here are not canon.**

## 2. Architecture

A Quarto book mirroring both predecessors. Data flows one way: `r/` collection scripts write `data/*.rds`, and chapters call `read_rds()` only. Chapters never call APIs. Every `write_rds()` is paired with an `export_csv()` to `data-out/`, ready for Azure and PowerBI.

```
pha-update-2026/
├── _quarto.yml            # book config: freeze auto, execute-dir project, output-dir docs, noindex meta, Hypothesis
├── _common.R              # sourced by every chapter: libs, pha_pal/cb_pal, geo+PUMA constants, caption helpers, flag_reliability(), export_csv()
├── .Rprofile              # source("renv/activate.R")
├── renv.lock / renv/      # R pinned 4.6.1; dplyr 1.2.1; hdatools 0.1.7 from GitHub hdadvisors/hdatools
├── CLAUDE.md              # repo type, session checklists, and every domain convention
├── README.md              # purpose, quick start, plain-language renv guide, status
├── .planning/             # build scaffolding — PLAN.md (this file), phases/, LOG.md
├── rrh-framework.scss     # brand styling (Noto Sans; from rrh)
├── img/pha_logo.jpg       # sidebar logo (from rrh)
├── index.qmd              # About this update
├── demand.qmd             # Section 1 Housing demand
├── ownership.qmd          # Section 2 Homeownership market
├── rental.qmd             # Section 3 Rental market
├── gaps.qmd               # Section 4 Housing gap
├── burden.qmd             # Section 5 Cost burden and instability
├── data-notes.qmd         # Appendix: data and methodology (doubles as PHA training doc)
│                          # + [Phase 7] 9 local summaries (local-*.qmd), tracker.qmd, exec-sum.qmd
├── r/                     # collection and prep scripts — committed (incl. r/pums/)
├── data/                  # .rds outputs and raw drops — gitignored (except data/raw/README.md)
│   └── raw/{mls,costar}/  # Jonathan's manual drops (spec: data/raw/README.md)
├── data-out/              # tidy CSV exports; public-source committed, mls_*/costar_* gitignored
├── docs/                  # rendered site — committed; GitHub Pages serves this
├── _freeze/               # committed (keeps renders fast and reproducible)
└── archive/soh-2026/      # archived State of Housing deliverables (committed; retained)
```

- Repo: `hdadvisors/pha-update-2026`, public. Pages serves `docs/` on `main`.
- Theming: `hdatools::theme_pha()` and `pha_pal` everywhere. Static ggplot2 and kableExtra tables. No leaflet, no ggiraph.
- Chapter anatomy: `# Title {#sec-slug}` → setup chunk (`source("_common.R")`, `read_rds()` stubs, inline-scalar block) → theme-based takeaway H2s → alternating figure and table blocks with bullets → a per-section "Since 2022" callout → a closing summary callout. The `/new-chapter` skill emits this shape.
- `.planning/` is dot-prefixed, so Quarto skips it without a render exclusion.

## 3. Conventions

Every convention for running a session lives in [CLAUDE.md](../CLAUDE.md), which is the file a session scans mid-work: code style, script anatomy, validation semantics, Windows execution, API keys, the data-fetch rule, chart and table conventions, the narrative rule, the `_common.R` inventory, commit conventions, and the known gotchas. This plan does not restate them.

## 4. Geography and vintages

### Geographies

Constants are defined once in `_common.R`.

| Set | Members (GEOID) | Role |
|---|---|---|
| `rr` (region, 8) | Hanover 51085, Richmond 51760, Goochland 51075, Powhatan 51145, Henrico 51087, New Kent 51127, Charles City 51036, Chesterfield 51041 | Full regional analysis universe |
| `pha` (primary, 4) | Chesterfield 51041, Hanover 51085, Henrico 51087, Richmond 51760 | Core regional narrative |
| `secondary` (4) | Charles City 51036, Goochland 51075, New Kent 51127, Powhatan 51145 | Local summaries only |
| `ashland` (place, sumlev 160) | Ashland town 5103368 | Local summary; place-level ACS with reliability flags |
| `virginia` | 51 | Statewide benchmark |

County and city GEOIDs were confirmed against the State of Housing deck's working `rr` and `pha` vectors. The Ashland place FIPS and the PUMAs below were resolved through `tigris` in Phase 1, never hardcoded from memory.

### PUMS geographies

2020-vintage PUMAs, for the 2020-2024 ACS PUMS.

| Set | PUMAs | Coverage |
|---|---|---|
| `puma_core3` (regional PUMS default) | 04101/04102/04103 (Chesterfield), 08701/08702 (Henrico), 76001/76002 (Richmond city) | The 3 localities that tile cleanly into whole PUMAs |
| `puma_region` | core-3 plus 08501 and 14501 | Adds the two mixed outer PUMAs |

Hanover cannot be isolated. It is split across 08501 (King William, New Kent, Charles City, and eastern Hanover) and 14501 (Goochland, Powhatan, and western Hanover), each of which also contains other counties. That is why core-3 is the locked regional PUMS default; Hanover enters only through county-level ACS tables. `puma_locality` in `_common.R` maps the 7 core-3 PUMAs to their locality labels for PUMS recoding.

### Vintages

As of July 2026. Record the actuals used in `data-notes.qmd`.

| Source | Vintage |
|---|---|
| ACS 5-year (anchor) | 2020–2024 (trend tables back to roughly 2010 for tenure, income, rent, value, population) |
| ACS PUMS | 2020–2024 5-year |
| Decennial | 2000 / 2010 / 2020 |
| PEP | Vintage 2025 (county totals and components; FTP fallback) |
| CHAS | 2018–2022, including race tables |
| HUD Income Limits / FMR / SAFMR | FY2026 |
| Weldon Cooper projections | 2025 official release (July 2025; published series 2030-2050) |
| Bright MLS | 2016 to present, monthly |
| CoStar | 2015 to present, quarterly |
| OEWS | latest release (2024), Richmond MSA |
| Evictions and delinquency | latest available |
| PIT counts | Greater Richmond CoC, latest trend |
| FRED CPI and PMMS (`MORTGAGE30US`) | through current |
| 2022 baseline | rrh-framework rendered site (`<hda>\rrh-framework\docs\`), transcribed in Phase 1 |

## 5. Dataset inventory

This is the streamlined data plan, exported to a Google Doc for PHA in Phase 1. It is curated down from the 2022 report's sprawl to a reduced, purposeful metric list. Each script writes `data/<name>.rds` and `data-out/<name>.csv`.

### A. API and package pulls, no manual step

| # | Dataset | Access | Geography | Script → output | Phase |
|---|---|---|---|---|---|
| 1 | ACS demographics: B01001 age, B01003 pop, B03002 race/eth, B11001 HH type, B25010 size, B11007 seniors alone | tidycensus | rr + VA (+Ashland place) | `r/acs_demographics.R` | 2 |
| 2 | ACS income and poverty: B19013 median (trend), B19001 distribution, S1701 poverty | tidycensus | rr + VA (+Ashland) | `r/acs_income.R` | 2 |
| 3 | PEP: county totals and components of change | tidycensus `get_estimates(vintage=2025)`; FTP fallback | rr | `r/pep.R` | 2 |
| 4 | Decennial 2000/2010/2020: pop, units, tenure | tidycensus | rr (+Ashland) | `r/decennial.R` | 2 |
| 5 | Weldon Cooper 2025 projections | manual xlsx or package | rr | `r/wcoop.R` | 2 |
| 6 | ACS housing stock: B25001 units, B25002/04 occ/vac, B25024 structure, B25034-36 year built, B25041/42 bedrooms | tidycensus | rr + VA (+Ashland) | `r/acs_stock.R` | 3 |
| 7 | ACS tenure and racial homeownership: B25003 plus B25003A–I | tidycensus | rr + VA (+Ashland) | `r/acs_tenure.R` | 3 |
| 8 | ACS costs and burden: B25064 rent (trend), B25077 value (trend), B25070 rent burden, B25091 owner burden, B25106 tenure×income×burden | tidycensus | rr + VA (+Ashland) | `r/acs_costs.R` | 3 / 5 |
| 9 | BPS permits 2000–2025 by structure type | census.gov text files | rr | `r/bps.R` | 3 |
| 10 | FRED: CPI and 30-year PMMS | fredr | national | `r/fred.R` | 3 |
| 11 | HUD FY2026 Income Limits (`calc_ami()`, Richmond MSA) | huduser.gov (browser UA) | Richmond HMFA | `r/hud_ami.R` | 4 |
| 12 | HUD FY2026 FMR and SAFMR | huduser.gov | region + zips | `r/fmr.R` | 3 |
| 13 | NHPD preservation extract | NHPD account | rr filter | `r/nhpd.R` | 3 |
| 14 | CHAS 2018–2022, sumlevels 050 (×8) and 160 (Ashland): T7/T8 (income×tenure×burden), T9 (race), T14/T15 (unit affordability for the rental gap), T18 (distributions) | huduser.gov (script with manual fallback) | rr + Ashland | `r/chas.R` | 5 |
| 15 | PUMS pipeline — collect, prep, AMI assignment, affordable-and-available gap, starter-home gap, burden×race×income, income distributions, labels, PUMA geography | tidycensus `get_pums` | `puma_core3` (+`puma_region` for totals) | `r/pums/{pums_collect,pums_prep,pums_ami,pums_gap,pums_labels,rva_puma}.R` | 4 |
| 16 | OEWS wage affordability | BLS OEWS (Jonathan's OK or manual) | Richmond MSA | `r/oews.R` | 5 |
| 17 | Eviction filings (instability) | LSC Civil Court Data Initiative (`civilcourtdata.lsc.gov`); 4 primary localities only; monthly 2016–2026-06; staged in `data/raw/evictions/` 2026-08-20. Secondary localities not used in this report. Ashland is not separable from Hanover (shared county court system). Delinquency data source TBD. | 4 primary | `r/evictions.R` | 5 |
| 18 | PIT homelessness — Greater Richmond CoC | CoC report, likely transcribed | CoC region | `r/pit.R` | 5 |
| 19 | Boundaries (rr, places, PUMAs, tracts if needed) | tigris + sf | study area | `r/geo.R` | 2 |

### B. Manual downloads by Jonathan into `data/raw/`

The export spec is `data/raw/README.md`.

| # | Dataset | Folder | Needed by |
|---|---|---|---|
| 20 | Bright MLS for-sale: 8 localities plus a regional total; monthly 2016 to latest; sales, median price, listings, days on market, months of supply | `data/raw/mls/` | Phase 3 |
| 21 | CoStar multifamily: Richmond market plus submarkets; quarterly 2015 to latest; inventory, rent, vacancy, under construction, deliveries | `data/raw/costar/` | Phase 3 |

### C. Derived and assembled

| # | Dataset | From | Script | Phase |
|---|---|---|---|---|
| 22 | `affordcalc` (max affordable rent and sales price, income needed) | port from faar | `r/affordcalc.R` | 4 |
| 23 | Gap assembly, wages versus costs, minimum income by price segment | gaps + affordcalc + oews + pums | `r/gaps.R` | 4 / 5 |
| 24 | Consolidated rental assistance (PoSH/HCV, LIHTC, project-based) | HUD PoSH, LIHTC database | `r/assistance.R` | 3 |
| 25 | `baseline_2022` | rrh-framework rendered site, transcribed | `r/baseline.R` | 1 |

### D. Dropped from the 2022 report

Do not build these. See Section 11.

LODES and commuting; QCEW; ggiraph interactivity; per-chapter re-declared geographies; inline `#| eval: false` data-prep chunks, all replaced by `r/` scripts.

## 6. Change-based narrative and the 2022 baseline

The signature analytical convention this cycle is that every section leads with what changed since 2022 and organizes findings by takeaway theme rather than by data-topic heading.

- `baseline_2022` is transcribed from the 2022 rrh-framework rendered site at `<hda>\rrh-framework\docs\`. It is a tidy frame of the 2022 report's headline numbers — population, tenure, median rent and value, burden rates, gap figures — keyed by metric and geography, with the 2022 source figure or table noted.
- Each chapter's setup chunk loads `baseline_2022` and computes the 2020-2024 versus 2022 delta inline. A per-section `::: {.callout-note}` "Since 2022" box states the change in plain terms.
- Baseline deltas are narrative and logged, never a `stopifnot()` gate. Differing vintages make some movement structural rather than real-world change. `data-notes.qmd` documents which comparisons are apples-to-apples and which are vintage-shifted.
- This callout replaces the fhfh interview-crosswalk callout. There are no stakeholder interviews in this engagement.
- The 2022 report defines "the region" as the 4 primary localities only, so every `geography == "region"` row in `baseline_2022` carries that narrower scope rather than the 8-locality `rr` set. Phase 7 documents the caveat.

## 7. Section content plan

Five regional sections in report order, then Phase 7's nine local summaries and the tracker. Each section opens with a one-line purpose comment, uses theme-based takeaway H2s, includes a per-section "Since 2022" callout, applies reliability treatment to secondary-locality and Ashland figures, and uses static ggplot and kableExtra only.

Figure lists here are the target, not the commitment. Final takeaway titles come from the actual numbers, and the detailed figure list for each chapter is drafted in that phase's file. This section fixes scope and theme; the phase file fixes the figures.

### Housing demand (`demand.qmd`)

Population level and change; components of change from PEP; households by type, size, and age; race and ethnicity composition; Weldon Cooper projections. Sources: `acs_demographics`, `acs_income`, `pep`, `decennial`, `wcoop`. The content map comes from the 2022 report's Part 1.

### Homeownership market (`ownership.qmd`)

Sales volume, median price nominal and real, listings, inventory, days on market, production from BPS and housing units, homeownership rate by race and ethnicity (B25003A–I), and income to buy against actual income. Sources: `mls`, `bps`, `acs_tenure`, `acs_stock`, `gaps`. Racial homeownership is net-new against the 2022 report.

### Rental market (`rental.qmd`)

CoStar rents, vacancy, and production; rental stock by structure; FMR and SAFMR against actual rents; NHPD preservation risk; and a consolidated rental assistance picture covering PoSH/HCV, LIHTC, and project-based units, both unit-based and tenant-based. Sources: `costar`, `acs_stock`, `fmr`, `nhpd`, `assistance`. The consolidated assistance view is net-new.

### Housing gap (`gaps.qmd`)

The PUMS-based affordable-and-available rental gap by AMI in the NLIHC style; the starter-home gap, meaning renters who could buy; and minimum income for homeownership by price point, unit size, and structure type against household income profiles. Sources: `r/pums/*`, `gaps`, `hud_ami`, `affordcalc`. This is the core new analysis, extending the faar prior art. Methodology is in Section 8.

### Cost burden and instability (`burden.qmd`)

Cost burden trend and by AMI band from ACS and CHAS; burden by race, ethnicity, and income from PUMS and CHAS T9; wage affordability from OEWS; evictions; delinquency; and PIT homelessness. Sources: `acs_costs`, `chas`, `r/pums/*`, `oews`, `evictions`, `pit`. Race and ethnicity disaggregation of burden is net-new.

### Local summaries and tracker

- Nine local summaries (`local-*.qmd`) from a parameterized template combining the faar `local-*.qmd` pattern with the 2022 report's Part 4 shape of takeaways plus three mirrored sections. Set `local_var`, `mls_var`, and `costar_var` at the top; the body reads the shared `.rds` files. Four primary localities first, then five secondary including Ashland. The Quarto pages are the source reference for the Canva print versions.
- A regional progress tracker (`tracker.qmd`) built from candidate metrics in the existing `.rds` files, with targets flagged for PHA collaboration. This is net-new with no prior art.

### Appendix and executive summary

`data-notes.qmd` carries the source and vintage table from Section 4 actuals; AMI, affordability, and PUMS gap methodology; burden definitions; 2022 baseline comparison caveats naming which comparisons are vintage-shifted; the reliability policy; and the race and ethnicity table crosswalk. It doubles as PHA capacity-building documentation.

`exec-sum.qmd` is a top-level page derived from the delivered State of Housing deck in `archive/soh-2026/`, following the fhfh `exec-sum.qmd` pattern.

## 8. Methodology specs

- **AMI framework:** band thresholds come from HUD-published FY2026 Income Limits (30, 50, and 80 percent by household size) plus HUD's published MFI for the Richmond MSA HMFA. Verify the area assignment from the FY2026 file at build; never assume it. `calc_ami()`, ported from faar, extends the published limits to 100 and 120 percent.
- **PUMS affordable-and-available rental gap:** the NLIHC method. For each AMI band, count renter households at or below the band against rental units that are both affordable to and available to that band, meaning not occupied by higher-income households, then accumulate to a surplus or deficit. Assign AMI to PUMS households from HUD limits at household size. Port the faar `r/pums/` modules `pums_ami` and `pums_gap` and extend them to `puma_core3`. Regional PUMS is core-3; Hanover is excluded per Section 4.
- **Starter-home gap:** renter households whose income could support a mortgage on an entry-level home, calculated through `affordcalc`, against the supply of entry-level for-sale and affordable units. This is the "renters who could buy" measure.
- **Minimum income for homeownership:** the income needed to buy at representative price points by unit size and structure type, against the PUMS household-income distribution, to show how many households can afford each segment. Ownership affordability assumes a payment at or below 28 percent of monthly income. Document the down-payment, rate (current PMMS with the pull date), tax, and insurance assumptions in `data-notes.qmd`; PHA advises on them.
- **Rental affordability:** maximum affordable rent is 30 percent of monthly income, and the income needed is (rent × 12) / 0.30.
- **Cost burden:** above 30 percent is burdened and above 50 percent is severely burdened. Exclude zero and negative incomes and no-cash-rent households, following the CHAS convention. By race and ethnicity, use PUMS householder race and ethnicity by burden and income, plus CHAS T9.
- **Racial homeownership:** B25003A–I owner and renter counts by householder race and ethnicity, converted to an ownership rate per group per geography.
- **Real dollars:** FRED CPI against a latest-period benchmark, following the faar `costar.R` pattern. Label adjusted series explicitly.
- **Reliability:** secondary-locality and Ashland ACS estimates are always CV-flagged through `flag_reliability()`. Report small PIT and eviction counts as counts with a volatility caveat, never as rates.
- **2022 comparison:** compute the delta against `baseline_2022` and flag vintage-shifted comparisons in `data-notes.qmd`.

## 9. Phases

| Phase | Delivers | Status | Issue | Plan |
|---|---|---|---|---|
| 1 | Scaffold, scaffolding skills, and the transcribed 2022 baseline | complete | | [phases/01-setup-baselines.md](phases/01-setup-baselines.md) |
| 2 | Demand data scripts: geo, ACS demographics, ACS income, PEP, decennial, Weldon Cooper | complete | [#2](https://github.com/hdadvisors/pha-update-2026/issues/2) | [phases/02-demand-data.md](phases/02-demand-data.md) |
| 3 | Market data scripts: MLS, CoStar, BPS, ACS stock and tenure, FMR, FRED, NHPD, assistance | planned | [#3](https://github.com/hdadvisors/pha-update-2026/issues/3) | [phases/03-market-data.md](phases/03-market-data.md) |
| 4 | PUMS engine, AMI and affordability calculators, and the gap methodology | not planned | [#4](https://github.com/hdadvisors/pha-update-2026/issues/4) | |
| 5 | Burden and instability data: CHAS, burden trend, OEWS, evictions, PIT | not planned | [#5](https://github.com/hdadvisors/pha-update-2026/issues/5) | |
| 6 | Five regional chapters — the preliminary draft milestone | not planned | [#6](https://github.com/hdadvisors/pha-update-2026/issues/6) | |
| 7 | Local summaries, progress tracker, and final assembly | not planned | [#7](https://github.com/hdadvisors/pha-update-2026/issues/7) | |

Phase 3 is blocked until the Bright MLS and CoStar exports land in `data/raw/` and `FRED_API_KEY` is present in `.Renviron`.

Status vocabulary: `not planned` means no phase file exists yet. `planned` means the phase file exists and its Verify lines are unticked. `in progress` means at least one Verify line has passed. `complete` means every Verify line in the phase file has passed.

Every phase opens with a planning-only session whose sole output is the phase file. Hard rule, no size exemption. A phase whose row reads `not planned` cannot be executed — plan it first.

Tasks stay numbered 1 through 14 inside the phase files, carrying forward the numbering used in commits and in the log. Phase 1 covers tasks 1 and 2; phases 2 through 5 cover tasks 3 through 6 one apiece; phase 6 covers tasks 7 through 11; phase 7 covers tasks 12 through 14.

Phase 6 is the milestone the sequence optimizes for: a full preliminary draft, rendered, commentable through Hypothesis, and shareable with PHA.

## 10. Project Verify

- [ ] `quarto render` completes with no errors and writes every page to `docs/`.
- [ ] `grep -rn "noindex" _quarto.yml` returns nothing.
- [ ] `grep -rln "@fig-\|@tbl-\|@sec-" *.qmd` shows no match inside a `labs(caption=)` or a `footnote()` call.
- [ ] Every `#| label: fig-` chunk in every `.qmd` has a `#| fig-alt:` line.
- [ ] `git ls-files data-out/` lists no file matching `mls_*` or `costar_*`.
- [ ] The PDF output renders and lands in `docs/`.
- [ ] Every headline number in the rendered book traces to a `data/*.rds` file, verified by the Phase 7 number sweep.
- [ ] `README.md` status line names the report as final rather than in progress.

## 11. Project Don't

No phase builds these without Jonathan approving an amendment. Log the request in the Decisions section.

- LODES or commuting analysis.
- QCEW wage analysis; OEWS only this cycle.
- ggiraph or plotly interactivity, leaflet maps, or scrollytelling. Static only.
- Print fact-sheet generation. Canva produces print; the Quarto locality pages are source reference.
- PUMS locality estimates for Hanover or the secondary counties. Core-3 only.
- New datasets or figures beyond Sections 5 and 7.
- Re-computing the 2022 baselines. They are transcribed from the rendered site.
- Fetching anything from the live web. Every reference is local.

Rule of thumb: if it is not needed to render a Section 7 figure, satisfy a Section 8 method, or produce a Section 5 output, it is scope creep.

## 12. Decisions

Append-only. One row per settled decision; never edit a row in place. A settled decision is not re-litigated unless implementation surfaces a contradiction — add a new row and use the Status column to point it at the row it supersedes.

| Date | Decision | Why | Status |
|---|---|---|---|
| 2026-07-15 | Static ggplot only; no girafe or ggiraph anywhere | Interactivity was not carried forward from the 2022 report, and the deliverable includes a PDF | active |
| 2026-07-15 | Hypothesis commenting on preliminary-review pages, through a private group | Hypothesis annotations are public by default, and PHA review comments are not | active |
| 2026-07-15 | PUMS regional default is core-3 (Chesterfield, Henrico, Richmond); both PUMA sets encoded in `_common.R` | Hanover cannot be isolated from the mixed outer PUMAs | active |
| 2026-07-15 | 2022 baselines are transcribed from the local rendered rrh-framework site, not recomputed or fetched | The 2022 numbers are the published record; recomputing them would produce a different report | active |
| 2026-07-15 | Print fact sheets are produced in Canva; the Quarto locality pages are source reference only | Print design is outside the Quarto toolchain | active |
| 2026-07-15 | Public repo from the start, with Pages live and a noindex meta tag until Phase 7 | Reviewers need a live URL before the report is public-facing | active |
| 2026-07-15 | PEP Vintage 2025, checking the API at build and falling back to the FTP tables | The post-2020 API requires an explicit vintage and sometimes lags | active |
| 2026-07-15 | Fresh manual MLS and CoStar exports from Jonathan; the existing `data/` files are archived | The archived exports are stale and their licensing bars redistribution | active |
| 2026-07-15 | Every task opens with an Opus plan-mode session producing a plan and no other work | Planning and execution in one session produces unscoped work | superseded 2026-08-05 by the phase plan gate |
| 2026-07-15 | Model policy: Sonnet for mechanical pulls and QA, Opus for planning, PUMS, gaps, and chapters, Fable for meta-level critique only | Matches model cost to the judgment each session needs | active |
| 2026-07-15 | Validation semantics: `stopifnot()` only on structure and same-vintage benchmarks; 2022 baselines produce logged percentage changes, never a hard failure | 2020-2024 ACS and 2016-2020 ACS differ by construction, so a delta is not an error | active |
| 2026-07-15 | `data-out/` commit policy: public-source CSVs committed, MLS and CoStar derivatives gitignored and delivered privately | The licensed sources cannot be redistributed through a public repo | active |
| 2026-07-15 | Ashland keeps place-level (sumlev 160) handling in the ACS scripts | Ashland is a town, not a county, and has no county-level record | active |
| 2026-07-15 | Dropped entirely: LODES and commuting, and QCEW; OEWS covers wages | Neither earned its place in the reduced metric list | active |
| 2026-08-05 | Build scaffolding moves to `.planning/`: PLAN.md, `phases/NN-slug.md`, and an append-only LOG.md | The `hda-docs` convention; keeps root to README and CLAUDE.md and takes the session log out of the file every session reads | active |
| 2026-08-05 | Seven phases, splitting the former Phase B into one phase per data task | Fits the 4-to-7 phase budget while keeping a planning session on each hard data task | active |
| 2026-08-05 | `EXECUTION-PLAN.md` deleted; git history is its record | Its live content is here, no session was permitted to read it, and it still took maintenance edits | active |
| 2026-08-05 | GitHub Issues adopted: the five house labels, one Issue per remaining phase | Makes the `hda-git:pr` session-close step real and gives the phase table a public counterpart | active |
| 2026-08-05 | Commit scopes stay `task-N` and `task-N-sN` rather than moving to `phase-N` | Keeps the existing history continuous and matches the `hda-git` report row | active |
| 2026-08-05 | The two scaffolding skills stay in-repo at `.claude/skills/` | They are unproven; no chapter has been built and only one `r/` script exists. Promote them to `hda-claude` once phases 2 through 6 exercise them | active |
| 2026-08-05 | No LICENSE file this cycle | Licensing a client deliverable is PHA's call. Revisit at Phase 7 alongside removing the noindex tag | active |
| 2026-08-06 | `data/raw/psh/` (HUD Picture of Subsidized Households county extracts) scoped as a net-new "federal rental-assistance utilization" figure in `rental.qmd` — regional program mix (Housing Choice Vouchers, public housing, project-based Section 8, 202/PRAC, 811/PRAC, Mod Rehab, S236/BMIR) and total assisted units, 2020-2024, from the county-level annual extracts already dropped | The folder has sat present but un-scoped since Phase 2 planning (flagged in `.planning/LOG.md`) and appears nowhere in Section 5's dataset inventory; the extract supports program-mix unit counts and occupancy rates only, not LIHTC production or voucher-holder demographics, so it does not fully satisfy Section 5 row 24's "consolidated rental assistance" scope on its own | active |
