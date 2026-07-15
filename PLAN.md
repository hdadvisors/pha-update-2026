# PLAN.md — Richmond Regional Housing Framework 2026 Data Update: Build Plan

**This file is the source of truth for building the report.** It was produced 2026-07-15
from `EXECUTION-PLAN.md` (rev. 3, final) — which distilled the scope of work, the 2022
`rrh-framework` predecessor, the `fhfh` methodology, and the `faar` PUMS prior art. Future
Claude sessions execute this plan; they do not renegotiate decisions recorded here. Propose
amendments to Jonathan and log the request in §11.

**How to use this file in a session:** read §1–4 (durable context + conventions), then only
the §9 block for the task/session you're running (+ the task's plan in `plans/` and the §5–8
rows it touches). Don't re-read `EXECUTION-PLAN.md` or the reference repos unless a task says
to. At session end: tick your checkboxes, add a dated §11 entry, commit.

> `EXECUTION-PLAN.md` remains in the repo as the origin/decision record. When the two ever
> disagree, **this file wins** for build mechanics; escalate genuine conflicts to Jonathan.

---

## 1. Project context

| | |
|---|---|
| Client | Partnership for Housing Affordability (PHA) |
| Study area | PlanRVA region — 8 localities + Town of Ashland (see §4) |
| Consultant | HDAdvisors (Jonathan Knopf) |
| Predecessor | 2022 Richmond Regional Housing Framework (`R:\hda\rrh-framework`) — this is its data update |
| This repo's deliverables | **Public Quarto book** → website (GitHub Pages) + PDF (Task 14); 5 regional sections; 9 local summaries (web + Canva print); regional progress tracker; exec summary; complete public repo; Azure/PowerBI-ready CSV exports |
| Already delivered | State of Housing presentation (Jan 2026 pptx, archived) — seeds the exec summary |
| Explicitly out of scope | See §10 |

### Key references (local only — never fetch from the live web)

- `EXECUTION-PLAN.md` — origin plan; §1 investigation findings, §2 reuse inventory, §7 locked decisions.
- `R:\hda\fhfh` — methodology + scaffolding donor: `PLAN.md`/`CLAUDE.md` structure, `_common.R`, `r/` script template (header → `.Renviron` fallback → numbered sections → `write_rds()` → validation block), chapter template, `.gitignore`/`.renvignore`/`.Rprofile`.
- `R:\hda\rrh-framework` — 2022 content predecessor: part/chapter organization, `rr`/`pha` FIPS sets, `rrh-framework.scss` + PHA logo, book config. Its **rendered site** (`docs/`) is the source for the 2022 baseline transcription (Task 2). Its ggiraph interactivity is **not** carried forward (static ggplot only).
- `R:\hda\faar` — PUMS prior art: `r/pums/` pipeline (`pums_collect`/`pums_prep`/`pums_ami`/`pums_gap`/`pums_labels`/`gwrc_puma`) + `gaps-current.qmd` (affordable-and-available rental gap) and parameterized `local-*.qmd` fact-sheet chapters.
- `R:\hda\hdatools` — `theme_pha()`, `scale_fill_pha()`/`scale_color_pha()`, `add_zero_line()` (confirmed in local source).
- `archive/soh-2026/` — the delivered SOH deck + its 3 R scripts + stale data drops. Logic folds into `r/` scripts; deck seeds the exec summary. **Data files here are NOT canon.**

### Decisions locked (EXECUTION-PLAN §7 — do not re-litigate)

1. **Static ggplot only** — no girafe/ggiraph anywhere.
2. **Hypothesis commenting** on preliminary-review pages; PHA reviewers use a **private** Hypothesis group.
3. **PUMS regional default = core-3** (Chesterfield/Henrico/Richmond); both PUMA sets encoded in `_common.R`.
4. **2022 baselines transcribed** from the local rendered rrh-framework site — not recomputed, not fetched.
5. **Print fact sheets in Canva**; Quarto locality pages are source reference only.
6. **Public repo from the start**; Pages live from the start with a **noindex** meta tag (removed in Task 14).
7. **PEP Vintage 2025** — Census FTP confirmed; check API at build, fall back to FTP tables.
8. **Fresh manual MLS/CoStar** from Jonathan (spec in `data/raw/README.md`); existing `data/` files archived.
9. **Every Task opens with an Opus plan-mode session** → task plan in `plans/`, no other work. **Exception: Task 1 (this scaffold) had none — the EXECUTION-PLAN was its plan; Task 2 gets one.**
10. **Model policy:** Sonnet for mechanical pulls/QA; Opus for planning, PUMS, gaps, chapters. **Fable only for meta-level investigation/critique** (sole sanctioned core-work exception: Task 5 gap-methodology design if Opus stalls).
11. **Validation semantics:** `stopifnot()` only on structure + **same-vintage** published benchmarks (SOH deck numbers count — they're current); 2022 baselines produce **logged % changes** in §11, flagged if implausible, **never hard-failed** (vintages differ by construction).
12. **`data-out/` commit policy:** public-source CSVs committed; MLS/CoStar-derived CSVs gitignored, delivered to PHA privately.
13. **Ashland keeps place-level (sumlev 160)** handling in ACS scripts.
14. **Dropped entirely:** LODES/commuting; QCEW (OEWS only for wages).

---

## 2. Architecture

Quarto **book** mirroring both predecessors. Data flows one way: `r/` collection scripts →
`data/*.rds` → chapters `read_rds()` only. **Chapters never call APIs.** Every `write_rds()`
is paired with an `export_csv()` to `data-out/` (Azure/PowerBI-ready).

```
pha-update-2026/
├── _quarto.yml            # book config: freeze auto, execute-dir project, output-dir docs, noindex meta, Hypothesis
├── _common.R              # sourced by every chapter: libs, pha_pal/cb_pal, geo+PUMA constants, caption helpers, flag_reliability(), export_csv()
├── .Rprofile              # source("renv/activate.R")            [created by renv::init(), Task 1 Session 2]
├── renv.lock / renv/      # R >= 4.5; dplyr >= 1.2; hdatools from GitHub hdadvisors/hdatools
├── CLAUDE.md              # session conventions + token-efficiency rules
├── PLAN.md                # this file
├── README.md              # quick-start + plain-language renv guide for teammates
├── rrh-framework.scss     # brand styling (Noto Sans; from rrh)
├── img/pha_logo.jpg       # sidebar logo (from rrh)
├── index.qmd              # About this update
├── demand.qmd             # §1 Housing demand
├── ownership.qmd          # §2 Homeownership market
├── rental.qmd             # §3 Rental market
├── gaps.qmd               # §4 Housing gap
├── burden.qmd             # §5 Cost burden & instability
├── data-notes.qmd         # Appendix: data & methodology (doubles as PHA training doc)
│                          # + [Phase D] 9 local summaries (local-*.qmd) + tracker.qmd
│                          # + [Task 14] exec-sum.qmd top-level page
├── r/                     # collection/prep scripts — COMMITTED (incl. r/pums/)
├── data/                  # .rds outputs + raw drops — gitignored (except data/raw/README.md)
│   └── raw/{mls,costar}/  # Jonathan's manual drops (spec: data/raw/README.md)
├── data-out/              # tidy CSV exports; public-source committed, mls_*/costar_* gitignored
├── docs/                  # rendered site — committed; GitHub Pages serves this
├── _freeze/               # committed (keeps renders fast + reproducible)
├── plans/                 # per-task plan-mode outputs (format ref: R:\hda\fhfh\plans\)
└── archive/soh-2026/      # archived SOH deliverables (committed; retained)
```

- Repo: `hdadvisors/pha-update-2026` (public); Pages from `docs/` on `main`.
- Theming: `hdatools::theme_pha()` + `pha_pal` everywhere. Static ggplot2; `kableExtra` tables. No leaflet/ggiraph.
- Chapter anatomy (adapt fhfh + the `/new-chapter` skill, Task 2): `# Title {#sec-slug}` → setup chunk (`source("_common.R")`, `read_rds()` stubs, inline-scalar block) → **theme-based takeaway H2s** → alternating figure/table + bullet blocks → per-section **"Since 2022"** callout → closing summary callout.

---

## 3. R standards & session conventions

### Code style

- Native pipe `|>`; tidyverse style; `janitor::clean_names()` on all imported raw data.
- **dplyr ≥ 1.2 idioms:** `.by=` over `group_by()` for one-off grouping; `across()`; `join_by()`; `reframe()` for multi-row summaries; `replace_values()`/`replace_when()`; `when_any()`/`when_all()`. For ACS variable→label recoding prefer `recode_values(.unmatched = "error")` **if available in the pinned dplyr**; otherwise `case_when()` (fhfh standardized on `case_when()` because `recode_values()`/`case_match()` were unavailable/deprecated in dplyr 1.2.1 — confirm at Task 3 and note in §11).
- `purrr::map()`/`map_dfr()` over `for` loops (pattern: `map_dfr(years, \(yr) get_acs(..., year = yr) |> mutate(year = yr))`).
- **Script anatomy:** header comment (what/source/output) → `## 1. Setup ----` numbered sections → `.Renviron` fallback for keys → `write_rds()` + `export_csv()` → **validation block**. No inline `install.packages()`. Idempotent — safe to re-run.
- tidycensus: `get_acs(geography, state = "VA", table = "BXXXXX", year, survey = "acs5", cache_table = TRUE)`; pull whole tables, build label lookups from `load_variables()` + `separate_wider_delim(label, "!!")`.

### Validation semantics (locked — §1 decision 11)

- `stopifnot()` fires **only** on: (a) structural expectations (row counts, all geographies present, no all-NA columns), and (b) **same-vintage** published benchmarks — e.g. HUD-published MFI, a Census-published table total, or the **SOH deck numbers** (current, Jan 2026).
- **2022 rrh-framework baselines** are compared as **logged % change in §11**, never `stopifnot()`. Implausible swings get flagged for human review; they never fail a build, because 2020-2024 ACS vs 2016-2020 ACS differ by construction.
- Every data task logs its benchmark results (pass + variance) to §11.

### Execution (Windows — critical for Claude sessions)

- **Never run R inline.** Write `r/<name>.R`, run `Rscript r/<name>.R` from project root. Ad-hoc checks → temp script in the **scratchpad**, run via Rscript — not in the repo.
- **R is not on PATH.** Prepend: `export PATH="/c/Program Files/R/R-4.5.1/bin:$PATH"` (bash) before `Rscript`/`quarto render`. Installed: R 4.4.2 / 4.4.3 / 4.5.0 / 4.5.1 (4.5.1 is the render target).
- Render: `quarto render` (whole book) or `quarto render <file>.qmd` (one section) from project root.
- **Jonathan runs long jobs** (PUMS downloads, CHAS zips, tigris geometries, full renders > ~2 min). Claude writes the script; Jonathan runs it and pastes back errors/validation output. Claude never babysits long `Rscript` runs.
- Forward slashes in R paths; all paths relative to project root.

### API keys

`CENSUS_API_KEY` and `FRED_API_KEY` live in `C:\Users\JTK\Documents\.Renviron`. Never print or
commit values. **Known gotcha (from fhfh):** R's HOME may be `C:\Users\JTK`, so `~/Documents/.Renviron`
isn't auto-loaded — scripts include an `.Renviron` fallback (`readRenviron("C:/Users/JTK/Documents/.Renviron")`
when the key is empty). Verify key visibility with a TRUE/FALSE check only.

### Data-fetch rule

tidycensus/tigris/fredr package downloads are approved. Direct fetches from census.gov file
servers (BPS, PEP FTP) and huduser.gov (CHAS zips, Income Limits) are approved **with manual
fallback** — huduser soft-blocks bare user-agents (send a full browser UA + Referer). **Anything
else on a government host (esp. BLS OEWS) requires Jonathan's OK or a manual download.** Each §9
task lists its prerequisite files.

### Chart & table conventions

- `theme_pha()` + `pha_pal`; `add_zero_line()`. **Titles are takeaway sentences**; subtitle = geography/units/years; caption via a `_common.R` source helper.
- For 2–3 series, prefer color-coded bold words in the subtitle (ggtext spans with `pha_pal` hexes) over legends.
- Currency: `scales::label_dollar()`; note nominal vs. inflation-adjusted in subtitle. Percent: `label_percent(accuracy = 1)` unless precision matters.
- Tables: `kbl() |> kable_styling(c("condensed","striped"))`; `formattable::comma`/`percent`.
- **Secondary-locality + Ashland** ACS estimates always carry reliability treatment via `flag_reliability()` (0–100 CV; High ≤15 / Medium ≤30 / Low >30 — **not** `hdatools::add_reliability()`, which assumes a 0–1 scale and mislabels small cells). Suppress CV>30 cells, footnote Medium cells.
- Every figure gets alt text (`#| fig-alt:`) — use the posit-dev alt-text skill.

### Known gotchas (carried from fhfh memory — expect these)

- **PEP:** post-2020 API requires an explicit `vintage=` arg; `year=` alone silently misbehaves. Use Vintage 2025; FTP fallback if the API lags.
- **huduser.gov:** requires a browser User-Agent + Referer or returns 202/empty.
- **CHAS:** data dictionary is a **separate** download from the table zips.
- **gridtext / `theme_pha`:** `@fig`/`@tbl`/`@sec` cross-refs inside `labs(caption=)` or kbl `footnote()` throw a gridtext `<a>`-tag error — keep cross-refs in **markdown bullets**, never in captions/footnotes.
- **ggplot2 4.0 (S7):** a raw `strip.text = element_text()` override can clash with `theme_pha`'s strip element — avoid overriding it, or de-facet.
- **dplyr:** `case_match()` soft-deprecated; standardize on `case_when()` unless the pinned dplyr supports `recode_values()`.

### Narrative rule

Chapters ship with: takeaway H2s, 2–5 bullet findings per section (plain statements traceable to a
figure/table), and callout boxes (**"Since 2022"** change callouts; data caveats). **No drafted
paragraphs** — bullets specific enough that a human expands them to prose without reopening the data.

### Session hygiene

- Start: read CLAUDE.md + your §9 block + the task's `plans/` file + the recent §11 log. Verify prerequisite raw files exist; if missing, do what doesn't need them and list blockers in §11.
- End: tick §9 checkboxes, add a dated §11 entry (deviations, data surprises, 2022 % changes, open questions), update README/CLAUDE.md if conventions changed, commit (concise message, no Claude/Anthropic co-author).

---

## 4. Geography & vintages

### Geographies (constants defined once in `_common.R`)

| Set | Members (GEOID) | Role |
|---|---|---|
| `rr` (region, 8) | Hanover 51085, Richmond 51760, Goochland 51075, Powhatan 51145, Henrico 51087, New Kent 51127, Charles City 51036, Chesterfield 51041 | Full regional analysis universe |
| `pha` (primary, 4) | Chesterfield 51041, Hanover 51085, Henrico 51087, Richmond 51760 | Core regional narrative |
| `secondary` (4) | Charles City 51036, Goochland 51075, New Kent 51127, Powhatan 51145 | Local summaries only |
| `ashland` (place, sumlev 160) | Ashland town **5103368** | Local summary; place-level ACS with reliability flags |
| `virginia` | 51 | Statewide benchmark |

County/city GEOIDs confirmed against the SOH deck's working `rr`/`pha` vectors. Ashland place
FIPS + the PUMAs below were resolved via `tigris` in Task 1 (never hardcoded from memory).

### PUMS geographies (2020-vintage PUMAs, for 2020-2024 ACS PUMS)

| Set | PUMAs | Coverage |
|---|---|---|
| `puma_core3` (regional PUMS default) | 04101/04102/04103 (Chesterfield), 08701/08702 (Henrico), 76001/76002 (Richmond city) | The 3 localities that tile cleanly into whole PUMAs |
| `puma_region` | core-3 + 08501 + 14501 | Adds the two mixed outer PUMAs |

**Hanover cannot be isolated** — it is split across 08501 (King William, New Kent, Charles City &
Eastern Hanover) and 14501 (Goochland, Powhatan & Western Hanover), each of which also contains
other counties. This is exactly why core-3 is the locked regional PUMS default; Hanover enters only
via county-level ACS tables. `puma_locality` (in `_common.R`) maps the 7 core-3 PUMAs to their
locality labels for PUMS recoding.

### Vintages (as of July 2026 — record actuals used in data-notes.qmd)

| Source | Vintage |
|---|---|
| ACS 5-year (anchor) | **2020–2024** (trend tables back to ~2010 for tenure, income, rent, value, population) |
| ACS PUMS | 2020–2024 5-year |
| Decennial | 2000 / 2010 / 2020 |
| PEP | **Vintage 2025** (county totals + components; FTP fallback) |
| CHAS | **2018–2022** (incl. race tables) |
| HUD Income Limits / FMR / SAFMR | **FY2026** |
| Weldon Cooper projections | 2024 official release |
| Bright MLS | 2016 – present (monthly) |
| CoStar | 2015 – present (quarterly) |
| OEWS | latest release (2024), Richmond MSA |
| Evictions / delinquency | latest available |
| PIT counts | Greater Richmond CoC, latest trend |
| FRED CPI + PMMS (`MORTGAGE30US`) | through current |
| **2022 baseline** | rrh-framework rendered site (`R:\hda\rrh-framework\docs\`) — transcribed, Task 2 |

---

## 5. Dataset inventory  *(= the streamlined data plan; exported to a Google Doc in Task 2)*

Curated **down** from rrh's sprawl to a reduced, purposeful metric list. One-way flow: each script
writes `data/<name>.rds` + `data-out/<name>.csv`.

### A. API / package pulls (no manual step)

| # | Dataset | Access | Geography | Script → output | Task |
|---|---|---|---|---|---|
| 1 | ACS demographics: B01001 age, B01003 pop, B03002 race/eth, B11001 HH type, B25010 size, B11007 seniors alone | tidycensus | rr + VA (+Ashland place) | `r/acs_demographics.R` | 3 |
| 2 | ACS income & poverty: B19013 median (trend), B19001 distribution, S1701 poverty | tidycensus | rr + VA (+Ashland) | `r/acs_income.R` | 3 |
| 3 | PEP: county totals + components of change | tidycensus `get_estimates(vintage=2025)`; FTP fallback | rr | `r/pep.R` | 3 |
| 4 | Decennial 2000/2010/2020: pop, units, tenure | tidycensus | rr (+Ashland) | `r/decennial.R` | 3 |
| 5 | Weldon Cooper 2024 projections | manual xlsx or package | rr | `r/wcoop.R` | 3 |
| 6 | ACS housing stock: B25001 units, B25002/04 occ/vac, B25024 structure, B25034-36 year built, B25041/42 bedrooms | tidycensus | rr + VA (+Ashland) | `r/acs_stock.R` | 4 |
| 7 | ACS tenure + **racial homeownership** B25003 + **B25003A–I** | tidycensus | rr + VA (+Ashland) | `r/acs_tenure.R` | 4 |
| 8 | ACS costs & burden: B25064 rent (trend), B25077 value (trend), B25070 rent burden, B25091 owner burden, B25106 tenure×income×burden | tidycensus | rr + VA (+Ashland) | `r/acs_costs.R` | 4 / 6 |
| 9 | BPS permits 2000–2025 by structure type | census.gov text files | rr | `r/bps.R` | 4 |
| 10 | FRED: CPI + 30-yr PMMS | fredr | national | `r/fred.R` | 4 |
| 11 | HUD FY2026 Income Limits (`calc_ami()`, Richmond MSA) | huduser.gov (browser UA) | Richmond HMFA | `r/hud_ami.R` | 5 |
| 12 | HUD FY2026 FMR + SAFMR | huduser.gov | region + zips | `r/fmr.R` | 4 |
| 13 | NHPD preservation extract | NHPD account | rr filter | `r/nhpd.R` | 4 |
| 14 | CHAS 2018–2022, sumlevels 050 (×8) + 160 (Ashland): T7/T8 (income×tenure×burden), **T9 (race)**, T14/T15 (unit affordability for rental gap), T18 (distributions) | huduser.gov (script + manual fallback) | rr + Ashland | `r/chas.R` | 6 |
| 15 | **PUMS pipeline** — collect, prep, AMI assignment, affordable-and-available gap, starter-home gap, burden×race×income, income distributions, labels, PUMA geography | tidycensus `get_pums` | `puma_core3` (+`puma_region` for totals) | `r/pums/{pums_collect,pums_prep,pums_ami,pums_gap,pums_labels,rva_puma}.R` | 5 |
| 16 | OEWS wage affordability | BLS OEWS (Jonathan OK / manual) | Richmond MSA | `r/oews.R` | 6 |
| 17 | Evictions + delinquency (instability) | latest sources (refresh rrh inline logic) | rr | `r/evictions.R` | 6 |
| 18 | PIT homelessness — Greater Richmond CoC | CoC report (likely transcribe) | CoC region | `r/pit.R` | 6 |
| 19 | Boundaries (rr, places, PUMAs, tracts if needed) | tigris + sf | study area | `r/geo.R` | 3 |

### B. Manual downloads by Jonathan → `data/raw/` (spec: `data/raw/README.md`)

| # | Dataset | Folder | Needed by |
|---|---|---|---|
| 20 | **Bright MLS** for-sale (8 localities + regional total; monthly 2016–latest; sales, median price, listings, DOM, months supply) | `data/raw/mls/` | Task 4 |
| 21 | **CoStar** multifamily (Richmond market + submarkets; quarterly 2015–latest; inventory, rent, vacancy, under-construction, deliveries) | `data/raw/costar/` | Task 4 |

### C. Derived / assembled

| # | Dataset | From | Script | Task |
|---|---|---|---|---|
| 22 | `affordcalc` (max affordable rent/sales, income-needed) | port faar | `r/affordcalc.R` | 5 |
| 23 | Gap assembly, wages-vs-costs, min-income-by-price-segment | gaps + affordcalc + oews + pums | `r/gaps.R` | 5 / 6 |
| 24 | Consolidated rental assistance (PoSH/HCV + LIHTC + project-based) | HUD PoSH, LIHTC db | `r/assistance.R` | 4 |
| 25 | `baseline_2022` | rrh-framework rendered site (transcribed) | `r/baseline.R` (or a data-drop) | 2 |

### D. Dropped from rrh (do not build — §10)

LODES/commuting; QCEW; ggiraph interactivity; per-chapter re-declared geographies; inline
`#| eval: false` data-prep chunks (all replaced by `r/` scripts).

---

## 6. Change-based narrative & the 2022 baseline

The signature analytical convention this cycle (EXECUTION-PLAN §3): every section leads with **what
changed since 2022** and organizes findings by **takeaway theme**, not by data-topic heading.

- **`baseline_2022`** (Task 2) is transcribed from the 2022 rrh-framework **rendered site** (`R:\hda\rrh-framework\docs\`) — a tidy frame of the 2022 report's headline numbers (population, tenure, median rent/value, burden rates, gap figures, etc.), keyed by metric × geography, with the 2022 source figure/table noted.
- Each chapter's setup chunk loads `baseline_2022` and computes the 2020-2024-vs-2022 delta inline; a per-section **`::: {.callout-note}` "Since 2022"** box states the change in plain terms.
- Baseline deltas are **narrative + logged**, never a `stopifnot()` gate (§3 validation semantics): differing vintages make some movement structural, not real-world change. Data-notes documents which comparisons are apples-to-apples vs vintage-shifted.
- This callout **replaces** fhfh's interview-crosswalk callout (there are no stakeholder interviews in this engagement).

---

## 7. Section content plan

Five regional sections (report order), then Phase D's 9 local summaries + tracker. Each section:
(a) opens with a 1-line purpose comment, (b) uses theme-based takeaway H2s, (c) includes a
per-section "Since 2022" callout, (d) applies reliability treatment to secondary-locality/Ashland
figures, (e) is static ggplot + kableExtra only. Figure lists are the target; final takeaway titles
come from the actual numbers. **Detailed figure lists are drafted in each chapter task's `plans/`
file (Tasks 7–11), not frozen here** — this section fixes scope and theme, the task plan fixes the
figures.

### §1 — Housing demand (`demand.qmd`, Task 7)
Population level + change; components of change (PEP); households by type/size/age; race/ethnicity
composition; projections (Weldon Cooper). Sources: `acs_demographics`, `acs_income`, `pep`,
`decennial`, `wcoop`. Content map ← rrh Part 1.

### §2 — Homeownership market (`ownership.qmd`, Task 8)
Sales volume, median price (nominal + real), listings/inventory/DOM, production (BPS + HU),
**homeownership rate by race/ethnicity (B25003A–I)**, income-to-buy vs actual income. Sources:
`mls`, `bps`, `acs_tenure`, `acs_stock`, `gaps`. **Net-new vs rrh:** racial homeownership.

### §3 — Rental market (`rental.qmd`, Task 9)
CoStar rents + vacancy + production; rental stock by structure; FMR/SAFMR vs actual; NHPD
preservation risk; **consolidated rental assistance picture** (PoSH/HCV + LIHTC + project-based —
unit- and tenant-based). Sources: `costar`, `acs_stock`, `fmr`, `nhpd`, `assistance`. **Net-new:**
the consolidated assistance view.

### §4 — Housing gap (`gaps.qmd`, Task 10)
**PUMS-based affordable-and-available rental gap by AMI** (NLIHC-style); **starter-home gap** (renters
who could buy); **minimum income for homeownership by price point / size / type vs household income
profiles**. Sources: `r/pums/*`, `gaps`, `hud_ami`, `affordcalc`. This is the core new analysis (faar
prior art, extended). Methodology: §8.

### §5 — Cost burden & instability (`burden.qmd`, Task 11)
Cost burden trend + by AMI band (ACS + CHAS); **burden × race/ethnicity × income** (PUMS + CHAS T9);
wage affordability (OEWS); evictions; delinquency; PIT homelessness. Sources: `acs_costs`, `chas`,
`r/pums/*`, `oews`, `evictions`, `pit`. **Net-new:** race/ethnicity disaggregation of burden.

### Phase D — local summaries + tracker
- **9 local summaries** (`local-*.qmd`, Task 12): parameterized template (faar `local-*.qmd` ×
  rrh Part 4 — Takeaways + 3 mirrored sections). Set `local_var`/`mls_var`/`costar_var` at top; body
  reads shared `.rds`. 4 primary (session 1) + 5 secondary incl. Ashland (session 2). Quarto pages =
  source reference for Canva print versions.
- **Regional progress tracker** (`tracker.qmd`, Task 13): candidate metrics from existing `.rds`;
  targets flagged for PHA collaboration (net-new; no prior art).

### Appendix — Data notes (`data-notes.qmd`, Task 14)
Source & vintage table (§4 actuals); AMI + affordability + PUMS-gap methodology; burden definitions;
2022-baseline comparison caveats (which comparisons are vintage-shifted); reliability policy;
race/ethnicity table crosswalk. **Doubles as PHA capacity-building documentation.**

### Exec summary (`exec-sum.qmd`, Task 14)
Top-level page derived from the delivered SOH deck (`archive/soh-2026/`); fhfh `exec-sum.qmd` pattern.

---

## 8. Methodology specs

- **AMI framework:** band thresholds from HUD-published FY2026 Income Limits (30/50/80% by household
  size) + HUD's published MFI for the **Richmond MSA HMFA** — verify the area assignment from the
  FY2026 file at build, never assume. `calc_ami()` (faar port) extends published limits to 100/120%.
- **PUMS affordable-and-available rental gap (core new analysis):** NLIHC method — for each AMI band,
  count renter households at or below the band vs rental units both **affordable** to and **available**
  (not occupied by higher-income households) to that band → cumulative surplus/deficit. Assign AMI to
  PUMS households from HUD limits at household size. Port faar `r/pums/` (`pums_ami`, `pums_gap`);
  extend to the Richmond `puma_core3` set. Regional PUMS = core-3 (Hanover excluded — §4).
- **Starter-home gap:** renter households whose income could support a mortgage on an entry-level home
  (via `affordcalc`) vs the supply of entry-level for-sale/affordable units — "renters who could buy."
- **Minimum income for homeownership:** income needed to buy at representative price points × unit
  size × structure type, vs the PUMS household-income distribution — how many households can afford
  each segment. Ownership affordability: payment ≤ 28% of monthly income; document down-payment, rate
  (current PMMS + pull date), tax, and insurance assumptions (PHA advises) in data-notes.
- **Rental affordability:** max affordable rent = 30% × monthly income; income-needed = (rent × 12) / 0.30.
- **Cost burden:** >30% burdened, >50% severely; exclude zero/negative-income and no-cash-rent (CHAS convention). **By race/ethnicity:** PUMS (householder race/ethnicity × burden × income) + CHAS T9.
- **Racial homeownership:** B25003A–I owner/renter counts by householder race/ethnicity → ownership rate per group, per geography.
- **Real dollars:** FRED CPI, latest-period benchmark (faar `costar.R` pattern); label adjusted series explicitly.
- **Reliability:** secondary-locality + Ashland ACS always CV-flagged via `flag_reliability()` (§3); PIT/eviction small counts as counts with volatility caveats, never rates.
- **2022 comparison:** delta vs `baseline_2022`; flag vintage-shifted comparisons in data-notes (§6).

---

## 9. Task plan

Hierarchy: **Phase → Task → Session(s).** Data tasks produce scripts + `.rds`/CSV only; chapter tasks
only consume. **Every Task from Task 3 on opens with an Opus plan-mode session** → a plan in `plans/`
(session outline + prompt-helper starter prompts + model recs + doc/log references), no other work.
Task 1 had none (EXECUTION-PLAN was its plan); Task 2 gets one.

**Common DoD for data tasks (3–6):** scripts run clean via `Rscript` (Jonathan runs the long ones);
`.rds` + `data-out/` CSV written; **hard validation** (`stopifnot`) passes on structure +
same-vintage benchmarks; **2022-baseline % change logged in §11** (implausible swings flagged, never
hard-failed); committed. **Common DoD for chapter tasks (7–11):** section renders clean into the book;
all figures static ggplot with fig-alt, takeaway H2s, "Since 2022" callout, reliability treatment;
no `@`-refs in captions; §11 entry; committed.

### Phase A — Setup

#### Task 1 — Scaffold  *(no planning session; this doc's origin was its plan)*
- [x] Archive SOH assets → `archive/soh-2026/` (scripts, img, pptx, all stale data)
- [x] `git init`; public repo `hdadvisors/pha-update-2026`; `.gitignore` per §1.12; Pages from `docs/`
- [x] Quarto book skeleton (index + 5 section stubs + data-notes appendix) renders clean to `docs/` with **noindex** meta + **Hypothesis** comments
- [x] `_common.R` (pha_pal, cb_pal, rr/pha/secondary/Ashland/PUMA constants, caption helpers, `flag_reliability()`, `export_csv()`)
- [x] `_quarto.yml` (rrh book config + fhfh execute settings) + scss + logo
- [x] `data/raw/README.md` = MLS/CoStar export spec
- [ ] PLAN.md (this file) + CLAUDE.md + README.md  *(Session 2 — in progress)*
- [ ] renv config written; **Jonathan runs `renv::init()`/`snapshot()`** and pastes output  *(Session 2)*
- **DoD:** skeleton renders clean + live (noindexed) on Pages; PLAN/CLAUDE/README written; renv snapshotted.
- **Don't:** pull any data; build any figure; transcribe the baseline; build skills.

#### Task 2 — Skills + baselines  *(+ planning session)*
- [ ] Build `/new-data-script` + `/new-chapter` universal (user-level) skills, parameterized on a project-config block; exemplars in the skills' reference files
- [ ] `baseline_2022` transcribed from `R:\hda\rrh-framework\docs\` → `data/baseline_2022.rds` (+ CSV)
- [ ] Export the §5 dataset inventory to a Google Doc for PHA (streamlined data plan)
- **DoD:** both skills invocable + documented; baseline frame validated (spot-check ≥10 headline numbers against the rendered pages); data plan doc shared.
- **Don't:** gate Phase B on PHA sign-off; pull live data; build chapter content.

### Phase B — Data collection (scripts + validation only; no figures)

#### Task 3 — Demand data (Sonnet)
- [ ] `r/geo.R`, `r/acs_demographics.R`, `r/acs_income.R`, `r/pep.R` (Vintage 2025; FTP fallback), `r/decennial.R`, `r/wcoop.R`
- **DoD (data):** as common; validate pop/HH/income vs SOH deck + Census-published totals; log 2022 deltas.
- **Don't:** touch market/PUMS/CHAS; build figures.

#### Task 4 — Market data (Sonnet)
- [ ] `r/mls.R` + `r/costar.R` (fresh exports; CPI-adjust + splice patterns), `r/bps.R`, `r/acs_stock.R`, `r/acs_tenure.R` (+B25003A–I), `r/fmr.R`, `r/fred.R`, `r/nhpd.R`, `r/assistance.R` (PoSH/HCV/LIHTC)
- **Prereq:** MLS + CoStar exports in `data/raw/` (spec: `data/raw/README.md`).
- **DoD (data):** validate MLS/CoStar/NHPD vs SOH deck numbers (current); log 2022 deltas.
- **Don't:** build figures; start PUMS.

#### Task 5 — PUMS engine (Opus; hardest — plan may recommend a one-off Fable escalation for gap-methodology design if Opus stalls)
- [ ] Port faar `r/pums/` to Richmond `puma_core3`; `r/hud_ami.R` + `r/affordcalc.R` ports
- [ ] Rental gap by AMI (affordable-and-available); starter-home gap; burden×race/ethnicity×income; income distributions for min-income comparisons; `r/gaps.R` assembly
- **DoD (data):** gap direction + magnitudes sanity-checked vs NLIHC/rrh framing; PUMA recode verified against `puma_locality`; log 2022 deltas where comparable.
- **Don't:** build figures; use `puma_region` for locality estimates (core-3 only).

#### Task 6 — Burden & instability data (Sonnet, some Opus judgment)
- [ ] `r/chas.R` (050×8 + 160 Ashland; T7/T8 + **T9 race** + T14/T15 + T18), extend `r/acs_costs.R` (burden trend), `r/oews.R`, `r/evictions.R`, `r/pit.R` (Greater Richmond CoC), min-income-by-price-segment assembly into `r/gaps.R`
- **DoD (data):** CHAS validates against CHAS-appropriate ranges (not ACS); OEWS release recorded; log 2022 deltas.
- **Don't:** build figures.

### Phase C — Regional chapters (report order; Opus) — **preliminary draft lands here**

- [ ] **Task 7 — Housing demand** (`demand.qmd`)
- [ ] **Task 8 — Homeownership market** (`ownership.qmd`)
- [ ] **Task 9 — Rental market** (`rental.qmd`)
- [ ] **Task 10 — Housing gap** (`gaps.qmd`)
- [ ] **Task 11 — Cost burden & instability** (`burden.qmd`)
- **Phase deliverable:** full preliminary draft — rendered book, all 5 sections, Hypothesis-commentable, shareable with PHA. **This is the milestone the sequence optimizes for.**
- **Don't (all):** call APIs from chapters; add datasets/figures beyond §5/§7 without a logged amendment; put `@`-refs in captions.

### Phase D — Local summaries + tracker

- [ ] **Task 12 — Local summaries** (`local-*.qmd`): parameterized template; session 1 = template + 4 primary; session 2 = 5 secondary (incl. Ashland). Quarto = Canva source reference.
- [ ] **Task 13 — Progress tracker** (`tracker.qmd`): candidate metrics from `.rds`; targets flagged for PHA.

### Phase E — Assembly & QA

- [ ] **Task 14 — Assembly:** `exec-sum.qmd` (from SOH deck) as top-level page; index/About; `data-notes.qmd`; full render (Jonathan-run); number sweep vs baselines; reliability/alt-text pass; PDF render (add `downloads: pdf` + scrreprt config); `data-out/` export sweep (confirm MLS/CoStar-derived CSVs stayed out of the repo); **remove the noindex meta tag**; repo docs finalized.

---

## 10. Scope guardrails — out of scope

No task builds these without Jonathan approving an amendment (log the request in §11):

- LODES / commuting analysis (dropped — EXECUTION-PLAN §7)
- QCEW wage analysis (OEWS only this cycle)
- ggiraph/plotly interactivity, leaflet maps, scrollytelling (static only)
- Print fact-sheet **generation** (Canva does print; Quarto locality pages are source reference)
- PUMS locality estimates for Hanover or the secondary counties (core-3 only; §4)
- New datasets/figures beyond §5 + §7
- Re-computing 2022 baselines (transcribed from the rendered site — §1.4)
- Fetching anything from the live web (all references are local)

Rule of thumb: if it isn't needed to render a §7 figure, satisfy a §8 method, or produce a §5 output,
it's scope creep.

---

## 11. Progress log

### Task status

| # | Task | Phase | Status | Date | Model |
|---|---|---|---|---|---|
| 1 | Scaffold | A | in progress (S1 done; S2 in progress) | 2026-07-15 | Opus 4.8 |
| 2 | Skills + baselines | A | not started | | |
| 3 | Demand data | B | not started | | |
| 4 | Market data | B | not started | | |
| 5 | PUMS engine | B | not started | | |
| 6 | Burden & instability data | B | not started | | |
| 7 | Housing demand chapter | C | not started | | |
| 8 | Homeownership chapter | C | not started | | |
| 9 | Rental chapter | C | not started | | |
| 10 | Housing gap chapter | C | not started | | |
| 11 | Cost burden chapter | C | not started | | |
| 12 | Local summaries | D | not started | | |
| 13 | Progress tracker | D | not started | | |
| 14 | Assembly & QA | E | not started | | |

### Log

- **2026-07-15** — **Task 1 Session 1 (Scaffold) complete** (Opus 4.8). Archived all SOH assets → `archive/soh-2026/` (3 scripts, `img/` 7 PNGs, the pptx, and all 8 stale `data/` files). `git init` on `main`; created **public** repo `hdadvisors/pha-update-2026`; enabled GitHub Pages from `main`/`docs` (`https://hdadvisors.github.io/pha-update-2026/`). Wrote `.gitignore` (commits `r/`/`docs/`/`_freeze/` + public-source `data-out/`; ignores `data/` except `data/raw/README.md`, plus `data-out/mls_*`/`costar_*`) — verified with `git check-ignore`. Built the Quarto book skeleton: `index.qmd` + 5 section stubs (`demand`/`ownership`/`rental`/`gaps`/`burden`) + `data-notes.qmd` appendix; `_quarto.yml` (rrh book config + fhfh `execute-dir: project`/`freeze: auto`; **noindex** robots meta + **Hypothesis** comments); copied `rrh-framework.scss` + `img/pha_logo.jpg`. `_common.R`: `pha_pal` (SOH hexes) + `cb_pal`; geography constants `rr`(8)/`pha`(4)/`secondary`(4)/`ashland`/`virginia`; PUMS `puma_core3`/`puma_region`/`puma_locality`; caption helpers (`acs`/`pums`/`chas`/`dec`/`pep`/`wc`/`bps`/`mls`/`costar`/`fmr`/`ami`/`nhpd`/`posh`/`lihtc`/`oews`/`pit`/`cpi`/`pmms`); `flag_reliability()` (0–100 CV, 15/30); `fct_wrap()`; `export_csv()`. `data/raw/README.md` = MLS/CoStar export spec (fields grounded in the archived exports' actual columns + fhfh `mls.R`/`costar.R` expectations). **Geography resolution (tigris, not memory — the note in `_common.R`):** Ashland town place FIPS = **5103368** (my memory guess 5102270 was wrong — validates the "resolve, don't recall" rule); 2020 PUMAs resolved for `year=2022` — core-3 = 04101/04102/04103 (Chesterfield), 08701/08702 (Henrico), 76001/76002 (Richmond); Hanover confirmed **not isolable** (split across 08501 + 14501, each multi-county) → core-3 is the right regional default. **Render:** `quarto render` clean under R 4.5.1 — 7 HTML pages in `docs/`, noindex meta on all 7, Hypothesis present, logo + `_freeze/` produced. **Deviations from the EXECUTION-PLAN Task 1 list:** (1) `_quarto.yml` is **HTML-only** — `downloads: pdf` + scrreprt config deferred to Task 14 so the skeleton renders clean without a LaTeX/typst toolchain (fhfh deferred its PDF route the same way); (2) `.Rprofile`/`.renvignore` **not** created in Session 1 — an `.Rprofile` sourcing the not-yet-existing `renv/activate.R` would break the Session 1 render; both come with `renv::init()` in Session 2; (3) chapter files named by theme (`demand`/`ownership`/…) rather than rrh's `part-N-M` scheme, matching the reduced 5-section preliminary structure. **First commit** `b772e1c`, pushed. **Open for Session 2:** PLAN.md (this file — done), CLAUDE.md, README.md, renv config + Jonathan runs init/snapshot.

*(Session 2 entry to append after CLAUDE.md/README/renv: files created, renv package list + snapshot output, any deviations.)*
