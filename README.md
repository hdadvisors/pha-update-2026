# Richmond Regional Housing Framework — 2026 Data Update

The 2026 data update to the Richmond Regional Housing Framework, produced by HDAdvisors for the Partnership for Housing Affordability (PHA). It refreshes the 2022 Data Update with the latest data and reorganizes the findings around the region's main housing themes.

The report is a Quarto book that renders to a website, and later to a PDF. It covers the PlanRVA region: Charles City, Chesterfield, Goochland, Hanover, Henrico, New Kent, and Powhatan counties; the City of Richmond; and the Town of Ashland.

**Live preview (work in progress, not yet public-facing):** https://hdadvisors.github.io/pha-update-2026/

## Status

In progress. The scaffold, environment, most data scripts, and five of the five regional chapters have content; the PUMS engine, the local summaries, the tracker, and the executive summary are still to come.

The punch list is [TODO.md](TODO.md). Session-by-session history is in [LOG.md](LOG.md).

## What's in here

| Path | What it is |
|------------------------------------|------------------------------------|
| `*.qmd` | The report pages, one per section |
| `r/` | Scripts that pull and prepare the data |
| `data/` | Prepared data files (not shared — see the data note below) |
| `data-out/` | Tidy CSV exports for Azure and PowerBI (public-source data only) |
| `docs/` | The rendered website, which is what GitHub Pages serves |
| `_common.R` | Shared settings: colors, geographies, caption text, helpers |
| `.claude/skills/` | Two in-repo scaffolding skills, `/new-data-script` and `/new-chapter`, that a Claude Code session invokes to start a new `r/` script or `.qmd` chapter in the project's house style |
| `TODO.md` | The punch list — what's left to finish |
| `LOG.md` | The dated session/dev log |
| `METHODOLOGY.md` | Internal data, geography, and scope conventions |
| `CLAUDE.md` | How work sessions are run, and every project convention |
| `archive/soh-2026/` | The earlier State of Housing slide work, kept for reference |

## How the data works

Data flows one way. The scripts in `r/` do all the data pulling and cleaning and save the results into `data/`. The report pages only read those saved files; they never pull data themselves. This keeps renders fast and the numbers reproducible.

`data/` is not committed. Census pulls are large, and the MLS and CoStar data are licensed and cannot be shared publicly. To recreate the data files, run the scripts in `r/`. The one exception is [data/raw/README.md](data/raw/README.md), which states exactly which MLS and CoStar exports to drop in.

## Running the report yourself

You need R 4.6.x, Quarto, and the `renv` package. The project's packages are locked to the R 4.6 series, so older R majors will not load them; any 4.6.x patch release works.

1.  **Restore the R packages.** First time only — see the plain-language guide below.

    ``` r
    renv::restore()
    ```

2.  **Render the report.** R and Quarto are usually not on the Windows PATH, so point to them first. The exact bin paths are machine-specific; use your own R 4.6.x and Quarto install locations.

    ``` bash
    # Example (a laptop with R 4.6.1 and Quarto in Program Files):
    export PATH="/c/Program Files/R/R-4.6.1/bin:/c/Program Files/Quarto/bin:$PATH"
    quarto render
    ```

3.  Open `docs/index.html` in a browser.

To render one section rather than the whole book, name it: `quarto render demand.qmd`. To run a data script, use `Rscript r/<name>.R` from the project root, where `.Rprofile` activates renv.

> Tip: to avoid step 2's PATH line every time, add your R 4.6.x `\bin` and Quarto `\bin` folders to your Windows PATH permanently, through System, then Environment Variables, then Path, then New.

## renv

This project uses **renv** to make sure everyone runs the exact same versions of every R package. It creates a shared, project-specific package list so the report builds the same regardless of machine.

**When you first open the project, or after someone adds a package:**

``` r
renv::restore()
```

This reads the shared package list in `renv.lock` and installs the right versions into a private library just for this project. Run it and wait — it can take a while the first time. After that you are ready to render.

**If you add or update a package**, for example because you wrote a new script that needs one:

``` r
renv::snapshot()
```

This updates the shared list so the next person gets your package too. Commit the changed `renv.lock` along with your work.

**If you see a package error** — something like *"there is no package called ..."* or a version complaint when you render:

1.  Run `renv::restore()` first. Nine times out of ten that fixes it, because your library drifted from the shared list.
2.  Still stuck? Run `renv::status()`, which reports what is out of sync.
3.  If a script genuinely needs a new package, run `install.packages("thepackage")`, then `renv::snapshot()` to record it, then commit `renv.lock`.

**What not to worry about:** the `renv/` folder and the `renv.lock` file are managed automatically, so do not hand-edit them. The private package library lives inside the project and is ignored by git, so it never bloats the repo.

## More detail

- [**TODO.md**](TODO.md) — the punch list of what's left.
- [**LOG.md**](LOG.md) — the dated session history.
- [**METHODOLOGY.md**](METHODOLOGY.md) — internal data, geography, and scope conventions.
- [**CLAUDE.md**](CLAUDE.md) — session conventions and project standards.
- [**data/raw/README.md**](data/raw/README.md) — exactly which MLS and CoStar exports to provide.
