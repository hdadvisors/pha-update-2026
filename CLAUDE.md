# CLAUDE.md — Richmond Regional Housing Framework 2026 Data Update

Conventions for all Claude sessions on this project. **This is a report repo** under the HDA four-type taxonomy, which settles the commit vocabulary below. **`.planning/PLAN.md` is the source of truth** — this file is the quick reference for running a session.

## Start-of-session checklist

1. Read this file, then `.planning/PLAN.md` Sections 1 through 4, then only the phase file for the phase being run, then the top entry of `.planning/LOG.md`.
2. Read only the Section 5 through 8 rows that your phase touches. Do not read the reference repos unless a task sends you there.
3. Verify that the prerequisite raw files exist under `data/raw/`. If any are missing, do the work that does not need them and record the blocker in the log entry.

A phase whose row in the Section 9 table reads `not planned` cannot be executed. Plan it first, in a planning-only session whose sole output is the phase file. That session must not run in Claude Code plan mode, because plan mode confines edits to a scratch file outside the repo and cannot write the phase file the session exists to produce.

## End-of-session checklist

1. Tick the `Verify` lines that passed.
2. Write the `.planning/LOG.md` entry and overwrite the kickoff-prompt block for the next session.
3. Update README.md or this file if a convention changed — same session, not a follow-up.
4. Commit the work and the log entry together — `hda-git:commit`.
5. Update the Issue last, so its comment can cite the SHA — `hda-git:pr`.

Steps 1 and 2 are automated by `hda-docs:wrap`. Steps 3 through 5 are run by the session itself after wrap returns.

Every log entry records deviations from the phase file, data surprises, the 2022 percentage changes, and what was left open.

## Commit conventions

`hda-git:commit` owns the full grammar, the staging rules, and the branch-or-main decision. What is specific to this repo:

| Setting | Value |
|---|---|
| Repo type | Report |
| Commit types | `fix`, `docs`, `chore`, `data`, `content`, `infra`, `plan` |
| Scope | `task-N`, or `task-N-sN` for a session within a multi-session task. Optional on `docs`, `chore`, and `plan` commits outside the task cadence |
| Versioned | No. Git history plus `.planning/LOG.md` is the release record |

Tasks are numbered 1 through 14 inside the phase files, carrying forward the numbering used in existing commits. A `plan` commit changes a planning artifact: a `.planning/phases/` file, or a PLAN.md scope or methodology amendment.

## Token efficiency and model policy

- **One phase focus per session.** Start narrow, per the checklist above. Do not read whole files when a block will do.
- **Model by session type.** Sonnet for mechanical data pulls, geography swaps, and QA sweeps. Opus for phase planning, PUMS methodology, gap analysis, and chapter builds. Fable for meta-level investigation and critique only, never for core output, with one sanctioned exception: the Phase 4 gap-methodology design if Opus stalls.
- **Jonathan runs long jobs** — PUMS, CHAS, and tigris pulls, and any full render over roughly two minutes. Claude writes the script; Jonathan runs it and pastes back errors and validation output. Never babysit a long `Rscript` run.
- **Manual data drops** for MLS and CoStar go straight into `data/raw/`. Jonathan provides them.
- **Skills carry the boilerplate.** Invoke `/new-data-script` before writing a new `r/*.R` pull or prep script, and `/new-chapter` before a new section `.qmd`. Never regenerate the anatomy from scratch in context. Both live in-repo at `.claude/skills/`. Each reads a project-config block from this file, PLAN.md, and `_common.R` at invocation and emits a pha-shaped scaffold; full exemplars and a conventions digest are in each skill's `references/`. They stay project-level until phases 2 through 6 exercise them, at which point promote them to the `hda-claude` marketplace with any evidence-based revisions.

## Data flow rule

`r/` scripts write `data/*.rds` and, through `export_csv()`, `data-out/*.csv`. Chapters call `read_rds()` only. **Chapters never call APIs.**

## Code style and script anatomy

Script anatomy: a header comment stating what, source, and output → numbered `## 1. Setup ----` sections → an `.Renviron` fallback for keys → `write_rds()` paired with `export_csv()` → a validation block. Scripts are idempotent and safe to re-run. No inline `install.packages()`.

- Native pipe `|>`, tidyverse style, `janitor::clean_names()` on all imported raw data.
- dplyr 1.2 idioms: `.by=` over `group_by()` for one-off grouping; `across()`; `join_by()`; `reframe()` for multi-row summaries. Use `recode_values()` for value-to-label recodes — the pinned dplyr is 1.2.1 and `case_match()` is soft-deprecated. Reserve `case_when()` for genuine conditional logic.
- `purrr::map()` and `imap()` over `for` loops, bound with `list_rbind()` or `list_cbind()`. The pinned purrr is 1.2.2, in which `map_dfr()` and `map_dfc()` are superseded. Pattern: `map(years, \(yr) get_acs(..., year = yr) |> mutate(year = yr)) |> list_rbind()`.
- tidycensus: `get_acs(geography, state = "VA", table = "BXXXXX", year, survey = "acs5", cache_table = TRUE)`. Pull whole tables and build label lookups from `load_variables()` with `separate_wider_delim(label, "!!")`.

## Validation semantics

- `stopifnot()` fires only on structural expectations (row counts, all geographies present, no all-NA columns) and on **same-vintage** published benchmarks — a HUD-published MFI, a Census-published table total, or the State of Housing deck numbers, which are current as of January 2026.
- 2022 baselines are compared as a **logged percentage change in the session's log entry**, never as a `stopifnot()` gate. Implausible swings are flagged for human review; they never fail a build, because 2020-2024 ACS and 2016-2020 ACS differ by construction.
- Every data phase logs its benchmark results, both passes and variances.

## What `_common.R` provides

- **Palettes:** `pha_pal`, the 6 brand hexes, and `cb_pal` for cost-burden fills.
- **Geography:** `rr` (8), `pha` (4 primary), `secondary` (4), `ashland` (place 5103368, sumlev 160), `virginia`; and the PUMS sets `puma_core3`, `puma_region`, `puma_locality`.
- **Regional chapter geography rule:** Regional findings chapters (`demand.qmd`, `ownership.qmd`, `rental.qmd`, `gaps.qmd`, `burden.qmd`) filter all chart data and inline scalars with `pha` (or `c(pha, "51")` when Virginia appears as a reference). Use `rr` only in `r/` data-collection scripts and in `index.qmd` / `data-notes.qmd` scope statements. Secondary localities are never plotted or named as findings in regional chapters.
- **Caption helpers:** `acs_cap`, `pums_cap`, `chas_cap`, `dec_cap`, `pep_cap`, `wc_cap`, `bps_cap`, `mls_cap`, `costar_cap`, `fmr_cap`, `ami_cap`, `nhpd_cap`, `posh_cap`, `lihtc_cap`, `oews_cap`, `pit_cap`, `eviction_cap`, `vdoe_cap`, `cpi_cap`, `pmms_cap`.
- **`flag_reliability(df, cv_col = cv)`** — High at or below 15, Medium at or below 30, Low above 30, from a **0 to 100** CV. Use it for secondary-locality and Ashland ACS estimates. Do not use `hdatools::add_reliability()`, which assumes a 0 to 1 scale and mislabels small cells as Low.
- **`export_csv(df, name)`** — writes `data-out/<name>.csv`. **Naming is commit policy:** name public-source exports plainly, and prefix MLS and CoStar derivatives `mls_` or `costar_` so `.gitignore` keeps them private.
- **`fct_wrap(f, width)`** — applies `str_wrap()` to a factor's levels.

## Chart and table conventions

- `theme_pha()` with `pha_pal`, plus `add_zero_line()`.
- Titles are takeaway sentences. The subtitle carries geography, units, and years. Captions come from a `_common.R` source helper.
- For 2 or 3 series, prefer color-coded bold words in the subtitle, as ggtext spans using `pha_pal` hexes, over a legend.
- Currency uses `scales::label_dollar()`, and the subtitle notes whether a series is nominal or inflation-adjusted. Percentages use `label_percent(accuracy = 1)` unless precision matters.
- Tables use `kbl() |> kable_styling(c("condensed","striped"))` with `formattable::comma` and `percent`.
- Secondary-locality and Ashland ACS estimates always carry reliability treatment through `flag_reliability()`. Suppress cells with a CV above 30 and footnote the Medium cells.
- Every figure gets `#| fig-alt:` alt text.

## Narrative rule

Chapters ship with takeaway H2s, 2 to 5 bullet findings per section (plain statements traceable to a figure or table), and callout boxes for the "Since 2022" change and for data caveats. **No drafted paragraphs.** The bullets must be specific enough that a human expands them into prose without reopening the data.

## Execution on Windows

**Never run R inline.** Write `r/<name>.R` and run `Rscript r/<name>.R` from the project root. Ad hoc checks go in a temp script in the scratchpad, run through `Rscript`, never in the repo.

R and Quarto are usually not on PATH. See the quick start in [README.md](README.md) for the prepend and the render commands; the install paths are machine-specific and are documented there and nowhere else.

Use forward slashes in R paths, and keep every path relative to the project root.

## API keys

`CENSUS_API_KEY`, `FRED_API_KEY`, and `GEOCODIO_API_KEY` are all required (the last for MLS geocoding, `r/mls_geocode.R`). They live in your user `.Renviron` at `%USERPROFILE%\Documents\.Renviron`. Never print or commit their values.

R's HOME on Windows may be `C:\Users\<you>` rather than the Documents folder, so that file is not always loaded automatically. Scripts include an `.Renviron` fallback derived from the current user — `readRenviron(file.path(Sys.getenv("USERPROFILE"), "Documents", ".Renviron"))` when the key is empty — never a hardcoded username. Verify visibility with a TRUE or FALSE check only.

## Data-fetch rule

tidycensus, tigris, and fredr package downloads are approved. Direct fetches from census.gov file servers (BPS, the PEP FTP) and from huduser.gov (CHAS zips, Income Limits) are approved with a manual fallback. Geocodio via `tidygeocoder` (`r/mls_geocode.R`) is approved for MLS address geocoding only. Anything else on a government host, especially BLS OEWS, requires Jonathan's approval or a manual download.

## Publishing status

Public repo, with GitHub Pages live from the start on `main`/`docs` at `https://hdadvisors.github.io/pha-update-2026/`, carrying a **noindex** robots meta tag set in `_quarto.yml` until the report is final. Phase 7 removes it. PHA reviewers comment through a **private** Hypothesis group, because Hypothesis annotations are public by default.

## Known gotchas

- **PEP** — the post-2020 API requires an explicit `vintage=` argument; `year=` alone misbehaves silently. Use Vintage 2025 and fall back to the FTP tables if the API lags.
- **huduser.gov** — send a browser User-Agent and Referer or the server returns 202 or an empty body. The CHAS data dictionary is a separate download from the table zips.
- **gridtext and `theme_pha`** — an `@fig`, `@tbl`, or `@sec` cross-reference inside `labs(caption=)` or a kbl `footnote()` throws a gridtext `<a>`-tag error. Keep cross-references in markdown bullets.
- **ggplot2 4.0 (S7)** — override strip text with `ggtext::element_markdown()`, never a raw `element_text()`. `theme_pha`'s strip element is a ggtext markdown element and ggplot2 4.0 only merges theme elements of the same class, so an `element_text()` override is the thing that clashes. Faceting is fine; the override just has to match the class. Documented at `hdatools/R/themes.R`, `theme_pha`'s `@details`.
- **`dplyr::join_by(a == b)` on differently-named columns** — the joined result keeps only `a`, silently dropping `b`. A downstream `mutate()` or `select()` that expects `b` to survive gets a column-not-found error, or worse, an `NA` after a `bind_rows()` masks the missing column with a same-named one from another frame. Join on the equal-named keys only and enforce the cross-name equality with a `filter()` immediately after, so both columns survive. Found while building `r/mls_clean.R`'s cross-MLS price-tolerance match.

## Repo map

See `.planning/PLAN.md` Section 2 for the annotated tree.
