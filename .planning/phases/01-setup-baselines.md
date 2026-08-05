# Phase 1: Setup and baselines

This phase is complete. It is recorded here as the migrated form of the original Task 1 checklist in the retired PLAN.md Section 9 and the Task 2 plan at `plans/task-2-skills-baselines.md`, produced in the Task 2 plan-mode session on 2026-07-15. The container follows the `hda-docs` phase-file skeleton adopted on 2026-08-05; the recorded content is unchanged. A completed phase file is never reopened.

## Read budget

`.planning/PLAN.md` Sections 1 through 4, this file, and the Section 5 rows for dataset 25. For the skills work: `<hda>\fhfh\r\*.R` and `<hda>\fhfh\*.qmd` as exemplar donors. For the baseline transcription: the rendered 2022 site at `<hda>\rrh-framework\docs\part-*.html`.

## Why this phase exists

Nothing can be built until the repo exists, renders, and has a locked environment. Two further things had to land before data collection could start: the scaffolding skills that carry the script and chapter boilerplate for every later phase, and the 2022 baseline frame that every "Since 2022" callout reads from. Phase 1 delivered all three.

## What is already done

Nothing preceded this phase. It opens the build.

## Tasks

### Task 1: Scaffold

Archive the State of Housing assets, create the public repo, stand up the Quarto book skeleton with `_common.R`, and lock the R environment.

**Verify:**

- [x] State of Housing assets archived to `archive/soh-2026/` — 3 scripts, 7 PNGs, the pptx, and all 8 stale `data/` files.
- [x] `git init` on `main`; public repo `hdadvisors/pha-update-2026` created; Pages enabled from `main`/`docs`.
- [x] `.gitignore` written and verified with `git check-ignore`: commits `r/`, `docs/`, `_freeze/`, and public-source `data-out/`; ignores `data/` except `data/raw/README.md`, plus `data-out/mls_*` and `data-out/costar_*`.
- [x] Quarto book skeleton renders clean to `docs/` — `index.qmd`, 5 section stubs, and the `data-notes.qmd` appendix, 7 HTML pages, with the noindex meta tag on all 7 and Hypothesis comments present.
- [x] `_common.R` provides `pha_pal` and `cb_pal`; the `rr`, `pha`, `secondary`, `ashland`, and `virginia` geography constants; `puma_core3`, `puma_region`, and `puma_locality`; 18 caption helpers; `flag_reliability()`; `fct_wrap()`; `export_csv()`.
- [x] `_quarto.yml` carries the book config plus `execute-dir: project` and `freeze: auto`; `rrh-framework.scss` and `img/pha_logo.jpg` copied in.
- [x] `data/raw/README.md` states the MLS and CoStar export spec.
- [x] Ashland place FIPS and the 2020 PUMAs resolved through `tigris` rather than from memory. Ashland is 5103368; core-3 is 04101/04102/04103, 08701/08702, 76001/76002; Hanover confirmed not isolable.
- [x] PLAN.md, CLAUDE.md, and README.md written.
- [x] renv configured: `.renvignore` written, and Jonathan ran `renv::init(bare=TRUE)` then `renv::snapshot(type="all")`. R pinned 4.6.0, dplyr 1.2.1, hdatools 0.1.7, ggplot2 4.0.3.
- [x] Render re-verified clean under the locked R 4.6.0 and renv environment.

**Don't:** pull any data; build any figure; transcribe the baseline; build the skills.

### Task 2: Skills and baselines

Two execution sessions, confirmed in the planning session, one focus each per the token-efficiency rule.

| Session | Focus | Model | Why |
|---|---|---|---|
| 2A | Build both skills and their docs | Opus | Designing the universal project-config parameterization and writing good skill instructions is judgment work, not a mechanical pull |
| 2B | Baseline transcription and the Google Doc data plan | Sonnet | Careful but mechanical number extraction from rendered pages, tibble assembly, doc creation |

**What Session 2A built.** Two in-repo, project-level skills at `.claude/skills/{new-data-script,new-chapter}/`, each a lean `SKILL.md` with YAML `name` and `description` frontmatter plus a `references/` directory holding an exemplar and a `conventions.md` digest. Both are project-agnostic and carry a project-config block that the skill populates by reading the target project's CLAUDE.md, PLAN.md, and `_common.R` at invocation, so nothing pha-specific is hardcoded and a later lift to user level stays clean. The block covers the project root and R paths, geography constants and where they are defined, the `_common.R` provisions to source, validation semantics, output directories and the naming and commit policy, the chapter anatomy tokens, and the commit conventions reference. `/new-data-script` emits the header, numbered pull sections, `write_rds()` with `export_csv()`, and validation-block anatomy. `/new-chapter` emits the `#sec-slug` title, a setup chunk that reads `.rds` only, takeaway H2s, alternating figure and table blocks, and the per-section "Since 2022" callout. Build depth was lightweight by decision: draft, smoke-test in a throwaway context, iterate once, with no skill-creator eval loop.

An unplanned mid-task session then upgraded `/new-data-script` through the `skill-creator` skill: migrated off the superseded `map_dfr()` to `map()` with `list_rbind()`, rewrote `references/exemplar-script.R` from a verbatim fhfh donor into a canonical best-practice reference that is what the skill should emit, and adopted `recode_values()` for value maps after verifying it is exported by the pinned dplyr 1.2.1. That correction propagated into CLAUDE.md and PLAN.md.

**What Session 2B built.** `r/baseline.R`, a hand-transcribed data drop rather than a computation, keyed metric by geography with columns `metric`, `geography`, `value`, `unit`, `section`, `source_page`, `source_fig`, and `note`. The planned browser-MCP extraction failed on `file://` paths over the mapped drive, so a scratchpad-only Python `html.parser` extractor pulled the `<main id="quarto-document-content">` text from all 19 rendered pages. The result is 142 rows across 6 sections and 16 geographies. The Section 5 dataset inventory was exported to a Google Doc in Jonathan's Drive; Claude created it and Jonathan shares it, because setting sharing permissions is a prohibited action.

**Verify:**

- [x] Both skills invoke and emit correct pha-shaped scaffolds, confirmed by smoke tests that scaffolded `r/acs_tenure.R` and `ownership.qmd` to the scratchpad with the repo untouched.
- [x] Skills committed in-repo at `.claude/skills/` and confirmed git-tracked (`git check-ignore` exit 1, no un-ignore rule needed); CLAUDE.md and README.md updated to reflect them.
- [x] `data/baseline_2022.rds` and `data-out/baseline_2022.csv` written; `Rscript r/baseline.R` runs clean and the structural `stopifnot()` passes.
- [x] 12 headline numbers spot-checked against the raw rendered HTML by `grep`, all exact matches, logged in full.
- [x] The Google Doc exists, was verified through `get_doc_as_markdown`, and its URL is logged. No sharing permissions were set.
- [x] Every session committed under the project's commit conventions, each with a dated log entry.

**Don't:** gate the data-collection phases on PHA sign-off; pull live data; build chapter content.

## Phase Verify

- [x] `quarto render` completes clean under the locked R 4.6.x and renv environment, producing 7 pages in `docs/`, and the site is live and noindexed on GitHub Pages.
- [x] `.claude/skills/` holds both skills, each with a `SKILL.md` and a `references/` directory, and both are tracked by git.
- [x] `data-out/baseline_2022.csv` exists and its frame covers all 6 sections and every `pha`, `secondary`, and `ashland` geography.

## Phase Decisions

Phase-local. A decision that constrains work outside this phase moves to PLAN.md's Decisions table the first time a later phase depends on it.

| Date | Decision | Why | Status |
|---|---|---|---|
| 2026-07-15 | The scaffolding skills live in-repo at `.claude/skills/`, not at user level | First build and first real-world test; the project-config-block design keeps a later lift clean | promoted to PLAN.md 2026-08-05 |
| 2026-07-15 | Lightweight build depth for both skills: draft, smoke-test, iterate once | The full skill-creator eval and benchmark loop is overkill for two internal boilerplate skills | active |
| 2026-07-15 | The baseline frame is comprehensive rather than minimal: all 5 regional sections plus 2 to 3 signature figures per locality | Every chapter callout and every local summary needs a baseline ready without a second transcription pass | active |
| 2026-07-15 | The `/new-data-script` exemplar is canonical, not a verbatim donor | A fresh run copying a donor exemplar emits off-standard code; the exemplar must be what the skill should produce | active |
| 2026-07-17 | Both 2022-source data inconsistencies are transcribed verbatim with flags rather than corrected | The frame records what the 2022 report said; correcting it would make the baseline something other than the published record | active |

## Open questions

Every question this phase raised has moved to the top entry of `.planning/LOG.md` as a tracked open item: the missing `FRED_API_KEY`, the `acs_income.R` table discrepancy, the 2022 report's narrower definition of "region", and the unverified PUMA vintage for `get_pums()`.
