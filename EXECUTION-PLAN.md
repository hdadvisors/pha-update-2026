# PHA 2026 Data Update — Project Execution Plan (rev. 3 — final, pre-Phase-A)

## Context

New engagement: the 2026 Data Update to the Richmond Regional Housing Framework for the Partnership for Housing Affordability (PHA) — the direct successor to `rrh-framework` (2022 update), built with the session methodology proven in `fhfh` (Fauquier HNA).

**Goals:**
1. Full reviewable preliminary draft as fast as possible, maximizing reuse of existing scaffolding.
2. **Token efficiency**: tight per-session focus, right-sized model/effort per task, Jonathan runs long data pulls manually outside Claude where that saves tokens.

**Terminology** (used throughout): **Phase** (A–E) → **Task** (1–14, a discrete work chunk) → **Session** (one literal Claude conversation; a task may span 1–3 sessions).

**Status:** rev. 3 is final — critically reviewed, all ambiguities resolved and locked in §7. The next session begins **Phase A, Task 1**, executing directly from this document (Task 1 has no separate planning session). Task 1 converts this plan into the working fhfh-style `PLAN.md`.

---

## 1. Investigation findings

### FHFH (`R:\hda\fhfh`) — methodology + scaffolding donor
Mature Quarto **book** HNA (11 of 12 planned work blocks complete). Key reusable assets:
- **PLAN.md as source of truth** (11 sections: context, architecture, R conventions, geography/vintages, dataset inventory, chapter plans, methodology specs, task blocks with Definition-of-Done + "Don't" lists, MVP guardrails, dated progress log §11).
- **One-way data flow**: `r/` scripts → `data/*.rds` → chapters `read_rds()` only; chapters never call APIs.
- **`_common.R`**: palettes, geography constants, ~18 caption helpers, `flag_reliability()` (0–100 CV, 15/30 thresholds — deliberately not `hdatools::add_reliability()`), `fct_wrap()`.
- **`r/` script template**: header comment → numbered sections → `.Renviron` fallback → `write_rds()` → **validation block** (`stopifnot()` against published benchmarks).
- **Chapter template**: setup chunk with inline scalars for prose, takeaway-sentence fig titles, ggtext color-span subtitles instead of legends, `fig-alt` everywhere, reliability suppression/footnoting, callout conventions, "narrative rule" (bullets + callouts, no drafted prose).
- **Work sequencing**: scaffold → data-only tasks → chapter tasks → assembly/QA; every session logs to §11. Model assignment per task type (Sonnet for pulls, Opus-class for methodology/chapters).
- Gotchas captured in memory (`C:\Users\JTK\.claude\projects\R--hda-fhfh\memory\project-fhfh.md`): PEP `vintage=` API change, huduser.gov User-Agent requirement, CHAS-vs-ACS cost-burden discrepancy, cross-refs-in-captions gridtext error, ggplot2 4.0 S7 `strip.text` clash, dplyr 1.2.1 `case_when()` standardization.

### rrh-framework (`R:\hda\rrh-framework`) — content predecessor
Published 2022 Quarto **book** for PHA: 4 parts, 19 chapters (Part 1 demographics ×4, Part 2 supply/market ×4, Part 3 gap analysis ×2, Part 4 locality summaries ×9). Reusable: chapter/part organization, `rr` (8-locality) / `pha` (4-locality) FIPS sets, `rrh-framework.scss` + PHA logo, dual HTML+PDF (`scrreprt`) config, GitHub Pages from `docs/`. Weaknesses to fix this time: **no `_common.R`** (geos/libraries re-declared per chapter), **no `r/` scripts** (data prep buried in `#| eval: false` chunks inside chapters). Its ggiraph interactivity is **not** carried forward — this project is static-ggplot only (decision locked below).

### FAAR (`R:\hda\faar`) — upstream template + PUMS prior art
Two directly reusable assets found here:
- **PUMS gap pipeline**: `r/pums/` (`pums_collect.R`, `pums_prep.R`, `pums_ami.R`, `pums_gap.R`, `pums_labels.R`, `gwrc_puma.R`, `naics_soc_lookup.R`) + `gaps-current.qmd`, which implements the affordable-and-available rental deficit by AMI band × bedroom count (demand vs supply join), AMI assignment to PUMS households, and cost-burden-from-PUMS charts. This is the starting point for the new PUMS work.
- **Parameterized locality fact-sheet chapters** (`local-*.qmd`): set `local_var`/`mls_var`/`costar_var` at top, rest reads shared `.rds` — the template for the 9 local summaries. (FAAR's print fact sheets were made in Canva; same route planned here.)

### Scope of work (Google Doc — contract Attachment 1; timeline ignored)
- **Deliverables**: streamlined data plan (curated, *reduced* metric list); 5 preliminary-findings web sections (Housing demand; Homeownership market; Rental market; Housing gap; Cost burden & instability); local summaries for **9 PlanRVA jurisdictions** (web pages + print fact sheets — print via Canva, adapting Quarto output); **regional progress tracker** (web page + 1-page print); full regional report (website + print PDF) with exec summary as top-level page; complete public GitHub repo. The **State of Housing presentation is already delivered** (the Jan 2026 pptx in this repo) — the only completed deliverable.
- **Analytical requirements (new vs 2022)**: change-based narrative (2022→2025/26 comparisons throughout); **theme-based section organization** (takeaway headings, not data-topic headings); expanded race/ethnicity disaggregation (cost burden via PUMS + CHAS; homeownership rate via B25003 A–I); **PUMS-based housing gap** (NLIHC-style affordable-and-available rental gap by AMI; starter-home gap = renters who could buy; minimum income for homeownership by price point/size/type vs household income profiles); full unit- and tenant-based rental assistance picture.
- **Geographies**: primary = Chesterfield, Hanover, Henrico, Richmond city (regional analysis); secondary = Charles City, Goochland, New Kent, Powhatan, Ashland (local summaries only). PUMS locality estimates only for Chesterfield/Henrico/Richmond; regional PUMS default = core-3 (locked below).
- **Technical**: standalone public GitHub repo, Quarto → GitHub Pages, extra script commentary for PHA capacity-building, processed datasets exportable for Azure/PowerBI (tidy CSVs alongside `.rds`).
- **Data vintages** (all available as of July 2026): 2020–2024 ACS 5-year tables + PUMS, CHAS 2018–2022, PEP **Vintage 2025** (confirmed on Census FTP; API availability checked at build time), Weldon Cooper 2024 projections. MLS/CoStar: **Jonathan provides fresh exports** — the CSVs/xlsx currently in `data/` are NOT canon and will be archived.

### Current repo (`R:\hda\pha-update-2026`)
Contains only the Jan 2026 SOH slide work: 3 standalone R scripts → 7 PNGs → the delivered pptx, plus now-stale data drops. All of it gets archived (scripts' logic folds into proper `r/` scripts; pptx retained as exec-summary source). Bonus: `market-rental.R` documents the **`pha_pal` brand hexes inline** (#5bab8e, #a6cccc, #f39152, #be451c, #a5add0, #2b6b9c). `R:\hda\hdatools` confirms `theme_pha()` + `scale_fill_pha()` exist.

### Files actually examined
- **fhfh** (full reads): `PLAN.md`, `CLAUDE.md`, `README.md`, `_quarto.yml`, `_common.R` (verified directly), `.gitignore`/`.renvignore`/`.Rprofile`, `r/acs_demographics.R`, `r/chas.R`, `r/hud_ami.R`, `r/affordcalc.R`, `demographics.qmd`, `gaps.qmd`, `index.qmd`, `exec-sum.qmd`, `conclusions.qmd`, `data-notes.qmd`; header lines of all 25 `r/` scripts; memory files `MEMORY.md` + `project-fhfh.md`.
- **rrh-framework**: `_quarto.yml`, `README.md`, `index.qmd`, `rrh-framework.scss`, `.gitignore`, `slides/_publish.yml`, `part-1-1.qmd` (full), `part-3-1.qmd` + `part-4-1.qmd` (partial), H1/H2 structure of all 20 `.qmd`; listings of `data/`, `lib/`, `maps/`, `widgets/`, `docs/`.
- **faar**: `local-fred.qmd` (opening), `r/` + `r/pums/` listings, `r/pums/gwrc_puma.R` + `naics_soc_lookup.R` (openings), `gaps-current.qmd` (PUMS/read_rds structure), `pdf/` listing.
- **Scope doc**: full contract + SOW + attachments via Workspace MCP.
- **pha-update-2026**: `demographics.R`, `market-rental.R`, `market-sale.R` (full), `data/mls_combined.csv` header, full listings.
- **hdatools**: `R/` listing + grep confirming `theme_pha`/`scale_fill_pha`.

---

## 2. Reuse inventory

| Component | Source | Classification | Notes |
|---|---|---|---|
| PLAN.md structure (§1–11, task blocks, progress log) | fhfh | **Adapt** | Rewrite content for PHA scope; keep skeleton, DoD/"Don't" pattern, §11 log method verbatim |
| CLAUDE.md session conventions | fhfh | **Adapt** | Swap geos/palette/run notes; keep run commands, data-flow rule, gotcha list, add token-efficiency conventions |
| `r/` → `data/*.rds` → `read_rds()` architecture | fhfh | **Reuse as-is** | Fixes rrh-framework's inline-chunk weakness |
| `_common.R` | fhfh | **Adapt** | `pha_pal` (hexes known), `rr`/`pha`/secondary/PUMA constants; keep caption-helper pattern, `cb_pal`, `fct_wrap` |
| `flag_reliability()` | fhfh | **Reuse as-is** | Secondary localities are the new small-geography problem |
| Caption helpers | fhfh | **Adapt** | Update vintages; add `pums_cap()`, `oews_cap()`, `posh_cap()`, `lihtc_cap()` |
| `r/` script template (header → `.Renviron` fallback → sections → `write_rds` → validation block) | fhfh | **Reuse as-is** | Hard checks (`stopifnot`) = structure + same-vintage published benchmarks (incl. SOH deck numbers, which are current); 2022 baselines = logged % change only, never hard-fail (see §7) |
| `acs_demographics/income/stock/costs/specialpop.R` | fhfh | **Adapt** | Geography swap; trends 2016–2024; drop fhfh's zip-code logic but **keep place-level (sumlev 160) pulls for Ashland** |
| Racial homeownership pull (B25003A–I) | — | **Net-new (small)** | Add to tenure script; identical pattern to other ACS pulls |
| `chas.R` | fhfh | **Adapt** | Same 2018–2022 vintage; sumlevel 050 ×8 + 160 Ashland; add race tables (T9) |
| `hud_ami.R` (`calc_ami()`), `fmr.R` | fhfh | **Adapt** | Richmond MSA HUD area |
| `affordcalc.R` (rent/sales/income-needed functions) | fhfh | **Reuse as-is** | Geography-independent; PHA advises assumptions |
| `gaps.R` (gap assembly, wages-vs-costs, ownership gap) | fhfh | **Adapt** | Rental gap replaced by PUMS method |
| **PUMS pipeline** (collect, prep, AMI assignment, affordable-and-available gap, labels, PUMA geography) | **faar `r/pums/` + `gaps-current.qmd`** | **Adapt** | The core new analysis has in-house prior art; extend for: starter-home gap, burden×race/ethnicity, min-income vs household profiles, Richmond PUMAs |
| `mls.R`, `costar.R` | fhfh | **Adapt** | Point at fresh exports Jonathan provides; keep CPI-adjust + splice patterns |
| `pep.R`, `decennial.R`, `wcoop.R`, `pit.R`, `nhpd.R`, `fred.R`, `bps.R` | fhfh | **Adapt** | Geography swap; PEP → Vintage 2025; PIT → Greater Richmond CoC |
| Rental assistance picture (PoSH/HCV, LIHTC, project-based) | rrh (partial, inline) | **Adapt + extend** | Consolidate into one `r/assistance.R` |
| Instability data (evictions, delinquency, PIT trend) | rrh (inline chunks) | **Adapt** | Lift into proper `r/` scripts; refresh sources |
| OEWS wage affordability | rrh (inline, 2021) | **Adapt** | Script-ify; latest OEWS release |
| Chapter `.qmd` template (setup chunk, takeaway titles, fig-alt, inline scalars, callouts, reliability treatment) | fhfh | **Adapt** | Add theme-based H2s + per-section "Since 2022" callout (replaces fhfh's interview-crosswalk callout). **Static ggplot only — no girafe/ggiraph anywhere** |
| `theme_pha()`, `scale_fill_pha()`, `add_zero_line()` | hdatools | **Reuse as-is** | Confirmed in local package source |
| `rrh-framework.scss`, PHA logo, `_quarto.yml` book config (parts, `downloads: pdf`, scrreprt) | rrh | **Adapt** | New title/repo-url; keep Noto Sans; `execute-dir: project` (fhfh) |
| Locality fact-sheet parameterized chapter | faar `local-*.qmd` | **Adapt** | Merge with rrh part-4 structure (Takeaways + 3 mirrored sections); Quarto chapters serve as **source reference** for Canva print versions |
| `pha_pal` hex definitions | pha-update-2026 `market-rental.R` | **Reuse as-is** | Lift into `_common.R` |
| 3 SOH R scripts | pha-update-2026 | **Adapt** | Fold logic into `r/` scripts, then archive originals |
| Existing `data/` files (MLS/CoStar/HU xlsx+csv) | pha-update-2026 | **Archive** | NOT canon — fresh exports to be provided |
| SOH pptx | pha-update-2026 | **Archive (keep)** | Delivered; exec-summary source material |
| Task workflow (data-first → chapters → assembly) + memory practice | fhfh | **Reuse as-is** | The proven process |
| 2022-baseline benchmark file | — | **Net-new** | Transcribed from the **local** rendered site (`R:\hda\rrh-framework\docs\`), not live-site fetches; feeds change-based narrative + logged variance checks |
| Regional progress tracker | — | **Net-new** | No prior art; needs PHA metric/target input |
| Streamlined data plan (client doc) | — | **Net-new** | Generated from PLAN.md §5 inventory; exported to Google Doc |
| Azure/PowerBI CSV exports | — | **Net-new (trivial)** | Export helper writes `data-out/` CSV alongside every `write_rds()`; public-source CSVs committed, MLS/CoStar-derived gitignored (see §4) |

---

## 3. Scope → components map

| Scope requirement | Status | How |
|---|---|---|
| Streamlined data plan | **Adapt** | PLAN.md §5 dataset inventory = same artifact; curate down from rrh's sprawl; export to Google Doc |
| Housing demand section | **Covered** | `acs_demographics/income/specialpop` + `pep` + `decennial` + `wcoop` + rrh part-1 content map |
| Homeownership market section | **Mostly covered** | `mls` + `bps` + HU estimates + fhfh chapter pattern; **gap:** B25003A–I racial homeownership (small) |
| Rental market section | **Mostly covered** | `costar` + `nhpd` + fhfh pattern; **gap:** consolidated assistance picture (PoSH + LIHTC + HCV) |
| Housing gap section | **Adapt (faar)** | faar PUMS pipeline + `affordcalc` + `hud_ami`; **extend:** starter-home gap, min-income-by-price-segment vs household profiles |
| Cost burden & instability section | **Partially covered** | ACS burden trend + CHAS patterns (fhfh) + faar PUMS burden charts; **extend:** burden×race/ethnicity×income; refresh evictions/delinquency (rrh logic exists inline) |
| Change-based narrative (vs 2022) | **New convention** | `baseline_2022` data + per-section "Since 2022" callout in chapter template |
| Theme-based organization | **New convention** | Takeaway-sentence H2s in chapter template; costs nothing once templated |
| 9 local summaries (web; print via Canva) | **Adapt** | faar `local-*.qmd` parameterization × rrh part-4 structure; Quarto = source reference for Canva |
| Regional progress tracker | **Gap** | Net-new page; blocked on PHA collaboration for metrics/targets (not blocking prelim draft) |
| Full report website + PDF | **Covered** | Quarto book, `downloads: pdf`, rrh scrreprt config, Pages from `docs/` (public repo) |
| Exec summary (top-level page + deck update) | **Covered** | Derive from delivered SOH pptx; fhfh `exec-sum.qmd` pattern |
| SOH presentation | **DONE** | Delivered Jan 2026; archive |
| PUMS geographies | **Locked** | Core-3 default; both PUMA sets encoded in `_common.R` |
| Script commentary for PHA training | **Covered** | fhfh template already heavily commented; data-notes appendix doubles as documentation |
| Azure/PowerBI-ready data | **Trivial** | `data-out/` CSV export helper |

---

## 4. Repo strategy

Build in **`R:\hda\pha-update-2026`**:

1. **Archive everything currently here** → `archive/soh-2026/`: the 3 R scripts, `img/`, the pptx, **and all current `data/` files** (stale — fresh MLS/CoStar exports to be provided by Jonathan; Census data pulled fresh via API/scripts).
2. **Initialize**: `git init`; **public** GitHub repo `hdadvisors/pha-update-2026`; `.gitignore` from fhfh (commit `r/`, `docs/`, `_freeze/`, and **public-source `data-out/` CSVs**; gitignore `data/` with small-raw-drop exceptions and **all MLS/CoStar-derived `data-out/` files** — those are delivered to PHA privately via Drive/Azure); renv; `.Rprofile`.
3. **Quarto book** (not website): matches both predecessors; parts + combined PDF + `downloads: pdf`; output to `docs/` for GitHub Pages, **live from the start with a `noindex` robots meta tag** (via `_quarto.yml`) until the report is final — removed in Task 14; **Hypothesis commenting enabled** (`comments: hypothesis`) for preliminary review — PHA reviewers annotate in a **private Hypothesis group** (annotations are public by default).

---

## 5. Proposed scaffolding

Two skills, no hooks, no chart helper beyond what hdatools already provides. **Both skills designed as *universal* (user-level, reusable in future HDA report projects)** — they read project specifics from the local `PLAN.md`/`_common.R` rather than hardcoding them:

1. **`/new-data-script`** (user-level skill): generates an `r/` script from the fhfh template — header block, `.Renviron` fallback, geo constants sourced from the project's `_common.R`, numbered sections, `write_rds()` + paired `data-out/` CSV export, validation block wired to the project's benchmark file. Encodes the cross-project gotcha list (PEP `vintage=`, huduser UA, CHAS dictionary, tidycensus patterns) so it never has to be re-derived in context. *Earns its place:* ~18–20 scripts here alone, plus every future HNA/data-update.
2. **`/new-chapter`** (user-level skill): scaffolds a `.qmd` — purpose comment, setup chunk (`source("_common.R")`, `read_rds()` stubs, inline-scalar block), theme-based H2 stubs, change-vs-baseline callout, closing summary callout, and full **static-chart conventions as commented exemplar chunks** (takeaway title, ggtext span subtitle, caption helper, fig-alt, reliability treatment, `theme_pha`/`theme_hda` per project). *Earns its place:* 15 instantiations here (5 chapters + 9 local summaries + tracker), plus future projects.

Universal-skill design notes (both): parameterize on a small project-config block (palette name, theme function, geography constants file, benchmark file path); default to conventions when config absent; keep exemplars in the skill's reference files, not the prompt, to minimize token load.

**Deliberately not proposed:** hooks (fhfh ran the whole build cleanly with none; render checks live in each task's DoD); a girafe/chart-styling helper (project is static-only; hdatools + exemplar chunks suffice); a fact-sheet generator (the faar parameterized template *is* the generator).

**Custom agents — door open, not pre-committed:** if a task plan identifies strategic value, custom subagents (`.claude/agents/`) may be created and deployed. Most plausible candidates: a low-cost *validation-runner* agent (executes `Rscript` checks and reports only pass/fail + variances, keeping raw output out of the main context) and a *number-sweep QA* agent for Phase E (cross-checks rendered figures against `baseline_2022` and PLAN.md benchmarks). Each will be proposed in the relevant task plan only if it earns its tokens.

---

## 6. Phased execution plan

Hierarchy: **Phase → Task → Session(s)**. Data tasks produce only scripts + `.rds`; chapter tasks only consume. Every session ends with a §11 log entry. **Reviewable preliminary draft lands at end of Phase C.**

**Per-task planning workflow (fhfh ad hoc practice, now formalized):** every Task begins with a discrete **plan-mode session (Opus)** that produces a task-specific plan md in `plans/` (format reference: `R:\hda\fhfh\plans\`) and does **no other work**. Each task plan must at minimum:
1. Outline the specific work session(s) to execute the task.
2. Draft starter prompts for those sessions using the **prompt-helper** skill.
3. Recommend model choice and settings per work session.
4. Reference project docs — especially the recent §11 log of issues/deviations — so work sessions start with current context.

(Session counts in the tasks below are **work sessions**; each task adds its one planning session on top. **Phase A exception:** Task 1 executes directly from this EXECUTION-PLAN — no separate planning session; Task 2 *does* get one (skill design + baseline-file format have real open design questions). The rule applies in full from Task 3 onward.)

**Token-efficiency conventions (all phases):**
- One task focus per session; start each session reading only CLAUDE.md + the relevant PLAN.md task block + the task plan (not whole files).
- Model by session type: **Sonnet** for mechanical data pulls, geography swaps, and QA sweeps; **Opus** for task planning, PUMS methodology, gap analysis, and chapter builds. **Fable only for meta-level investigations or critical assessments outside this execution plan** — never for core output sessions.
- **Jonathan runs long jobs manually**: Claude writes the script; Jonathan executes big pulls (PUMS downloads, CHAS zips, tigris geometries, full renders) outside Claude and pastes back errors/validation output. Claude never babysits long Rscript runs.
- Manual data drops (MLS, CoStar, and similar exports) provided by Jonathan directly into `data/raw/`.
- Skills carry the boilerplate so it's never regenerated from scratch in context.

### Phase A — Setup
- **Task 1 — Scaffold** (1–2 sessions; no planning session — this doc is its plan): **Session 1** = archive per §4; git init + public repo; Quarto book skeleton (index + 5 chapter stubs + data-notes appendix) renders clean with noindex meta; `_common.R` (pha_pal, cb_pal, `rr`/`pha`/secondary/Ashland/PUMA constants, caption helpers, `flag_reliability()`, CSV-export helper); `_quarto.yml` (rrh config + Hypothesis comments + fhfh execute settings); scss + logo; `data/raw/README.md` = **MLS/CoStar export spec** (fields, date ranges, geographies, format — derived from fhfh `mls.R`/`costar.R` input expectations + 2022 report coverage) so Jonathan can pull exports any time before Task 4. **Session 2** (split here if session 1 runs long; otherwise same session) = **PLAN.md drafted in full** (incl. §5 dataset inventory = streamlined-data-plan content, §9 task blocks, and its own first §11 log entry covering Task 1); CLAUDE.md; README (incl. plain-language renv quick guide for teammates); renv.
- **Task 2 — Skills + baselines** (1 session + planning session): build the two universal skills; `baseline_2022.rds` transcribed from the **local** rendered rrh-framework site (`R:\hda\rrh-framework\docs\`); streamlined data plan exported to Google Doc for PHA. **Phase B does not wait for PHA sign-off** — their feedback trims/adds at the margins later.
- *Phase deliverable:* rendered empty book on Pages (noindexed); PLAN.md + data plan ready for review.

### Phase B — Data collection (scripts + validation only, no figures)
- **Task 3 — Demand data** (1–2 sessions, Sonnet-tier): `acs_demographics`, `acs_income`, `pep` (Vintage 2025; FTP fallback if API lags), `decennial`, `wcoop`, household characteristics.
- **Task 4 — Market data** (1–2 sessions, Sonnet-tier): `mls` + `costar` (fresh exports), `bps`, HU estimates, tenure + B25003A–I, `nhpd`, `assistance.R` (PoSH/HCV/LIHTC), `fmr`, `fred`.
- **Task 5 — PUMS engine** (2–3 sessions, Opus-tier; hardest task — its planning session may recommend a one-off Fable escalation for the gap-methodology design only if Opus stalls): port faar `r/pums/` pipeline to Richmond PUMAs (core-3 + oversampled sets); rental gap by AMI (affordable-and-available); extend to starter-home gap renter profiling, burden×race/ethnicity×income, income distributions for min-income comparisons; `hud_ami` + `affordcalc` ports.
- **Task 6 — Burden & instability data** (1–2 sessions): ACS burden trend, CHAS (incl. race tables), OEWS wages, evictions, delinquency, PIT (Greater Richmond CoC), min-income-by-price-segment assembly.
- *Per-task DoD:* scripts run clean via `Rscript` (run by Jonathan where long), `.rds` + `data-out/` CSVs written; **hard validation** (`stopifnot`) passes on structure + same-vintage published benchmarks; **2022-baseline comparison** logged as % change in §11 (implausible swings flagged for review, never hard-failed — vintages differ by construction).

### Phase C — Regional chapters (report order; Opus-tier)
- **Task 7 — Housing demand** · **Task 8 — Homeownership market** · **Task 9 — Rental market** · **Task 10 — Housing gap** · **Task 11 — Cost burden & instability** (each ~1 session).
- Each chapter: theme-based takeaway H2s, **static ggplot** figures (`theme_pha`), 2–5 bullets/section with inline-R stats, "Since 2022" callouts, reliability treatment on secondary-locality figures, fig-alt throughout. Narrative rule: bullets + callouts, no drafted prose.
- *Phase deliverable:* **full preliminary draft** — rendered book with all 5 sections, Hypothesis-commentable, shareable with PHA. This is the milestone the sequence optimizes for.

### Phase D — Local summaries + tracker
- **Task 12 — Local summaries** (2 sessions): parameterized template (faar × rrh part-4); session 1 = template + 4 primary localities; session 2 = 5 secondary localities. Quarto pages = source reference for later Canva print versions.
- **Task 13 — Progress tracker** (1 session): draft page with candidate metrics from existing `.rds`; targets flagged for PHA collaboration.

### Phase E — Assembly & QA
- **Task 14 — Assembly** (1–2 sessions): exec summary (from SOH deck) as top-level page; index/About; data-notes appendix (doubles as PHA training documentation); full render (Jonathan-run); number sweep against baselines; reliability/alt-text pass; PDF render; `data-out/` export sweep (verify MLS/CoStar-derived files stayed out of the repo); **remove the noindex meta tag**; repo docs finalized.

---

## 7. Decisions locked (from plan review)

- **Static ggplot only** — no girafe/ggiraph anywhere.
- **Hypothesis commenting** for preliminary review pages.
- **PUMS regional default = core-3** (Chesterfield/Henrico/Richmond); both PUMA sets encoded.
- **2022 baselines transcribed** from the published rrh-framework site (not recomputed).
- **Print fact sheets in Canva** (as FAAR was); Quarto locality chapters are source reference only.
- **SOH presentation delivered** — archive the pptx; it seeds the exec summary.
- **Public repo from the start.**
- **PEP Vintage 2025** — available on Census FTP; check API at build time, fall back to FTP tables.
- **Skills are universal/user-level**, parameterized per project.
- **Fresh manual data from Jonathan** for MLS/CoStar; existing `data/` files archived, not used.
- **Every Task opens with an Opus plan-mode session** producing a task plan in `plans/` (session outline + prompt-helper starter prompts + model recommendations + doc/log references); no other work in that session. **Phase A exception: Task 1 has no planning session (this document is its plan); Task 2 does.**
- **Model policy**: Sonnet/Opus for all core output; **Fable reserved for meta-level investigations/critical assessments only**. Sole sanctioned exception: Task 5's plan may recommend Fable for the gap-methodology design session if Opus stalls.
- **Task 1 is 1–2 sessions**, splitting after the skeleton renders clean (scaffold first; PLAN.md/CLAUDE.md/README second) if context runs long.
- **Pages live from the start with a noindex meta tag** until the report is final (removed in Task 14); PHA reviewers use a **private Hypothesis group**.
- **Phase B is not gated on PHA data-plan sign-off** — data collection starts immediately after Task 2; PHA feedback adjusts at the margins.
- **Validation semantics**: `stopifnot()` only on structure + same-vintage published benchmarks (SOH deck numbers count — they're current); 2022 baselines produce logged % changes in §11, flagged if implausible, never hard-failed.
- **`data-out/` commit policy**: public-source CSVs committed to the public repo; MLS/CoStar-derived CSVs gitignored and delivered to PHA privately (Drive/Azure).
- **MLS/CoStar export spec written in Task 1** (`data/raw/README.md`), so exports can be pulled any time before Task 4.
- **`baseline_2022.rds` transcribed from the local rendered site** (`R:\hda\rrh-framework\docs\`), not live-site fetches.
- **Ashland keeps place-level (sumlev 160) handling** in ACS scripts; only fhfh's zip-code logic is dropped.
- **renv: yes** — including a for-dummies renv quick guide in the README for teammates (restore/snapshot in plain terms, what to do when a package error appears).
- **LODES/commuting dropped entirely.**
- **OEWS only** for wage analysis; QCEW omitted for the time being.

*No open decisions remain — ready to execute Task 1 on approval.*
