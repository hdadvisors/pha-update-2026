# CLAUDE.md — Richmond Regional Housing Framework 2026 Data Update

Conventions for all Claude sessions on this project. **PLAN.md is the full source of truth** —
this file is the quick-reference for running a session.

## Start-of-session checklist

1. Read this file + your **PLAN.md §9 task block** + the task's plan in `plans/` + the recent **PLAN.md §11 log**.
2. Read only the §5–8 rows your task touches. **Don't** re-read `EXECUTION-PLAN.md` or the reference repos unless a task says to.
3. Verify prerequisite raw files exist (`data/raw/…`). If missing, do what doesn't need them and list blockers in §11.

## End-of-session checklist

1. Tick your §9 checkboxes; add a dated §11 log entry (deviations, data surprises, **2022 % changes**, open questions).
2. Update README.md / this file if a convention changed (docs are first-class — same session).
3. Commit per the **Commit style guide** below. **No Claude/Anthropic co-author or contributor lines.**

## Commit style guide

Canonical for this project — PLAN.md §3 (Session hygiene) points here rather than restating.

**Format:** `type(scope): subject`

### Types

| Type | Use for |
|---|---|
| `data` | New/changed data-collection or prep scripts (`r/`), new data outputs, validation-block changes |
| `content` | New or edited book content — chapters, local summaries, tracker, exec summary |
| `infra` | Shared plumbing: `_common.R`, `_quarto.yml`, renv/build config, skills boilerplate |
| `fix` | Correcting a bug or wrong output in existing data or content work |
| `docs` | README/CLAUDE.md/PLAN.md meta-doc edits, setup guides |
| `chore` | Repo housekeeping with no data/content change: `.gitignore`, lockfile bump, file moves |
| `plan` | Planning artifacts: `plans/` task plans, PLAN.md scope/methodology amendments |

Add or drop types if the project's layers shift — don't pad for symmetry.

### Scope

`task-N` for a numbered task (PLAN.md §9); `task-N-sN` for a specific session within a
multi-session task (matches the "Session 1"/"Session 2" language used in §11 log entries), e.g.
`task-1-s2`. Optional on `docs`/`chore`/`plan` commits outside the task cadence.

### Choosing the type on mixed commits

Tag by the dominant/point-of-the-commit type; disclose the rest in the body. Don't split a
commit to keep types pure — an ad hoc fix mid-task folds into that task's commit (including its
§11 log update), rather than becoming a dangling unlabeled commit.

### Subject line

Imperative mood (`Add`, not `Added`/`Adding`); no trailing period; ≤50 chars if possible, hard
cap ~72. States the *what* — the body carries the *why*.

### Body

Blank line between subject and body — always. Bullet list of specifics: what changed, key
validated numbers (incl. **2022 % changes**), files/modules touched. `fix` commits state what was
wrong and how it was confirmed fixed. Explain *why*, not *what*, for anything non-obvious. Omit
the body entirely for trivial, self-explanatory commits.

### Non-negotiables

- No bare, unlabeled commits ("misc changes", "updates") — every commit gets a type, even `chore`.
- **No Claude/Anthropic co-author or contributor lines, ever** (project + global convention).
- Ad hoc fixes made mid-task fold into that task's commit, not left dangling.
- One task-part per commit; don't bundle unrelated tasks together.

### Examples

```
data(task-3): pull ACS demographics + PEP components

- age/pop/race/HH-type tables via tidycensus; PEP vintage 2025 (FTP fallback tested)
- validated pop totals against SOH deck; 2022 baseline +3.1% pop (logged, plausible)

content(task-8): homeownership market chapter

- sales volume, price trend, racial homeownership (B25003A-I) figures
- "Since 2022" callout; reliability flags on secondary/Ashland figures

docs: cross-reference commit style guide from PLAN.md

chore: bump renv lockfile after hdatools 0.1.8
```

## Token-efficiency rules (EXECUTION-PLAN §6 — this project's second goal)

- **One task focus per session.** Start narrow (checklist above); don't read whole files when a block will do.
- **Model by session type:** **Sonnet** for mechanical data pulls, geography swaps, QA sweeps; **Opus** for task planning, PUMS methodology, gap analysis, chapter builds. **Fable only for meta-level investigation/critique** — never core output (sole exception: Task 5 gap-methodology design if Opus stalls).
- **Jonathan runs long jobs** (PUMS/CHAS/tigris pulls, full renders > ~2 min). Claude writes the script; Jonathan runs it and pastes back errors/validation. **Never babysit a long `Rscript` run.**
- **Manual data drops** (MLS, CoStar) go straight into `data/raw/` — Jonathan provides them.
- **Skills carry the boilerplate** — invoke `/new-data-script` before writing a new `r/*.R` pull/prep script and `/new-chapter` before a new section `.qmd`; never regenerate the anatomy from scratch in context. They live in-repo at `.claude/skills/{new-data-script,new-chapter}/` (built Task 2). Each reads a **project-config block** from this file + PLAN.md + `_common.R` at invocation and emits a pha-shaped scaffold; full exemplars + a conventions digest are in each skill's `references/`. **Project-level for now**; elevate to user-level (`~/.claude/skills/`) once proven on Tasks 3–11.

## Quick start (run commands)

R is **not** on PATH. Prepend it first (bash):

```bash
export PATH="/c/R/R-4.6.0/bin:$PATH"
```

**Render the book:** `quarto render`  (one section: `quarto render demand.qmd`)
**Run a script:** `Rscript r/<name>.R`  (from project root; `.Rprofile` activates renv)
**Restore the env (first time after cloning):** `renv::restore()`

**R 4.6.0** (at `C:\R\R-4.6.0`) is the render target — renv.lock is pinned to it and the renv
library is built for R-4.6, so the packages only load under 4.6.x. (Program Files also has
4.4.2 / 4.4.3 / 4.5.0 / 4.5.1, but those won't see the renv library.)

## Data flow rule

`r/` scripts → `data/*.rds` (+ `export_csv()` → `data-out/*.csv`) → chapters `read_rds()` only.
**Chapters never call APIs.**

## Script anatomy (PLAN.md §3)

Header comment (what/source/output) → `## 1. Setup ----` numbered sections → `.Renviron` fallback
for keys → `write_rds()` + `export_csv()` → **validation block**. Idempotent; no inline
`install.packages()`. Native pipe `|>`; `janitor::clean_names()` on raw data; dplyr ≥ 1.2 idioms;
`case_when()` (not `case_match()`); `map_dfr()` over loops.

## Validation semantics (locked — PLAN.md §3)

- `stopifnot()` **only** on structure + **same-vintage** benchmarks (incl. the **SOH deck** numbers — current).
- **2022 baselines** → logged **% change in §11**, flagged if implausible, **never hard-failed** (vintages differ).

## `_common.R` provides

- **Palettes:** `pha_pal` (6 brand hexes), `cb_pal` (cost-burden fill).
- **Geography:** `rr`(8), `pha`(4 primary), `secondary`(4), `ashland` (place 5103368, sumlev 160), `virginia`; PUMS `puma_core3`, `puma_region`, `puma_locality`.
- **Caption helpers:** `acs_cap`, `pums_cap`, `chas_cap`, `dec_cap`, `pep_cap`, `wc_cap`, `bps_cap`, `mls_cap`, `costar_cap`, `fmr_cap`, `ami_cap`, `nhpd_cap`, `posh_cap`, `lihtc_cap`, `oews_cap`, `pit_cap`, `cpi_cap`, `pmms_cap`.
- **`flag_reliability(df, cv_col = cv)`** — High ≤15 / Medium ≤30 / Low >30 from a **0–100** CV. Use for secondary-locality + Ashland ACS. **Not** `hdatools::add_reliability()` (0–1 scale; mislabels small cells "Low").
- **`export_csv(df, name)`** — writes `data-out/<name>.csv`. **Naming = commit policy:** name public-source exports plainly; prefix MLS/CoStar-derived ones `mls_`/`costar_` so `.gitignore` keeps them private.
- **`fct_wrap(f, width)`** — `str_wrap()` a factor's levels.

## Chart & table conventions (PLAN.md §3)

`theme_pha()` + `pha_pal`; `add_zero_line()`. **Takeaway-sentence titles**; ggtext color-span
subtitles over legends for 2–3 series; `label_dollar()`/`label_percent()`; `kbl() |> kable_styling()`.
Reliability treatment on secondary/Ashland figures. `#| fig-alt:` on every figure.

## Known gotchas (expect these — PLAN.md §3)

- **PEP:** API needs explicit `vintage=` (use 2025); FTP fallback.
- **huduser.gov:** send a browser User-Agent + Referer or get 202/empty. **CHAS dictionary** is a separate download.
- **No `@fig`/`@tbl`/`@sec` cross-refs inside `labs(caption=)` or kbl `footnote()`** — gridtext `<a>`-tag error. Keep cross-refs in markdown bullets.
- **ggplot2 4.0 (S7):** avoid raw `strip.text = element_text()` overrides with `theme_pha` (class clash) — de-facet if needed.

## API keys

`CENSUS_API_KEY` / `FRED_API_KEY` live in `C:\Users\JTK\Documents\.Renviron`. Never print or commit.
**HOME gotcha:** R's HOME may be `C:\Users\JTK`, so that file isn't auto-loaded — scripts include an
`.Renviron` fallback. Verify visibility with a TRUE/FALSE check only.

## Publishing status

Public repo; **GitHub Pages live from the start** (`main`/`docs`) at
`https://hdadvisors.github.io/pha-update-2026/`, with a **noindex** robots meta tag (in `_quarto.yml`)
until the report is final — **removed in Task 14**. PHA reviewers comment via a **private Hypothesis
group** (Hypothesis annotations are public by default).

## Windows R rule

**Never run R inline.** Write a temp script, run via `Rscript` from project root. Temp/ad-hoc scripts
(renv setup, key checks, one-off queries) go in the **scratchpad**, not the repo.

## Repo map

See PLAN.md §2. Key: `r/` (committed pipeline, incl. `r/pums/`), `data/` (gitignored except
`data/raw/README.md`), `data-out/` (public CSVs committed), `docs/` (committed site), `_freeze/`
(committed), `plans/` (per-task plans), `archive/soh-2026/` (retained SOH deliverables),
`.claude/skills/` (committed; the two scaffolding skills — see below).
