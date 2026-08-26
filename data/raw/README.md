# Raw data drops — MLS & CoStar export spec

This folder holds the **only manually provided data** in the project. Everything else
(Census ACS/PUMS/PEP/decennial, CHAS, HUD, FRED, OEWS, etc.) is pulled programmatically by
the `r/` scripts. Bright MLS and CoStar are licensed and cannot be pulled via API, so
Jonathan exports them by hand and drops them here.

**These files are gitignored** (licensed, large). Only this README is committed. The
processed CSVs derived from them (`data-out/mls_*`, `data-out/costar_*`) are also gitignored
and delivered to PHA privately (Drive/Azure) — see the root `.gitignore` and `README.md`.

Drop files exactly as exported (native column names, native format). The `r/mls.R` and
`r/costar.R` scripts clean and reshape them — **do not pre-edit the exports**.

> These can be pulled any time before **Task 4** (Market data). Ping Jonathan if the export
> UI has changed and a field below is no longer available.

---

## 1. Bright MLS — for-sale residential market

**Folder:** `data/raw/mls/`

**Geographies (one series each):**

| Tier | Localities |
|---|---|
| Primary (required) | Chesterfield, Hanover, Henrico, Richmond city |
| Secondary (required) | Charles City, Goochland, New Kent, Powhatan |
| Regional total (required) | Sum/aggregate of the 8 localities above |
| Ashland town (if separable) | Bright may not break Ashland out from Hanover — include only if the platform offers it; otherwise Ashland's summary uses Hanover as proxy, noted in the text |

**Metrics (monthly, one value per locality × month):**

- Closed sales (count)
- Median sale price
- New listings (count)
- Active listings / inventory (count)
- Median days to sell (days on market)
- Months of supply (if available)
- Median sale-to-list price ratio (if available)
- Median sale price by structure type (SF detached / attached / condo) — if the platform
  exports it cleanly; otherwise skip

**Date range:** monthly, **January 2016 → latest available month** (2016 start anchors the
long trend and the 2022 baseline; latest month drives the "since 2022" change narrative).

**Format:** CSV or XLSX as exported. Preferred shape is **one file per metric**, columns =
years, rows = months (the standard Bright monthly-summary layout — matches the archived SOH
exports), **per locality**. Name files so locality and metric are unambiguous, e.g.:

```
data/raw/mls/mls_<locality>_<metric>.csv
   e.g. mls_henrico_median_sale_price.csv, mls_richmond_active_listings.csv
```

A single combined long file (`year, month, locality, metric, value`) is also fine if the
export tool produces one — note which shape you used so `r/mls.R` reads it correctly.

---

## 2. CoStar — multifamily rental market

**Folder:** `data/raw/costar/`

**Geographies:**

- Richmond MSA / market total (required)
- Submarkets, if available (used to approximate locality-level rental conditions in the
  local summaries — CoStar submarkets do not align to county lines; that caveat goes in the
  text)

**Metrics (quarterly market time series — native CoStar workbook columns, keep as-is):**

`Period`, `Inventory Bldgs`, `Inventory Units`, `Inventory Avg SF`, `Asking Rent Per Unit`,
`Asking Rent Per SF`, `Asking Rent % Growth/Yr`, `Effective Rent Per Unit`,
`Effective Rent % Growth/Yr`, `Effective Rent Concessions %`, `Vacancy Units`,
`Vacancy Percent`, `Vacancy % Growth/Yr`, `Occupancy Percent`, `Absorption Units`,
`Under Construction Bldgs`, `Under Construction Units`, `Deliveries Bldgs`,
`Deliveries Units`.

(This is the full multifamily analytics column set CoStar exports; the scripts use the
subset they need. Include all columns rather than pre-trimming.)

**Date range:** quarterly, **2015 Q1 → latest available quarter** (include the current QTD
row if present; `r/costar.R` filters `QTD` rows out).

**Format:** XLSX as exported by CoStar (the native workbook — includes an embedded
sub-header row that `r/costar.R` already handles). Name files clearly:

```
data/raw/costar/costar_market_quarterly.xlsx     # market-level quarterly time series
data/raw/costar/costar_submarkets_quarterly.xlsx # submarket breakdown, if pulled
```

---

---

## 3. Eviction filings — LSC Civil Court Data Initiative

**Folder:** `data/raw/evictions/`

**Source:** Legal Services Corporation Civil Court Data Initiative, `civilcourtdata.lsc.gov`. Methodology: https://civilcourtdata.lsc.gov/about/methodology.

**Coverage:** 4 primary localities only (Chesterfield, Henrico, Hanover, Richmond city). Eviction data for the 4 secondary localities is not used in this report. Ashland cannot be separated from Hanover County — the town uses the same county court system and no town-level extract exists.

**Fields:** `month_start_date`, `jurisdiction`, `filings_count`, `percent_of_historical_average`, `defaults_count`, `defaults_comparison`.

**Date range:** monthly, 2016-01 through 2026-06.

**Downloaded:** 2026-08-20. One CSV per locality, named `<locality>-virginia-8-20-2026.csv`.

**Needed by:** Phase 5 (`r/evictions.R`). Note in `data-notes.qmd` that eviction figures cover the 4 primary localities only and that Ashland is not separable from Hanover.

---

---

## 4. Virginia Housing LIHTC — property listing and project rankings

**Folder:** `data/raw/lihtc/`

**Source:** Virginia Housing (VHDA), internal data request. Not publicly downloadable; Jonathan obtained directly.

**Files:**

| File | Description |
|---|---|
| `vh-lihtc-property-listing.xlsx` | Full statewide LIHTC property listing as of 2025-02-13. One row per property, 1,479 statewide. |
| `2025 FINAL RANKINGS- Board Approved.pdf` | Virginia Housing Board-approved project rankings for the 2025 competitive LIHTC cycle. |
| `2024 Final Rankings.pdf` | Board-approved rankings for the 2024 cycle. |
| `2023 Final Rankings.pdf` | Board-approved rankings for the 2023 cycle. |

**Property listing columns (xlsx, one header row — read with `skip=1`):**

`Property Name`, `VHDA#`, `Street Address`, `City`, `Zip`, `Jurisdiction`, `Tax Credit Units`, `Total Units`, `Target Type`, `Cycle Name`, `Building Type`, `Has Rental Assistance?*`

- `Tax Credit Units` — units receiving the tax credit subsidy.
- `Total Units` — all units in the development (may exceed tax credit units).
- `Target Type` — General, Elderly, PWD (persons with disabilities), or Homeless.
- `Cycle Name` — year and credit type, e.g. "2024 9% Competitive" or "2024 4% Tax Exempt". Goes back to 1990.
- `Has Rental Assistance?*` — logical; indicates layered project-based rental assistance.

**Region coverage:** 231 properties in the 4 primary localities (Chesterfield 37, Hanover 10, Henrico 56, Richmond City 128). The 4 secondary localities (Charles City, Goochland, New Kent, Powhatan) have no LIHTC properties in the listing. `Jurisdiction` values use the full locality name ("Chesterfield County", "Richmond City", etc.).

**Rankings PDFs purpose:** The 2023–2025 rankings capture recently funded projects that are not yet in NHPD. `r/assistance.R` uses the property listing for the unit inventory; the rankings PDFs are reference documents for identifying pipeline projects and confirming regional credits. They are not machine-read by a script — relevant regional projects should be noted in the data-notes caveat on NHPD recency.

**Needed by:** `r/lihtc.R` and `r/assistance.R` (see TODO.md, consolidated rental assistance).

---

## Checklist before handing off to Task 4

- [ ] MLS: all 8 localities + regional total, monthly 2016–latest, metrics above
- [ ] MLS: file shape (per-metric-wide vs. combined-long) noted here or in the handoff
- [ ] CoStar: market quarterly workbook, 2015 Q1–latest, full column set
- [ ] CoStar: submarket workbook if available
- [ ] Files dropped in `data/raw/mls/` and `data/raw/costar/` (not pre-edited)
