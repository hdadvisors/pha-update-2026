---
name: new-chapter
description: >
  Scaffold a new Quarto section/chapter .qmd following an HDA Quarto book's chapter
  anatomy (title + setup chunk reading .rds → takeaway-sentence H2s → alternating
  figure/table + bullet blocks → per-section change callout → closing summary). Use
  whenever creating a new report chapter or section in an HDA housing report
  (pha-update-2026, fhfh, or similar Quarto book). Trigger on "new chapter", "scaffold
  <section>.qmd", "start the demand/ownership/rental/gaps/burden section".
---

# new-chapter

Scaffold a new chapter `.qmd` that matches the target project's chapter anatomy, theming,
and narrative rules. This skill is **project-agnostic**: it carries the shared HDA chapter
structure but reads the *specific* project's palette, theme, geographies, caption helpers,
and narrative convention from that project's own docs at invocation. Nothing
project-specific is hardcoded here — that keeps the skill portable across HDA reports.

**Chapters consume data only.** They `read_rds()` from `data/`; they never call APIs.
If the data a section needs isn't in `data/` yet, that's a data-script task first
(`/new-data-script`), not a chapter task.

## How to use this skill

1. **Populate the project-config block** (below) from the project's docs.
2. **Emit the chapter skeleton**, substituting config values, adapted to the section the
   user named (its data sources, its takeaway themes from the section plan).
3. **Write it to `<section>.qmd`** and remind the user of the narrative + render workflow.

`references/exemplar-chapter.qmd` is a complete real fhfh chapter (figures, inline scalars,
callouts). `references/conventions.md` digests the chart/table + narrative rules. Read them
for the full idiom when needed.

## Step 1 — Populate the project-config block

Read the target project's `CLAUDE.md`, `PLAN.md` (chapter-anatomy + section-content plan +
narrative rule), and `_common.R` (theme, palette, caption helpers, `flag_reliability()`),
and fill:

```
### PROJECT CONFIG (fill from CLAUDE.md / PLAN.md / _common.R before scaffolding)
Setup source        : <e.g. source("_common.R")>
Theme + palette      : <e.g. theme_pha() + pha_pal (6 hexes) ; add_zero_line()>
Palette anchors      : <named hexes for ggtext subtitle spans, e.g. pha_pal[1] green, [6] dark blue>
Geography constants  : <rr/pha/secondary/ashland/virginia + PUMS sets, from _common.R>
Caption helpers      : <acs_cap/pums_cap/chas_cap/... from _common.R — use these, not literals.
                        Derived/assembled data (e.g. gaps) has no single helper: cite the
                        underlying sources' helpers (e.g. pums_cap() + ami_cap())>
Reliability treatment: <flag_reliability(cv 0-100) on secondary-locality + Ashland; suppress
                        Low (CV>30), footnote Medium>
Change-callout        : <this project's per-section callout — e.g. pha "Since 2022" callout-note
                        comparing to baseline_2022; fhfh used an interview-crosswalk callout>
Baseline frame        : <e.g. read_rds("data/baseline_2022.rds") ; delta computed inline>
Table style           : <kbl() |> kable_styling(c("condensed","striped")) ; formattable comma/percent>
Cross-ref rule        : <NO @fig/@tbl/@sec inside labs(caption=) or kbl footnote() — gridtext
                        <a>-tag error; keep cross-refs in markdown bullets only>
fig-alt               : <every figure gets #| fig-alt: (posit-dev alt-text skill)>
Section plan          : <the section's scope + takeaway themes from PLAN.md §7 / the task plan>
Section data sources  : <which data/*.rds this section reads>
Commit style          : <type(scope): subject — content(task-N) for a new chapter>
```

If a field isn't in the docs, ask rather than guess.

## Step 2 — Emit the chapter skeleton

Substitute config values. Build takeaway H2s from the section's themes (not data-topic
headings). Alternate figure/table blocks with bullet findings. Canonical anatomy:

````markdown
# <Section title> {#sec-<slug>}

<!-- Purpose: <1-line section purpose>. Narrative rule: takeaway titles + bullet
     findings + callouts only — no drafted prose. -->

```{r}
#| label: setup
#| include: false
source("_common.R")

<obj>      <- read_rds("data/<source>.rds")     # one read_rds() per data source
baseline   <- read_rds("data/baseline_2022.rds") # change-callout baseline (if used)

# Palette anchors — match ggtext subtitle spans to fills
green <- pha_pal[1]; dblue <- pha_pal[6]   # (names/indices from config)

# Inline-scalar block — expose a few numbers for bullet text via `r ...`
<scalar> <- <obj> |> filter(...) |> pull(estimate)
```

## <Takeaway-sentence H2 — a finding, not a topic>

```{r}
#| label: fig-<slug>
#| fig-cap: "<takeaway sentence — the chart's point>"
#| fig-alt: "<full sentence(s) describing the chart's content and trend for screen readers>"

<df> <- <obj> |> <shape the data>

ggplot(<df>, aes(<...>)) +
  geom_<...>() +
  scale_*_continuous(labels = label_dollar()/label_percent()) +
  labs(
    title = "<takeaway sentence — matches fig-cap>",
    subtitle = "<geography / units / years ; ggtext color spans for 2-3 series>",
    caption = <acs_cap("BXXXXX")>,          # caption helper — NEVER a raw @fig/@sec ref
    x = NULL, y = NULL
  ) +
  theme_pha() +
  add_zero_line("y")
```

- **<Bullet finding — a plain statement traceable to the figure above.>**
- <2–5 bullets per section; specific enough to expand to prose without reopening the data.>
- <Inline scalars via `r label_percent()(<scalar>)` where a live number sharpens the point.>

```{r}
#| label: tbl-<slug>
#| tbl-cap: "<table caption>"

<tbl> <- <obj> |> transmute(<clean display columns>)

<tbl> |>
  kbl(align = "<...>") |>
  kable_styling(c("condensed", "striped"), full_width = FALSE) |>
  footnote(general = <caption helper text>, general_title = "", footnote_as_chunk = TRUE)
```

- <Bullets for the table block.>

::: {.callout-note}
## Since 2022
<Plain-language statement of the change vs the baseline frame, computed inline from
`baseline`. Flag vintage-shifted comparisons. This is the signature per-section callout.>
:::

## <Next takeaway H2 …>

<!-- repeat figure/table + bullet blocks; apply reliability treatment to
     secondary-locality/Ashland figures (suppress CV>30, footnote Medium). -->

::: {.callout-note}
## <Closing summary or data caveat>
<Section wrap-up or a data-universe caveat, as the section needs.>
:::
````

## Step 3 — Remind of the workflow

State these back to the user:

- **Narrative rule:** takeaway H2s + 2–5 bullet findings per section + callouts. **No
  drafted paragraphs** — bullets specific enough that a human expands them to prose.
- **Change callout placement:** add the "Since 2022" box to sections that have a comparable
  baseline metric in the frame — not every H2. Sections with no clean 2022 analogue (e.g.
  DOM, inventory) skip it. Confirm the baseline frame's actual columns once `baseline.R` has
  been built (it's keyed metric × geography); until then the setup-chunk selectors are stubs.
- **Reliability:** secondary-locality + Ashland figures always carry `flag_reliability()`
  treatment (suppress CV>30, footnote Medium).
- **Every figure** gets `#| fig-alt:`. **No `@fig`/`@tbl`/`@sec` cross-refs inside
  `labs(caption=)` or kbl `footnote()`** — gridtext throws an `<a>`-tag error; keep
  cross-refs in markdown bullets.
- **ggplot2 4.0 (S7):** avoid raw `strip.text = element_text()` overrides with `theme_pha`
  (class clash) — de-facet if needed.
- **Render:** prepend the R bin path, then `quarto render <section>.qmd` (one section) or
  `quarto render` (whole book) from project root. Full renders > ~2 min are Jonathan's.
- **Commit** per the project's style guide (e.g. `content(task-N): <subject>`).

## Portability note

This skill lives in-repo (`.claude/skills/`) while it proves out. The project-config-block
design lets the same SKILL.md serve fhfh, pha-update-2026, and future HDA reports — the
change-callout field alone flexes between projects (pha's "Since 2022" vs fhfh's interview
crosswalk). Elevating to user-level (`~/.claude/skills/`) needs no rewrite here.
