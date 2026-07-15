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

## Checklist before handing off to Task 4

- [ ] MLS: all 8 localities + regional total, monthly 2016–latest, metrics above
- [ ] MLS: file shape (per-metric-wide vs. combined-long) noted here or in the handoff
- [ ] CoStar: market quarterly workbook, 2015 Q1–latest, full column set
- [ ] CoStar: submarket workbook if available
- [ ] Files dropped in `data/raw/mls/` and `data/raw/costar/` (not pre-edited)
