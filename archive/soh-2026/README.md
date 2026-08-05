# archive/soh-2026 — frozen

**This directory is a frozen deliverable. Nothing in it is maintained, and nothing in it is
in scope for any code standard, audit, linter, or formatter.** Read it for provenance; do not
edit it, do not bring it into compliance, and do not treat anything in it as an example.

## What this is

The delivered assets for the 2026 State of Housing presentation, archived wholesale when this
repo was scaffolded so the 2026 Data Update could start from a clean tree without losing the
prior cycle's working material.

| Path | Contents |
|---|---|
| `scripts/` | Three chart scripts — `demographics.R`, `market-rental.R`, `market-sale.R` |
| `data/` | Eight source exports: CoStar multifamily and vacancy, five Bright MLS extracts, and a Census housing-unit estimates workbook |
| `img/` | Seven delivered chart PNGs |
| `2026 SOH Presentation - Data Slides.pptx` | The delivered deck |

## Why it is out of scope

These files were written for a slide deck, against an older `hdatools`, before this project
had conventions. They will not match the current standard and are not supposed to. The
specific things a sweep will flag, so nobody re-investigates them:

- **Nine `theme_pha(base_size = N)` calls** with the size hardcoded — two at 50 in
  `demographics.R`, two at 60 in `market-rental.R`, five at 60 in `market-sale.R`. Slide
  canvases are far larger than a report figure, so these values were correct for their target
  and are meaningless outside it. The current rule is to let the theme detect the output
  format rather than hardcode a size, which is a rule about report figures.
- **Standalone `Rscript` chart scripts writing PNGs**, rather than live chunks in a `.qmd`.
  That is the delivery shape a slide deck needs, not a defect.
- **Hand-written source lines and palette values** predating this repo's `_common.R` caption
  helpers and `pha_pal`.

None of the above is evidence of a pattern in the live pipeline. The live pipeline —
`_common.R`, `r/*.R`, the chapter `.qmd` files, and `_quarto.yml` — is audited separately and
contains no `theme_*()` calls at all. See [`.claude/r-standards-audit.md`](../../.claude/r-standards-audit.md),
which declares this directory Tier 3 and excludes it from every count.

## If you need something from here

Copy the value or the approach into a new file under `r/` and bring *that* file up to
standard. Do not edit in place, and do not scaffold a new script or chapter from these.
