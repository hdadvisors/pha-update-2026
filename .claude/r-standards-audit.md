# R standards compliance audit — v0 freeze and findings

**Tracking Issue:** [#9](https://github.com/hdadvisors/pha-update-2026/issues/9) in this repo. The wider body of work is [hdadvisors/hda-claude#32](https://github.com/hdadvisors/hda-claude/issues/32), where this audit is Phase 7.

**What this document is.** A frozen snapshot of every R convention this repo had written down as of 2026-08-05, each given a permanent ID, plus every defect found by auditing the repo against that snapshot. It is **evidence, not a ruling.** No rule in it is proposed, changed, or decided here; where the audit found a genuine ambiguity it is written up as an open question rather than resolved.

**Why it runs before the standard exists.** HDA has no org-wide R standard yet. This repo has the most complete written conventions of any HDA repo, so it can be audited *against itself* before that standard exists — and a finding that this repo contradicts its own documented rule stays valid no matter what the later rulings sitting decides. The audit produces the evidence that sitting reads.

**Four passes, in order:** v0 freeze → self-consistency → gap → stale doc. Each is a separate section below.

**Reading rule.** Every finding states its tier before its count or severity means anything, and every finding cites a source: a self-consistency finding cites the v0 ID it violates; a gap finding cites a specific `crc` location or `hdatools` export and is labeled **Evidence**, never a violation. A claim with no citable source is not in this document.

---

## 1. Scope tiers

**Declared before anything was counted.** A violation's tier determines whether its count means anything at all — nine hardcoded font sizes in a frozen slide deck are not evidence of a pattern in the live report pipeline, and reading them as one would send someone editing an archive.

### Tier 1 — the live pipeline

The files that render the report. In scope, fully.

| File | Lines | What it is |
|---|---|---|
| `_common.R` | 222 | Chunk options, packages, palettes, geography constants, 18 caption helpers, `flag_reliability()`, `fct_wrap()`, `export_csv()` |
| `r/baseline.R` | 266 | The one committed data script — a hand-transcribed 2022 baseline frame |
| `_quarto.yml` | 64 | Book config, knitr chunk options, HTML format |
| `index.qmd`, `demand.qmd`, `ownership.qmd`, `rental.qmd`, `gaps.qmd`, `burden.qmd`, `data-notes.qmd` | 117 total | Six section stubs and an appendix stub, 12–37 lines each. Setup chunk only; no content yet |

**Tier 1 contains zero `ggplot()` calls and zero `theme_*()` calls** — the one `theme_pha()` string in the tier is a package-loading comment at `_common.R:23`. Verified by direct grep, not assumed. This single fact disposes of most of what a naive chart audit would have flagged, and it is why several gap findings below are recorded as forward-looking rather than as live defects.

### Tier 2 — skill exemplars and reference material

`.claude/skills/new-data-script/` and `.claude/skills/new-chapter/`: two `SKILL.md` bodies, two `references/conventions.md` digests, and two exemplars (`exemplar-script.R`, `exemplar-chapter.qmd`).

**Higher stakes than Tier 1, not lower.** These files are the copy source for every future script and chapter. A defect here does not sit still; it propagates into every file the skill scaffolds. Finding 4 is the whole argument for this tier existing.

Note that the two `references/conventions.md` files are simultaneously **v0 sources** (Section 2 freezes them) and **Tier 2 audit targets** (Section 3 audits them). That is not circular: a document can state a rule and also fail to agree with the other document stating the same rule, which is exactly finding S1 below.

### Tier 3 — frozen deliverables

`archive/soh-2026/` — three chart scripts (428 lines), eight source data exports, seven delivered PNGs, and the delivered deck.

**Out of scope for compliance, entirely.** These were written for a slide deck, against an older `hdatools`, before this repo had conventions. `archive/soh-2026/README.md` (written by this audit, finding 5) declares this in the directory itself so a future sweep does not re-investigate it. Everything a checker would flag there is enumerated in that README.

**Nothing in Tier 3 is counted anywhere in this document.** Where a Tier 3 count appears below it appears explicitly as a *reason not to record a finding*.

---

## 2. The v0 freeze

The union of three documents, as of commit `b938d8a`, before this audit's own fixes:

| Key | Source document |
|---|---|
| **C** | `CLAUDE.md` |
| **DS** | `.claude/skills/new-data-script/references/conventions.md` |
| **CH** | `.claude/skills/new-chapter/references/conventions.md` |

A `SKILL.md` is **not** a v0 source — both are Tier 2 audit targets. Where a v0 rule also appears in a `SKILL.md`, that location is recorded against the rule's ID as an *appearance*, because a rule that is wrong has to be corrected everywhere it appears, not only where it was frozen from. This is what lets finding S1 cite one ID across three files.

### About the IDs

**Prefix `PHA-`, not `R-`.** These are this repo's own documented rules, frozen for audit — not the org standard. Two reasons for the prefix:

1. The org standard reserves `R-D01` through `R-D14` for a different axis (hdatools-usage rulings). Using an unrelated prefix makes collision with that range impossible rather than merely avoided.
2. The rulings sitting will mint its own IDs across categories A, B, C, E, and F. If this document had minted `R-A01` too, the two schemes would collide on their first overlap. A `PHA-` ID maps onto a future standard ID without either one moving.

**Category letters mirror the planned scheme** (A scope and mechanics, B language and idiom, C project skeleton, E chart/figure/narrative spec) so the mapping is mechanical rather than a judgment call. There are no F rules: v0 contains no enforcement or retrofit conventions.

**An ID is permanent.** It is never renumbered, reused, or moved, even if a later pass finds the rule wrong, redundant, or superseded. PHA-E10 is the live example — it was frozen with wrong text, and it keeps its number with the text struck and corrected in place rather than being reissued.

### A — scope and mechanics

| ID | Rule | Stated at |
|---|---|---|
| PHA-A01 | Never run R inline. Write `r/<name>.R` and run `Rscript r/<name>.R` from the project root. Ad hoc checks go in a scratchpad script, never in the repo. | C:90; DS:85–86 |
| PHA-A02 | R and Quarto are usually not on PATH; prepend the bin path. Install paths are documented in README.md and nowhere else. | C:92; CH:96 |
| PHA-A03 | Use forward slashes in R paths, and keep every path relative to the project root. | C:94 |
| PHA-A04 | `CENSUS_API_KEY` and `FRED_API_KEY` are both required and live in the user `.Renviron` at `%USERPROFILE%\Documents\.Renviron`. Never print or commit their values; verify visibility with a TRUE/FALSE check only. | C:98, C:100; DS:65–70 |
| PHA-A05 | Every script carries an `.Renviron` fallback derived from the current user — `readRenviron(file.path(Sys.getenv("USERPROFILE"), "Documents", ".Renviron"))` when the key is empty — never a hardcoded username. R's HOME on Windows may not be the Documents folder. | C:100; DS:66–69 |
| PHA-A06 | Data-fetch approvals: tidycensus, tigris, and fredr package downloads are approved; census.gov file servers (BPS, PEP FTP) and huduser.gov are approved with a manual fallback; anything else on a government host, especially BLS OEWS, needs the maintainer's approval or a manual download. | C:104; DS:74–77 |
| PHA-A07 | Long jobs — PUMS, CHAS, and tigris pulls, and any full render over roughly two minutes — are the maintainer's to run. Claude writes the script and hands it off; never babysit an `Rscript` run. | C:42; CH:97 |
| PHA-A08 | Invoke `/new-data-script` before writing a new `r/*.R` pull or prep script, and `/new-chapter` before a new section `.qmd`. Never regenerate the anatomy from scratch in context. | C:44 |
| PHA-A09 | One phase focus per session; do not read whole files when a block will do. Model by session type: Sonnet for mechanical pulls and QA sweeps, Opus for planning, methodology, and chapter builds, Fable for meta-level critique only. | C:40–41 |
| PHA-A10 | Public repo, GitHub Pages live from `main`/`docs`, carrying a noindex robots meta tag until the report is final. PHA reviewers comment through a private Hypothesis group. | C:108 |
| PHA-A11 | Manual data drops for MLS and CoStar go straight into `data/raw/`, supplied by the maintainer. | C:43 |
| PHA-A12 | PEP: the post-2020 API requires an explicit `vintage=` argument; `year=` alone misbehaves silently. Use Vintage 2025 and fall back to the FTP tables if the API lags. | C:112; DS:81–82 |
| PHA-A13 | huduser.gov: send a browser User-Agent and Referer or the server returns 202 or an empty body. The CHAS data dictionary is a separate download from the table zips. | C:113; DS:83–84 |

### B — language and idiom

| ID | Rule | Stated at |
|---|---|---|
| PHA-B01 | Native pipe `\|>`, tidyverse style. | C:54; DS:10 |
| PHA-B02 | `janitor::clean_names()` on all imported raw data. | C:54; DS:10 |
| PHA-B03 | dplyr 1.2 idioms: `.by=` over `group_by()` for one-off grouping; `across()`; `join_by()`; `reframe()` for multi-row summaries. DS additionally names `when_any()`/`when_all()`, `replace_values()`, and `filter_out()` as available. | C:55; DS:11–15 |
| PHA-B04 | `recode_values()` for value-to-label recodes — the pinned dplyr is 1.2.1 and `case_match()` is soft-deprecated. Reserve `case_when()` for genuine conditional logic, not value lookups. | C:55; DS:16–20 |
| PHA-B05 | `purrr::map()` and `imap()` over `for` loops, bound with `list_rbind()` or `list_cbind()`. The pinned purrr is 1.2.2, in which `map_dfr()`/`map_dfc()` are superseded. | C:56; DS:21–26 |
| PHA-B06 | tidycensus call shape: `get_acs(geography, state = "VA", table = "BXXXXX", year, survey = "acs5", cache_table = TRUE)`. Pull whole tables and build label lookups from `load_variables()` with `separate_wider_delim(label, "!!")`. | C:57; DS:27–29 |

### C — project skeleton

| ID | Rule | Stated at |
|---|---|---|
| PHA-C01 | Script anatomy, mandatory order: header comment (what / source and vintage / tables / output) → `## 1. Setup ----` (libraries, `source("_common.R")`, `.Renviron` fallback, `dir.create("data")`) → numbered pull sections, one per table or source, each with a `message()` progress line and an `nrow()` confirmation → `write_rds()` paired with `export_csv()` → validation block. | C:52; DS:31–40 |
| PHA-C02 | Scripts are idempotent and safe to re-run. No inline `install.packages()`. | C:52; DS:41 |
| PHA-C03 | One-way data flow: `r/` scripts write `data/*.rds` and, through `export_csv()`, `data-out/*.csv`. Chapters call `read_rds()` only. Chapters never call APIs. | C:48; CH:15–17 |
| PHA-C04 | `export_csv(df, name)` writes `data-out/<name>.csv`. Naming is commit policy: name public-source exports plainly, and prefix MLS and CoStar derivatives `mls_` or `costar_` so `.gitignore` keeps them private. | C:71; DS:88–92 |
| PHA-C05 | `stopifnot()` fires only on structural expectations (row counts, all geographies present, no all-NA columns) and on same-vintage published benchmarks — a HUD-published MFI, a Census-published table total, or the State of Housing deck numbers current as of January 2026. | C:61; DS:53–56 |
| PHA-C06 | 2022 baselines are compared as a logged percentage change in the session log entry, never as a `stopifnot()` gate. Implausible swings are flagged for human review; they never fail a build, because 2020-2024 and 2016-2020 ACS differ by construction. | C:62; DS:57–60; CH:77–79 |
| PHA-C07 | Every data phase logs its benchmark results, both passes and variances. | C:63; DS:61 |
| PHA-C08 | Reliability: carry a 0–100 CV column, `cv = if_else(estimate > 0, (moe / 1.645) / estimate * 100, NA_real_)`. Tier it with `_common.R`'s `flag_reliability()` — High at or below 15, Medium at or below 30, Low above 30. Never `hdatools::add_reliability()`, which assumes a 0–1 scale and mislabels small cells as Low. | C:70; DS:43–49; CH:51–63 |
| PHA-C09 | Reliability boundary: data scripts only *emit* the `cv` column. Tiering, suppression, and footnoting happen downstream in chapters. | DS:47–49 |
| PHA-C10 | `_common.R` provides the palettes (`pha_pal`, `cb_pal`), the geography constants (`rr`, `pha`, `secondary`, `ashland` at place FIPS 5103368 sumlev 160, `virginia`, `puma_core3`, `puma_region`, `puma_locality`), 18 caption helpers, `flag_reliability()`, `export_csv()`, and `fct_wrap()`. Source them; do not redefine them. | C:67–72 |

### E — chart, table, and narrative spec

| ID | Rule | Stated at |
|---|---|---|
| PHA-E01 | `theme_pha()` with `pha_pal`, plus `add_zero_line()`. | C:76; CH:20 |
| PHA-E02 | Static ggplot2 only — no ggiraph, plotly, or leaflet. A locked decision. | CH:20–21 |
| PHA-E03 | Titles are takeaway sentences matching `fig-cap`. The subtitle carries geography, units, and years. | C:77; CH:22–23 |
| PHA-E04 | For 2 or 3 series, prefer color-coded bold words in the subtitle — ggtext spans written as `<span style='color:#hex'>**word**</span>` using `pha_pal` hexes — over a legend; match the hexes to the fills. | C:78; CH:24–25 |
| PHA-E05 | Currency uses `scales::label_dollar()`, and the subtitle notes whether a series is nominal or inflation-adjusted. Percentages use `label_percent(accuracy = 1)` unless precision matters. | C:79; CH:26–27 |
| PHA-E06 | Captions come from `_common.R` source helpers, never hand-typed source lines. | C:77; CH:28–29 |
| PHA-E07 | Tables use `kbl() \|> kable_styling(c("condensed","striped"))` with `formattable::comma` and `percent`. | C:80; CH:33–34 |
| PHA-E08 | The table source line goes in `footnote(general = <caption helper>, general_title = "", footnote_as_chunk = TRUE)`. | CH:35–36 |
| PHA-E09 | No `@fig`, `@tbl`, or `@sec` cross-reference inside `labs(caption=)` or a kbl `footnote()` — gridtext throws an `<a>`-tag error. Keep cross-references in markdown bullets. | C:114; CH:28–29, CH:85–86 |
| PHA-E10 | **Strip-text overrides.** ~~Frozen v0 text: "a raw `strip.text = element_text()` override can clash with `theme_pha`'s strip element — avoid overriding it, or de-facet."~~ **Struck: the frozen text is wrong.** Corrected by this audit — see finding S1. The ID does not move. | C:115; CH:87–90; also appears at `new-chapter/SKILL.md:174` |
| PHA-E11 | Every figure gets `#| fig-alt:` alt text — full sentences describing content and trend. | C:82; CH:92 |
| PHA-E12 | Secondary-locality and Ashland ACS estimates always carry reliability treatment: suppress cells with a CV above 30, footnote the Medium cells, and state reliability in a bullet or the callout. Small counts (PIT, evictions) are presented as counts with volatility caveats, never as rates. | C:81; CH:52–60 |
| PHA-E13 | Chapter anatomy, mandatory order: `# Title {#sec-slug}` → setup chunk (`source("_common.R")`, `read_rds()` stubs, an inline-scalar block) → theme-based takeaway H2s → alternating figure/table + bullet blocks → per-section change callout → closing summary or caveat callout. | CH:11–13 |
| PHA-E14 | Narrative rule: takeaway H2s, 2 to 5 bullet findings per section (plain statements each traceable to a figure or table), and callout boxes. No drafted paragraphs — bullets specific enough that a human expands them into prose without reopening the data. Expose a few live numbers via inline `r ...` scalars. | C:86; CH:67–71 |
| PHA-E15 | Every section carries a per-section `::: {.callout-note}` "Since 2022" box comparing 2020-2024 figures to `baseline_2022`, computed inline. Baseline deltas are narrative and logged, never a `stopifnot()` gate. | C:86; CH:75–81 |

**44 rules: 13 A, 6 B, 10 C, 15 E.**

### Deliberately not assigned an ID

Recorded so the omission is visible and reversible rather than silent. `CLAUDE.md` also carries a start-of-session checklist, an end-of-session checklist, a commit-type vocabulary and scope grammar, a repo-type declaration, a phase-table status gate, and a repo-map pointer. These are session-process and git conventions owned by `hda-docs` and `hda-git:commit`. They are excluded because **no R file can violate them**, so carrying them into an R standard would add 6 rules that no checker could ever evaluate and no audit pass could ever exercise. If the rulings sitting disagrees, they can be added with fresh IDs; nothing above needs to move.

---

## 3. The six pre-confirmed findings

Confirmed during planning, before this audit ran. Inputs, not discoveries. Listed here with what actually happened to each.

| # | Tier | Finding | Severity | Disposition |
|---|---|---|---|---|
| 1 | 1 | `_quarto.yml` set no `dev`, so no figure could ever receive a bundled brand font | blocking | **Fixed** — `dev: "ragg_png"` set at `_quarto.yml:43`. See the caveat below |
| 2 | 1 | `_common.R`'s `pha_pal` hand-duplicated the package's PHA palette exactly | blocking | **Fixed** — now `pha_pal <- pha_pal_discrete()(6)` at `_common.R:38`. See the correction below |
| 3 | 1, 2 | The strip-text rule (PHA-E10) prescribed avoidance where `hdatools` prescribes `ggtext::element_markdown()`, in three files | blocking | **Fixed** in all three — see finding S1 |
| 4 | 2 | `exemplar-chapter.qmd` is an unconverted donor chapter and is the copy source for every future chapter | blocking | **Flagged, not rewritten** — see below |
| 5 | 3 | `archive/soh-2026/` had no README declaring it frozen | advisory | **Fixed** — `archive/soh-2026/README.md` written |
| 6 | 1 | `fct_wrap()` is not a defect | none | **Confirmed non-finding** — see Section 7 |

### Finding 1 — the fix is necessary but not yet sufficient

`dev: "ragg_png"` is set and the render still exits 0 (smoke-rendered `burden.qmd`, clean, no artifact churn). But it does **not** put brand type in figures at this repo's pinned `hdatools`, and saying otherwise would be wrong.

Measured directly under the project's own renv library: after `library(hdatools)`, `systemfonts::registry_fonts()` returns **0 rows**, while `sysfonts::font_families()` lists `Lato, Roboto Slab, Open Sans, Poppins, Noto Sans`. The pinned 0.1.7 registers fonts through **showtext/sysfonts**; `ragg` reads the **systemfonts** registry, which is empty. `theme_pha()` defaults to `base_family = "Noto Sans"`, and `"Noto Sans"` is not an installed system font on this machine.

So the setting is correct, is a prerequisite, and costs nothing — but the font gap closes only when `hdatools` is upgraded. Root cause is gap finding **G1**. This is inert today regardless: Tier 1 has zero `ggplot()` calls.

### Finding 2 — a correction to the fix as specified

The fix was specified as `pha_pal <- pha_colors()`. That is wrong twice over:

1. **`pha_colors` is a data object, not a function** — `hdatools/R/colors.R:45` is `pha_colors <- .brands$pha$palette`. `pha_colors()` raises "attempt to apply non-function."
2. **`pha_colors` does not exist at this repo's pinned version** at all. Confirmed by running it: `Error: object 'pha_colors' not found`.

The version-appropriate accessor 0.1.7 does export is `pha_pal_discrete()`, a palette factory. `pha_pal_discrete()(6)` returns the six hexes and was verified `identical()` to the vector it replaced, unnamed, with `cb_pal` byte-identical before and after — checked by sourcing the edited `_common.R` and asserting both objects. The naming detail matters: `pha_colors` is a *named* vector, so a naive swap would have renamed `cb_pal`'s keys from `Severely cost-burdened` to `Severely cost-burdened.Red`, silently breaking any manual scale keyed on them.

Recorded because the wrong call form appears in the planning documents and would otherwise be copied forward.

### Finding 4 — flagged, deliberately not fixed

`exemplar-chapter.qmd` (now 550 lines) carries a 40-line non-compliance banner above its existing header, and `new-chapter/SKILL.md` carries a matching block-quote warning that redirects readers to its own inline skeleton. **Content otherwise unchanged: the diff is 40 insertions, 0 deletions.**

Verified counts, from `HEAD` before this audit's edits: 12 `theme_hda()` calls; 5 reads of `hda_pal`; 6 `scale_fill_manual()` and 2 `scale_color_manual()` calls with hand hexes; 3 hand-written `<span style='color:#hex'>` subtitle spans; 2 hand-built `c(\`TRUE\` = blue, \`FALSE\` = "grey75")` focus palettes.

`hda_pal` deserves its own line: it exists **nowhere**. Not in this repo (`_common.R` defines `pha_pal`) and not in `hdatools` at either version — 0.1.7 exports `pha_pal_discrete()`, a function; 0.5.0 exports the `pha_colors` vector. Copying this file errors out on its first chart.

It is not rewritten because a patched donor is not an exemplar. The replacement has to be this project's own first compliant chapter — a file that passed a checker, not one someone hopes is representative.

**Concentration note.** Every one of those defects is in one file, so under this audit's own concentration rule they are **one finding, not six**. A file-count of "8 manual scales, 12 wrong-brand themes" across the repo would be a false pattern; all of it is this single donor.

---

## 4. Self-consistency pass

Tier 1 and Tier 2 audited against the v0 checklist. Every finding cites the v0 ID it violates.

**The yield is small, and that is the finding.** Tier 1 is clean against v0: zero magrittr pipes, zero `T`/`F` logical literals, zero `coord_flip()`, correct script anatomy in `r/baseline.R` with a structural-only `stopifnot()` and a comment explaining why no benchmark applies, and `_common.R`'s 18 caption helpers and 8 geography constants matching `CLAUDE.md`'s inventory exactly (checked name by name). Padding this section would misrepresent the repo.

### S1 — PHA-E10 is documented wrong, in three files *(blocking, fixed)*

**Tier 1 and Tier 2.** `CLAUDE.md:115` (Tier 1), `new-chapter/references/conventions.md:87` (Tier 2, a v0 source), `new-chapter/SKILL.md:174` (Tier 2, an appearance).

v0 told the reader to avoid overriding strip text or to stop faceting. The upstream package documents the opposite: `hdatools/R/themes.R`, in `theme_pha`'s `@details`, says to use `ggtext::element_markdown()` and never a raw `element_text()`, because the branded strip element is a ggtext markdown element and ggplot2 4.0 merges only elements of the same class. `element_text()` is the thing that clashes; faceting is not the problem and never needed avoiding.

This cites PHA-E10 rather than violating it — the rule is v0-documented and simply wrong against its own upstream source, which is the shape the phase this audit belongs to explicitly assigns to this pass.

**Corrected in all three files.** One nuance worth recording: at the *pinned* 0.1.7, `theme_pha()$strip.text` is a plain `ggplot2::element_text` inherited from `theme_minimal()` — measured, not inferred — so no clash arises there at all. The markdown strip element appears at `hdatools/R/themes.R:109` in 0.5.0. The frozen rule was therefore wrong at both versions, for two different reasons: it prescribed avoidance where 0.5.0 wants a class match, and it warned of a clash that 0.1.7 cannot produce.

### S2 — PHA-E07's two statements of the table rule disagree *(advisory, not fixed)*

**Both locations are v0 sources**, which is what makes this a self-consistency finding rather than a style nit.

- `CLAUDE.md:80` — `kbl() |> kable_styling(c("condensed","striped"))`
- `new-chapter/references/conventions.md:33` — `kbl(align = "...") |> kable_styling(c("condensed", "striped"), full_width = FALSE)`

Two arguments appear in one statement and not the other: `align =` and `full_width = FALSE`. These are not cosmetic — `full_width` changes whether every table in the report spans the page. A chapter scaffolded by a session reading `CLAUDE.md` gets full-width tables; one scaffolded from the skill digest does not, and nothing reconciles them.

**Not fixed here.** Which form is canonical is a ruling, and this phase does not rule. Both statements are recorded against PHA-E07 so whichever is chosen propagates to both.

---

## 5. Gap pass

Rules real in `crc`'s conventions or in the `hdatools` exported API but absent from v0. **Every item here is Evidence for the rulings sitting, not a violation.** This repo cannot have broken a rule it never wrote down.

### G1 — the repo pins `hdatools` 0.1.7; the planned hdatools rules assume 0.5.0 *(Evidence — the root cause under findings 1, 2, and 3)*

**Tier 1** — `renv.lock` governs every tier at once.

`renv.lock` pins `hdatools` **0.1.7**, dated 2024-11-19, `RemoteSha 7ac3e5f`. The installed copy at `renv/library/windows/R-4.6/x86_64-w64-mingw32/hdatools` confirms it. Its `NAMESPACE` exports **25** names. The current package at `R:\hda\hdatools\NAMESPACE` exports **69**.

Exports the planned hdatools-usage rules depend on that **do not exist** at the pin:

| Missing export | What the planned rule needs it for |
|---|---|
| `pha_colors`, `pha_color()` | Brand hex lookups and semantic/ordinal mappings |
| `pha_span()` | Replaces the hand-written ggtext spans PHA-E04 currently prescribes |
| `pha_focus_pal()` | Replaces hand-built highlight-one-mute-the-rest palettes |
| `scale_*_pha_b()`, `scale_*_pha_c()` | Binned and continuous brand scales |
| `register_hda_fonts()` | The systemfonts registration path `ragg` reads |
| `theme_vha`, `vha_*` | Fourth brand, not present at all |

Three further measured consequences, each checked by running code rather than reading source:

- **Font mechanism differs.** After `library(hdatools)` at the pin, `systemfonts::registry_fonts()` is empty (0 rows) and `sysfonts::font_families()` carries the brand fonts. 0.1.7 is showtext-based; 0.5.0 is systemfonts-based. This is why finding 1's fix is necessary but not sufficient.
- **The strip element differs.** `theme_pha()$strip.text` is `ggplot2::element_text` at the pin and `ggtext::element_markdown()` at 0.5.0 (`hdatools/R/themes.R:109`). This is why PHA-E10 was wrong at both versions for different reasons.
- **The pin is not clean under the pinned ggplot2.** Calling `theme_pha()` under the pinned ggplot2 4.0.3 emits two deprecation warnings — `size` in `element_line()` and in `element_rect()`, deprecated since ggplot2 3.4.0 — naming `hdatools` as the source.

v0 has **no version-pinning rule of any kind**, so nothing here is a violation. But it is the single most consequential piece of evidence this audit produced: an entire planned rule axis is written against an API this repo cannot currently call, and the upgrade is a real migration (font mechanism, scale surface, and accessor surface all change), not a lockfile bump. Written up as open question **Q2**.

### G2 — no v0 rule requires deriving brand values from the package *(Evidence)*

`hdatools` exports the palette at both versions — `pha_colors` at `hdatools/R/colors.R:45`, `pha_pal_discrete()` at the pin. v0's PHA-C10 and PHA-E01 both *name* `pha_pal` but neither says where its values may come from, so hand-typing six hexes that duplicate the package broke no documented rule. Finding 2 was fixed anyway, because a gap finding's severity does not depend on whether it also violated something.

### G3 — no v0 rule governs the figure device *(Evidence)*

v0's entire chart section (PHA-E01 through PHA-E12) is silent on `dev`. The package's font registration runs at load (`hdatools/R/zzz.R`), and the empirical consequence of omitting `ragg` is not uniform: silent substitution with warnings in HTML, and a **fatal, whole-render-halting error** in PDF (`font family 'Lato' not found in PostScript font database` → `Execution halted`), measured in the spike recorded at `R:\hda\hda-claude\.planning\r-standards-spike-findings.md`. Finding 1 fixed it here.

### G4 — no v0 rule requires an explicit `color` on text geoms *(Evidence)*

`crc/CLAUDE.md:108` states the rule and `crc/CLAUDE.md:128` gives the mechanism. Upstream: `hdatools/R/themes.R:143-149` sets `element_geom(ink = "#383c3d", ..., colour = NA, fill = discrete_pal[1])`, package-wide across all four themes — so any geom drawing through the `colour` channel with no fill fallback renders invisible unless the layer sets it.

**Tier note:** this bites Tier 1 and Tier 2 the moment a chart exists. Tier 1 has zero `ggplot()` calls today, so nothing is currently broken, and the exemplar's own `geom_text()` calls do largely pass explicit colors. Recorded as forward-looking evidence, not a live defect.

### G5 — no v0 rule prefers direct axis mapping over `coord_flip()`, or scopes `flip_gridlines` *(Evidence)*

`crc/CLAUDE.md:104-105`. Tier 1 and Tier 2 contain zero `coord_flip()` calls, so there is nothing to fix — the gap is in the written standard, not the code.

### G6 — no v0 rule governs the span and focus-palette helpers, and PHA-E04 prescribes the thing they replace *(Evidence)*

`hdatools` exports `pha_span()` (`R/span.R`) and `pha_focus_pal()` (`R/focus.R`) at 0.5.0. This is stronger than a simple absence: **PHA-E04 actively documents the hand-written `<span style='color:#hex'>**word**</span>` form as the house convention**, which is exactly what `pha_span()` exists to replace.

It is still Evidence and not a violation, on two independent grounds: v0 cannot violate a rule it does not contain, and at the pinned 0.1.7 neither helper exists to be called. Blocked behind G1.

### G7 — no v0 rule governs `base_size` or output-format detection *(Evidence, and a tier trap)*

`crc/CLAUDE.md:100` and `crc/CLAUDE.md:127` carry crc's `base_size` rule and its auto-shrink gotcha; `hdatools` exports `get_output_format()` and `adjust_base_size()` at both versions. v0 says nothing about either.

**Resolve the tier before reading the count.** A grep for hardcoded `base_size` returns **9 hits, and all 9 are Tier 3** — two `theme_pha(base_size = 50)` in `archive/soh-2026/scripts/demographics.R`, two `base_size = 60` in `market-rental.R`, five in `market-sale.R`. Tier 1 and Tier 2 return **zero**. Those nine were correct for a slide canvas and are frozen. **This is explicitly not evidence of a Tier 1 pattern**, and recording it as one would send someone editing an archive — which is the specific failure this audit's tier discipline exists to prevent. `archive/soh-2026/README.md` now says so in the directory itself.

### G8 — no v0 rule governs diverging-bar axis breaks or bar value labels *(Evidence, narrow)*

`crc/CLAUDE.md:113-114` — explicit `breaks` at round increments with `expand = expansion(mult = 0.15)`, values kept as raw proportions, and bar labels at `accuracy = 0.1` positioned outside the bar by sign. Narrow scope: diverging value bar charts only. Recorded for completeness; it is the weakest item in this section.

### Checked and deliberately **not** recorded as a gap

`crc/CLAUDE.md:98` specifies `ggsave(width = 4.25, height = 3, dpi = 300, bg = "white")` for chart PNGs. This is absent from v0, but it is **not a gap for this repo**: it is a rule of the designer-handoff workflow, where chart PNGs are assets placed in a layout tool. This repo is self-rendered — Quarto produces the deliverable from live chunks — so it has no `ggsave()` calls anywhere outside Tier 3 and should not acquire the rule. Recorded here so a later pass does not "find" it.

---

## 6. Stale-doc pass

Does v0's text still match reality?

### T1 — v0 and Tier 1 both point at planning files that no longer exist *(advisory, not fixed)*

The `.planning/` migration (PR #8, merged as `b938d8a`) deleted root `PLAN.md` and `EXECUTION-PLAN.md`. Commit `57ffe9b` repointed *some* of the references and missed these **15, across 12 files and two tiers**:

**v0 text and Tier 2 reference material:**

| Location | Stale reference |
|---|---|
| `CLAUDE.md:44` | "reads a project-config block from this file, PLAN.md, and `_common.R`" |
| `new-chapter/SKILL.md:46` | "Read the target project's `CLAUDE.md`, `PLAN.md` …" — never repointed |
| `new-chapter/SKILL.md:51`, `new-data-script/SKILL.md:48` | Both config-block headers still read "fill from CLAUDE.md / PLAN.md / _common.R" |

**Tier 1 content:**

| Location | Stale reference |
|---|---|
| `burden.qmd:14`, `demand.qmd:13`, `gaps.qmd:14`, `ownership.qmd:13`, `rental.qmd:14`, `data-notes.qmd:12` | "see PLAN.md §9" |
| `data-notes.qmd:4` | "EXECUTION-PLAN §3" |
| `r/baseline.R:4, 7, 23, 247` | "PLAN.md S6", "S1", "S1/S4", "S3" |
| `_common.R:81, 87, 170, 204` | "EXECUTION-PLAN §7", "§7", "§7", "§4, §5" |

**Spread across 12 files, so this is a pattern, not an artifact of one file.** The section numbers are doubly stale: `.planning/PLAN.md` renumbered its sections during the migration, so even repointing the filename would not make "§9" resolve.

**Not fixed here.** The phase this audit belongs to lands exactly two file fixes in this pass (findings 4 and 5); sweeping 12 files is separate work, and this audit's own rule is to default away from creating work. Recorded so it can be scheduled deliberately.

### T2 — PHA-E07's positional `kable_styling()` produces no styling in PDF *(advisory, latent, not fixed)*

Both v0 statements of PHA-E07 pass `kable_styling()`'s options **positionally**. Empirically that form silently produces **zero** table styling in PDF: rendering the org's documented pattern verbatim and keeping the intermediate `.tex` showed no `\cellcolor` commands anywhere in the table block, while the same table with named `bootstrap_options=`/`latex_options=` styled correctly. No error, no warning. Recorded at `R:\hda\hda-claude\.planning\r-standards-spike-findings.md`, Task 3.

**Latent, not active.** `_quarto.yml` declares `format: html` only, and HTML styles correctly under both calling conventions. `_quarto.yml:63` defers the PDF route, at which point this starts silently shipping unstyled tables.

**Not fixed here.** Which calling convention is canonical is a ruling. Flagged against PHA-E07 alongside S2, since both concern the same rule's argument list.

### Checked and clean

`_common.R:23`'s comment names `theme_pha()`, `scale_fill_pha()`, `scale_color_pha()`, and `add_zero_line()` as what `hdatools` provides. All four exist at the pinned 0.1.7 — verified against the installed `NAMESPACE`. Not stale. `new-chapter/references/conventions.md:5-7`'s description of the exemplar as an unadapted donor to be read for anatomy rather than copied was already accurate, and is now reinforced rather than corrected.

---

## 7. Confirmed non-findings

Recorded so a later dedup or cleanup pass does not "fix" them.

### `fct_wrap()` is not a duplicate of anything *(finding 6)*

**Tier 1**, `_common.R:202`. `fct_wrap(f, width)` is `fct_relabel(f, ~ str_wrap(., width = width))` — it wraps **the levels of a factor**, for wrapping axis labels. `hdatools::markdown_wrap_gen()` returns a **labeller function** for use in a facet spec. They operate on different objects at different points in the plot pipeline and are not interchangeable. **No change. Do not "deduplicate" these.**

### `flag_reliability()`'s `case_when()` is correct

**Tier 1**, `_common.R:189-197`. PHA-B04 reserves `case_when()` for genuine conditional logic and directs value-to-label recodes to `recode_values()`. `flag_reliability()` tests ranges (`cv <= 15`, `cv <= 30`, `cv > 30`) rather than looking up values, so `case_when()` is the correct choice. Not a PHA-B04 violation.

### The brand-mixing count is a scope artifact

A repo-wide grep returns 14 `theme_hda(` and 6 `theme_pha(` in Tier 2 — a count that looks like brand mixing and is not. **Twelve of the `theme_hda` calls are finding 4's single donor file**; the remainder, and every Tier 2 `theme_pha`, are in prose, skeletons, and the warning banners this audit added. Tier 1 has **zero** `theme_*()` calls of any brand because it has zero `ggplot()` calls. There is no brand-mixing finding here, and one would have been false.

---

## 8. Open questions

Written in the rulings-sitting decision template rather than as narrative. **Neither is resolved here**, per this audit's rule that an ambiguity defaults to "no finding, open question" rather than to whichever reading creates work.

### Q1 — Does PHA-C01's per-section `message()` and `nrow()` requirement apply to a script that pulls nothing?

**Layer:** project, or universal if the script-anatomy rule generalizes.

**Evidence:** PHA-C01 requires numbered sections "one per table/source, each with a `message()` progress line and a `nrow()` confirmation." `r/baseline.R` — the only committed `r/*.R` — has six numbered sections (2 through 7) that are `tribble()` literals carrying neither. It fetches nothing; there is no source to report progress against, and it does emit a `message()` at the write step and a row/section/geography summary in its validation block. `exemplar-script.R`, which does pull, carries both per section as the rule describes.

**Options:**
- **(a)** The rule is already scoped to *pull* sections by its own wording, and `baseline.R` complies. No change to anything.
- **(b)** The rule applies to every numbered section, and `baseline.R` is a violation needing six `message()` lines.
- **(c)** The rule is restated to name its trigger explicitly — a section that fetches or reads external data — so the question cannot recur.

**Blast:** (a) nothing. (b) one file, six lines, plus every future literal-data script. (c) one sentence in two v0 documents.

**Not recorded as a finding.** Reading (a) is available on the rule's existing text, and this audit does not resolve toward the reading that creates work.

### Q2 — Should the standard carry an `hdatools` version floor?

**Layer:** universal for the floor itself; project for each repo's pin.

**Evidence:** G1. This repo pins `hdatools` 0.1.7 (25 exports) while the planned hdatools-usage rules are written against the current package (69 exports). Three of this audit's six pre-confirmed findings — 1, 2, and 3 — trace directly to that gap, and two of them could only be fixed in a version-appropriate form rather than the form specified. The upgrade is a genuine migration: the font mechanism changes (showtext → systemfonts), the accessor and scale surface changes, and the pinned version already emits ggplot2 4.0 deprecation warnings. It is not a lockfile bump, and it needs a re-render the maintainer runs.

**Options:**
- **(a)** The standard states a minimum `hdatools` version; a repo below it is non-compliant until it upgrades.
- **(b)** The standard is written version-agnostically, with per-version guidance wherever the API differs.
- **(c)** The floor is a project-layer setting in each repo's own config, and any rule needing a newer API declares its own floor.

**Blast:** (a) forces an upgrade plus a full re-render in every active R repo before the standard applies anywhere. (b) roughly doubles the hdatools rule text and has to be maintained against two APIs. (c) needs a new config key and makes a rule's applicability repo-dependent, which the checker then has to model.

**Not resolved here.** This is a ruling, and this phase produces evidence.

---

## 9. What this audit changed

Six files, one new file, one new directory README.

| File | Change |
|---|---|
| `_quarto.yml` | `dev: "ragg_png"` added under `knitr: opts_chunk:` (finding 1) |
| `_common.R` | `pha_pal` derived from the package instead of hand-typed (finding 2) |
| `CLAUDE.md` | PHA-E10 corrected (finding 3 / S1) |
| `.claude/skills/new-chapter/SKILL.md` | PHA-E10 corrected; exemplar warning cross-reference added (findings 3 and 4) |
| `.claude/skills/new-chapter/references/conventions.md` | PHA-E10 corrected (finding 3 / S1) |
| `.claude/skills/new-chapter/references/exemplar-chapter.qmd` | Non-compliance banner prepended, 40 insertions and 0 deletions (finding 4) |
| `archive/soh-2026/README.md` | New — declares Tier 3 frozen and out of scope (finding 5) |
| `.claude/r-standards-audit.md` | New — this document |

**Verified by running, not by inspection:** `_common.R` sources clean with `pha_pal` and `cb_pal` byte-identical to their pre-change values; `quarto render burden.qmd` exits 0 and produces no tracked-file churn. No data was pulled and no render output was committed.

**Not changed:** `r/baseline.R`, the six `.qmd` stubs, `renv.lock`, and everything under `archive/soh-2026/` except its new README.
