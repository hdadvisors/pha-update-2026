# Task 2 (Skills + baselines) — PHA 2026 Data Update

Detailed execution plan for PLAN.md §9 **Task 2 — Skills + baselines**. PLAN.md (repo root) remains
the source of truth; this document is the step-by-step build reference. Produced in the Task 2
plan-mode session (2026-07-15, Opus 4.8). Format ref: `R:\hda\fhfh\plans\`.

## Context

Task 1 (scaffold) is complete and committed (`9f720b8`); the repo renders clean under the locked
R 4.6.0 + renv environment. Task 2 is the last Phase A setup task before data collection (Phase B).

Task 2 has three independent deliverables (PLAN.md §9):
1. Build `/new-data-script` + `/new-chapter` as **universal (user-level) skills**, parameterized on a
   project-config block, with exemplars in the skills' reference files.
2. Transcribe `baseline_2022` from the rendered rrh-framework site → `data/baseline_2022.rds` (+CSV).
3. Export the §5 dataset inventory to a Google Doc for PHA (the streamlined data plan).

**DoD (PLAN.md §9):** both skills invocable + documented; baseline frame validated (spot-check ≥10
headline numbers vs the rendered pages); data-plan doc shared.
**Don't:** gate Phase B on PHA sign-off; pull live data; build chapter content.

### Facts established during planning

- **No donor skills exist.** Neither fhfh nor any HDA repo has a `/new-data-script` or `/new-chapter`
  skill — net-new.
- **Location: project-level for now** (Jonathan's call). Skills live **in-repo** at
  `pha-update-2026/.claude/skills/<name>/SKILL.md`, invoked as `/<name>`. This is the first build +
  real-world test; **if they prove out on Tasks 3–11, elevate them to user-level** (`~/.claude/skills/`)
  with any evidence-based revisions so they're portable across HDA projects. The universal
  project-config-block design (below) is built now precisely to make that later lift clean — nothing
  pha-specific is hardcoded, only sourced from the project docs at invocation.
- **Skill anatomy** (from skill-creator): `SKILL.md` (YAML frontmatter `name`+`description`, then
  markdown body <500 lines) + optional `references/` (loaded on demand) + `assets/` + `scripts/`.
  Progressive disclosure: keep SKILL.md lean; put full exemplars in `references/`.
- **Exemplar sources.** pha-update has no finished scripts/chapters yet at Task 2, so the skills'
  reference exemplars come from the donor repos: fhfh `r/` script anatomy (e.g.
  `R:\hda\fhfh\r\acs_demographics.R`) and an fhfh/rrh chapter `.qmd`.
- **rrh docs topic→page map** (baseline source; titles confirmed):
  - `part-1-1` Population changes · `part-1-2` Household characteristics · `part-1-3` Incomes & wages
    · `part-1-4` Special populations → **§1 Demand**
  - `part-2-1` Homeownership → **§2 Ownership** · `part-2-2` Rental homes + `part-2-3` Housing
    assistance + `part-2-4` NOAH → **§3 Rental**
  - `part-3-1` Affordability of current supply → **§4 Gaps** · `part-3-2` Impact of housing costs on
    budgets → **§5 Burden**
  - `part-4-1..9` = 9 local summaries (Richmond, Chesterfield, Henrico, Hanover, Ashland, Charles
    City, Goochland, New Kent, Powhatan) → per-locality baseline rows.
- **Google Workspace MCP is available** (`create_doc`, `import_to_google_doc`, `insert_doc_elements`,
  `start_google_auth`). **Constraint:** setting sharing permissions is a prohibited action for
  Claude — Claude creates the doc; **Jonathan shares it with PHA**.

---

## Execution structure — 2 sessions

Confirmed by Jonathan in the planning session. One focus per session (CLAUDE.md token-efficiency).

| Session | Focus | Model | Why |
|---|---|---|---|
| **2A** | Build both skills + docs | **Opus** | Designing the universal + project-config parameterization and writing good skill instructions is judgment work (meta-tooling, not a mechanical pull). |
| **2B** | Baseline transcription + Google-Doc data plan | **Sonnet** | Careful-but-mechanical number extraction from rendered pages, tibble assembly, doc creation. |

Sessions are independent; either order works. 2A first is natural (skills are reused from Task 3 on).
Each opens with the CLAUDE.md start-of-session checklist and closes with a §11 log entry + commit.

---

## Session 2A — Skills (Opus)

### The project-config block (shared design)

Both skills are **universal**: usable on fhfh, pha-update, and future HDA Quarto book projects. The
per-project variation is captured in a small **project-config block** the skill populates by reading
the target project's `PLAN.md` + `CLAUDE.md` at invocation (pha-update already documents all of it).
Parameters:

- Project root; R version + bin path; render/run commands
- Geography constants + where they're defined (`_common.R`)
- `_common.R` provisions to source (palettes, caption helpers, `flag_reliability()`, `export_csv()`)
- Validation semantics (stopifnot scope; 2022-baseline = logged-not-failed)
- Output dirs + naming/commit policy (`data/`, `data-out/`, `mls_`/`costar_` private prefixes)
- Chapter anatomy tokens (takeaway H2s, "Since 2022" callout, reliability treatment, fig-alt)
- Commit style guide reference

SKILL.md instructs Claude to fill this block from the project docs first, then scaffold — keeping one
skill correct across projects instead of hardcoding pha-update paths.

### `/new-data-script`

- **Frontmatter `description`** (triggering): scaffold a new `r/*.R` data-collection script following
  the project's script anatomy — trigger whenever creating a new data-pull/prep script in an HDA
  Quarto data project.
- **Body:** populate project-config → emit the skeleton (header comment what/source/output →
  `## 1. Setup ----` + `.Renviron` fallback + geo constants → numbered pull sections → `write_rds()`
  + `export_csv()` → validation block) → remind of Windows Rscript rule, idempotency, `case_when()`,
  `map_dfr()`, `.by=`, `janitor::clean_names()`.
- **`references/exemplar-script.R`** — a complete real script (fhfh `acs_demographics.R` pattern:
  county+place+state bind, `load_variables()` label parse, `flag_reliability()` CV, stopifnot).
- **`references/conventions.md`** — R-standards + validation-semantics digest (PLAN.md §3).

### `/new-chapter`

- **Frontmatter `description`** (triggering): scaffold a new Quarto section/chapter `.qmd` following
  the project's chapter anatomy — trigger whenever creating a new report chapter/section.
- **Body:** populate project-config → emit the skeleton (`# Title {#sec-slug}` → setup chunk
  `source("_common.R")` + `read_rds()` stubs + inline-scalar block → theme-based takeaway H2s →
  alternating figure/table + bullet blocks → per-section "Since 2022" `callout-note` → closing
  summary callout) → remind: chapters `read_rds()` only (never call APIs), `theme_pha()`+`pha_pal`,
  reliability treatment on secondary/Ashland, `#| fig-alt:` on every figure, no `@`-refs in captions.
- **`references/exemplar-chapter.qmd`** — a real chapter (fhfh market/demographics chapter).
- **`references/conventions.md`** — chart/table + narrative-rule digest (PLAN.md §3, §6).

### Build depth — lightweight (confirmed)

Draft each skill, then a smoke test (invoke `/new-data-script` and `/new-chapter` in a throwaway
context, confirm they produce correct pha-shaped scaffolds), iterate once. Meets the DoD ("invocable
+ documented") without the full skill-creator eval/benchmark loop, which is overkill for two internal
boilerplate skills used by the HDA team.

### 2A end-of-session

- Skills at `pha-update-2026/.claude/skills/{new-data-script,new-chapter}/`; smoke-tested.
- **Confirm `.claude/skills/` is tracked, not gitignored** — Task 1's `.gitignore` didn't anticipate
  `.claude/`; add an explicit un-ignore / allow rule if needed so the skills commit with the repo.
- Update pha-update **CLAUDE.md** "Skills carry the boilerplate" note + **README.md** if a workflow
  changed (docs are first-class). Note in §11 that skills are **project-level for now** (in-repo, so a
  fresh clone contains them), with a documented **elevation path to user-level** once proven on the
  data/chapter tasks.
- Commit: `infra(task-2-s2a): build /new-data-script + /new-chapter skills`. Add §11 entry.

---

## Session 2B — Baselines + data plan (Sonnet)

### `r/baseline.R` → `data/baseline_2022.rds` (+ `data-out/baseline_2022.csv`)

- **Nature:** a transcribed **data drop**, not a computation (decision 4 — 2022 baselines are
  transcribed from the rendered site, never recomputed/fetched). The script builds a tidy tibble of
  hardcoded headline numbers read off the rrh rendered pages, each row carrying its source citation.
- **Frame shape** (per §6 — keyed by metric × geography):
  `metric | geography (GEOID or name) | value | unit | section | source_page | source_fig | note`.
- **Extraction method:** for each rrh page, open the local rendered HTML with the browser MCP
  (`navigate` to the `file://` path → `get_page_text`) for clean prose+table text, then transcribe
  the headline figures as R literals. (Fallback: `Read` the HTML directly.) Numbers are typed by hand
  into the script — the reproducible record of what the 2022 report said.
- **Target headline metrics — comprehensive frame** (confirmed): headline numbers across all 5
  regional sections *and* 2–3 signature figures per locality, so every chapter's "Since 2022" callout
  and the Task 12 local summaries have a baseline ready. Candidate set by section:
  - **Demand** (part-1-1..4): regional + 4-primary population, population change, # households,
    avg household size, median age, race/ethnicity shares, senior share.
  - **Ownership** (part-2-1): homeownership rate (region + localities), median sale price / value,
    Black–White homeownership gap if reported.
  - **Rental** (part-2-2..4): median gross rent, renter share, vacancy, assisted-unit counts, NOAH
    estimate.
  - **Gaps** (part-3-1): affordable-unit gap / deficit figures by AMI as reported in 2022.
  - **Burden** (part-3-2): cost-burdened share (owner/renter), severely-burdened share, by region +
    primary localities.
  - **Local** (part-4-1..9): 2–3 signature numbers per locality for the Task 12 local summaries.
- **Validation block:** structural `stopifnot()` only (all sections present, no all-NA values,
  expected geography coverage). **No same-vintage benchmark** applies (this frame IS the 2022
  vintage) — and 2022 numbers are never a `stopifnot()` gate anyway (§3 validation semantics).
- **Spot-check (DoD):** re-open ≥10 transcribed numbers against the rendered pages, confirm exact
  matches; log the 10 checked in §11.

### Google Doc — streamlined data plan (§5 inventory)

- **Content:** the §5 dataset inventory (tables A/B/C/D) rendered as a PHA-facing "streamlined data
  plan" — light framing intro + the four tables. Source of truth stays PLAN.md §5; the doc is a
  shareable snapshot.
- **Mechanism:** `create_doc` (or author markdown then `import_to_google_doc`) into Jonathan's Drive.
  Requires Google auth (`start_google_auth`) if not already connected — surface to Jonathan if so.
- **Sharing:** Claude does **not** set sharing permissions (prohibited action). Claude creates the
  doc and hands Jonathan the link; **Jonathan shares it with PHA**. Log the doc URL in §11.
- Per DoD "Don't": informational only — **Phase B is not gated** on PHA sign-off.

### 2B end-of-session

- `r/baseline.R` committed; `data/baseline_2022.rds` written (gitignored); `data-out/baseline_2022.csv`
  committed (public-source). Google Doc created + link handed to Jonathan.
- Commit: `data(task-2-s2b): transcribe 2022 baseline frame + export data plan`. Add §11 entry with
  the 10 spot-checked numbers + the doc URL.

---

## Starter prompts (execution sessions)

**Session 2A (Opus):**
> Task 2 Session 2A (skills). Read CLAUDE.md, PLAN.md §9 Task 2 + §2 chapter-anatomy note + §3
> R-standards, and `plans/task-2-skills-baselines.md`. Build two universal but **project-level** skills
> in-repo at `.claude/skills/`: `/new-data-script` and `/new-chapter`, parameterized on a project-config
> block populated from the target project's PLAN.md/CLAUDE.md (so they stay portable for a later
> user-level lift), with real exemplars from fhfh in each skill's `references/`. Confirm `.claude/skills/`
> is git-tracked. Smoke-test both against pha-update conventions. Update CLAUDE.md/README, log §11,
> commit. Do not transcribe the baseline or touch the Google Doc.

**Session 2B (Sonnet):**
> Task 2 Session 2B (baselines + data plan). Read CLAUDE.md, PLAN.md §9 Task 2 + §5 inventory + §6
> baseline convention + §4 geographies, and `plans/task-2-skills-baselines.md`. Write `r/baseline.R`
> that transcribes 2022 headline numbers from the rendered rrh site (`R:\hda\rrh-framework\docs\`,
> part-1-* / part-2-* / part-3-* regional + part-4-* local) into a tidy metric×geography frame →
> `data/baseline_2022.rds` + `data-out/baseline_2022.csv`; structural stopifnot only; spot-check ≥10
> numbers vs the pages. Then export the §5 inventory to a Google Doc in my Drive (I'll handle
> sharing). Log §11 (10 checks + doc URL), commit. Don't pull live data or build chapter content.

---

## Doc / log references

- **PLAN.md §9 Task 2** (checkboxes/DoD), **§5** (inventory = doc source), **§6** (baseline
  convention), **§4** (geographies), **§11** (log). **CLAUDE.md** commit style guide + skills note.
- **rrh rendered site:** `R:\hda\rrh-framework\docs\part-*.html` (baseline source).
- **fhfh exemplars:** `R:\hda\fhfh\r\*.R`, `R:\hda\fhfh\*.qmd` (skill reference files); fhfh plan
  format `R:\hda\fhfh\plans\`.

---

## Verification (Task 2 DoD)

- [ ] Both skills invoke (`/new-data-script`, `/new-chapter`) and emit correct pha-shaped scaffolds.
- [ ] Skills committed in-repo at `.claude/skills/` (git-tracked); CLAUDE.md/README reflect them;
      §11 notes project-level-for-now + the elevation path to user-level.
- [ ] `data/baseline_2022.rds` + `data-out/baseline_2022.csv` written; structural stopifnot passes.
- [ ] ≥10 headline numbers spot-checked against the rendered rrh pages and logged in §11.
- [ ] Google Doc created; link handed to Jonathan (he shares); URL logged in §11.
- [ ] Each session committed per the CLAUDE.md commit style guide; §11 status table updated.
