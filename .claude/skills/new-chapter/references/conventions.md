# Chart, table & narrative digest (chapters)

Condensed from the HDA project conventions (PLAN.md §3/§6/§7 / CLAUDE.md). Read this when
you need the full idiom; the SKILL.md body covers the common path.
`references/exemplar-chapter.qmd` is a complete real fhfh chapter demonstrating figures,
inline scalars, and callouts.

## Chapter anatomy (mandatory order)

`# Title {#sec-slug}` → setup chunk (`source("_common.R")`, `read_rds()` stubs, an
inline-scalar block) → **theme-based takeaway H2s** → alternating figure/table + bullet
blocks → per-section change callout → closing summary/caveat callout.

**Data flow is one-way:** chapters `read_rds()` from `data/` only. **Chapters never call
APIs.** If a section needs data not yet in `data/`, that's a `/new-data-script` task first.

## Chart conventions

- `theme_pha()` + `pha_pal` everywhere; `add_zero_line()`. Static ggplot2 only —
  **no ggiraph/plotly/leaflet** (locked decision).
- **Titles are takeaway sentences** (the finding), matching `fig-cap`. Subtitle =
  geography / units / years.
- For **2–3 series, prefer color-coded bold words in the subtitle** (ggtext `<span
  style='color:#hex'>**word**</span>`) over a legend; match the hexes to the fills.
- Currency: `scales::label_dollar()`; note nominal vs inflation-adjusted in the subtitle.
  Percent: `label_percent(accuracy = 1)` unless precision matters.
- Captions come from **`_common.R` source helpers** (`acs_cap()`, `pums_cap()`, …) — never
  hand-typed source lines, and **never** a cross-ref inside the caption.

## Table conventions

- `kbl(align = "...") |> kable_styling(c("condensed", "striped"), full_width = FALSE)`.
- `formattable::comma` / `percent` for cell formatting.
- Source line via `footnote(general = <caption helper>, general_title = "",
  footnote_as_chunk = TRUE)` — **no cross-refs in the footnote** (gridtext `<a>`-tag error).

Table block pattern (from fhfh `market-rental.qmd`, `tbl-nhpd`):

```r
#| label: tbl-<slug>
#| tbl-cap: "<caption>"
<tbl> <- <obj> |> transmute(<clean, display-named columns>)
<tbl> |>
  kbl(align = "llrrll") |>
  kable_styling(c("condensed", "striped"), full_width = FALSE) |>
  footnote(general = paste0(nhpd_cap(), " <extra note>."),
           general_title = "", footnote_as_chunk = TRUE)
```

## Reliability treatment (secondary-locality + Ashland)

Estimates for the 4 secondary counties and Ashland (place, sumlev 160) always carry
reliability treatment. Pipe the frame's 0–100 `cv` column through `_common.R`'s
`flag_reliability()` (High ≤15 / Medium ≤30 / Low >30), then:

- **Suppress Low cells** (CV > 30): `share = if_else(reliability == "Low", NA_real_, share)`.
- **Footnote Medium cells**; state reliability in a bullet or the callout.
- For small counts (PIT, evictions) present as **counts with volatility caveats, never
  rates**.

`flag_reliability()`, not `hdatools::add_reliability()` — the latter assumes a 0–1 scale and
mislabels small cells.

## Narrative rule

Chapters ship with: **takeaway H2s** (a finding, not a data-topic heading), **2–5 bullet
findings per section** (plain statements each traceable to a figure/table), and **callout
boxes**. **No drafted paragraphs** — bullets specific enough that a human expands them to
prose without reopening the data. Expose a few live numbers via inline `r ...` scalars from
the setup chunk.

## The change callout (signature convention)

Every section leads with **what changed** and organizes by takeaway theme. In pha-update
each section carries a per-section `::: {.callout-note}` **"Since 2022"** box comparing
2020-2024 figures to `baseline_2022` (transcribed from the predecessor's rendered site),
computed inline. Baseline deltas are **narrative + logged, never a `stopifnot()` gate** —
differing vintages make some movement structural. Document apples-to-apples vs
vintage-shifted comparisons in data-notes. (In fhfh this slot was an interview-crosswalk
callout; the skill's config block flexes this per project.)

## Known gotchas

- **No `@fig`/`@tbl`/`@sec` cross-refs inside `labs(caption=)` or kbl `footnote()`** —
  gridtext `<a>`-tag error. Keep all cross-refs in **markdown bullets**.
- **ggplot2 4.0 (S7):** a raw `strip.text = element_text()` override clashes with
  `theme_pha`'s strip element — avoid it, or de-facet.
- **fig-alt on every figure** (`#| fig-alt:`) — full sentence(s) describing content + trend.

## Render

Prepend the R bin path, then `quarto render <section>.qmd` (one section) or `quarto render`
(whole book) from project root. Full renders > ~2 min are Jonathan's to run.
