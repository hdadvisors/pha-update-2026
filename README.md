# Richmond Regional Housing Framework — 2026 Data Update

The 2026 data update to the Richmond Regional Housing Framework, produced by HDAdvisors for the
Partnership for Housing Affordability (PHA). It refreshes the 2022 Framework with the latest data
and reorganizes the findings around the region's main housing themes.

The report is a Quarto book that renders to a website (and, later, a PDF). It covers the PlanRVA
region: Charles City, Chesterfield, Goochland, Hanover, Henrico, New Kent, and Powhatan counties;
the City of Richmond; and the Town of Ashland.

**Live preview (work in progress, not yet public-facing):**
https://hdadvisors.github.io/pha-update-2026/

## What's in here

| Path | What it is |
|---|---|
| `*.qmd` | The report pages (one per section) |
| `r/` | Scripts that pull and prepare the data |
| `data/` | Prepared data files (not shared — see the data note below) |
| `data-out/` | Tidy CSV exports for Azure/PowerBI (public-source data only) |
| `docs/` | The rendered website (this is what GitHub Pages serves) |
| `_common.R` | Shared settings: colors, geographies, caption text, helpers |
| `.claude/skills/` | Two in-repo scaffolding skills — `/new-data-script` and `/new-chapter` — that a Claude Code session can invoke to start a new `r/` script or `.qmd` chapter in the project's house style |
| `PLAN.md` | The full build plan and running log — the source of truth |
| `CLAUDE.md` | How work sessions are run |
| `archive/soh-2026/` | The earlier State of Housing slide work, kept for reference |

## How the data works

Data flows one way: the scripts in `r/` do all the data pulling and cleaning and save the results
into `data/`. The report pages only *read* those saved files — they never pull data themselves.
This keeps renders fast and the numbers reproducible.

`data/` is not committed to the repo (Census pulls are large; MLS and CoStar data are licensed and
can't be shared publicly). To recreate the data files, run the scripts in `r/`. The one exception is
`data/raw/README.md`, which tells you exactly what MLS and CoStar exports to drop in.

## Running the report yourself

**You need:** R 4.6.0, Quarto, and the `renv` package. (The project's packages are locked to R
4.6.x — older R versions won't load them.)

1. **Restore the R packages** (first time only — see the plain-language guide below):
   ```r
   renv::restore()
   ```
2. **Render the report.** R isn't on the Windows PATH by default, so point to it first:
   ```bash
   export PATH="/c/R/R-4.6.0/bin:$PATH"
   quarto render
   ```
3. Open `docs/index.html` in a browser.

   > Tip: to avoid step 2's PATH line every time, add `C:\R\R-4.6.0\bin` to your
   > Windows PATH permanently (System → Environment Variables → Path → New).

---

## renv, in plain terms (for teammates)

This project uses **renv** to make sure everyone runs the exact same versions of every R package.
Think of it as a shared, project-specific package list so the report builds the same on your machine
as on anyone else's. You mostly don't have to think about it. Here's all you need:

**When you first open the project (or after someone adds a package):**
```r
renv::restore()
```
This reads the shared package list (`renv.lock`) and installs the right versions into a private
library just for this project. Run it and wait — it can take a while the first time. That's it;
you're ready to render.

**If you add or update a package** (e.g. you wrote a new script that needs one):
```r
renv::snapshot()
```
This updates the shared list so the next person gets your package too. Commit the changed
`renv.lock` along with your work.

**If you see a package error** — something like *"there is no package called ..."* or a version
complaint when you render:
1. Run `renv::restore()` first. Nine times out of ten that fixes it (your library drifted from the
   shared list).
2. Still stuck? Run `renv::status()` — it tells you what's out of sync in plain-ish language.
3. If a script genuinely needs a new package, `install.packages("thepackage")`, then
   `renv::snapshot()` to record it, then commit `renv.lock`.

**What not to worry about:** the `renv/` folder and `renv.lock` file are managed automatically —
don't hand-edit them. The private package library lives inside the project and is ignored by git, so
it never bloats the repo.

---

## More detail

- **[PLAN.md](PLAN.md)** — the build plan, dataset inventory, methodology, and dated progress log.
- **[CLAUDE.md](CLAUDE.md)** — session conventions and run commands.
- **[data/raw/README.md](data/raw/README.md)** — exactly what MLS and CoStar exports to provide.
