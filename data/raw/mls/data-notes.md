# MLS raw data notes

Findings from a first-pass inspection of `data/raw/mls/*.csv` before cleaning and geocoding. Covers all 80 files pulled from CVR MLS, close-date filtered, spanning 2019-12-23 through 2026-07-23. See `mls_files_date-ranges.txt` for the declared close-date window of each file.

## Bottom line

No re-export needed. Every issue below is handled in cleaning, not by pulling more data from MLS.

## File structure

- 80 files, 110,450 rows combined.
- Two header signatures (after `mls_rr_2025_07.csv` was manually fixed to drop a duplicate `Address` export field):
  - 27 files use an `Address` column: street only, no city/state/zip.
  - 53 files use an `Address Line` column: usually `"street, City VA Zip"`, but 72 rows within those files lack the city portion.
- `Zip` and `County/City` are 100% populated. `Zip` is always a valid 5-digit string. `County/City` has 8 distinct values; `Charles City County` is the only one with "County" baked into the name (cosmetic, not an error).
- Column missingness elsewhere is all explainable, not a red flag: `Acres` 14% (condos), `Subdivision` 12%, `SqFtTotal` 2%, `Sold Terms`/`Owned By` ~1.8% each.
- No gaps between the 80 declared export windows — coverage is fully contiguous 2020-01-01 through 2026-07-22.

## PID is the best join/dedupe key

`PID` (parcel ID) is far more reliable than matching on address strings, which differ in formatting between CVR and the co-listed networks (abbreviations, casing, missing city, typos). Strip hyphens/spaces to normalize before joining.

- Placeholder values that are **not** usable for matching: `"NO TAX RECORD"`, `"TBD"`, `"Not Yet Assigned"`. Treat these as missing, not as a real key. **Normalization order matters:** check the exclusion list on the raw string _before_ stripping hyphens and spaces. Stripping first turns `"Not Yet Assigned"` into `"NOTYETASSIGNED"`, which escapes the exclusion check and produces false cross-MLS joins. 483 rows carry `PID = "Not Yet Assigned"` (466 CVR, 17 REIN); the buggy order generates 3 confirmed false pairs (different properties sharing a sale date) alongside 16 genuine Leeds Castle Lane / Knockholt Lane new-construction duplicates that are correctly caught by addr+date+price anyway.
- Switching the primary dedupe key from address+date+price to PID+date surfaced **383 additional cross-MLS duplicate pairs** that the address-string method missed entirely. Use PID+date as the primary method going forward; fall back to normalized address+date+price only when PID is missing or a placeholder.

## Cross-MLS duplicates (the main cleanup item)

Since 2021, CVR listings are increasingly co-listed on other regional MLS networks — records with an `ML #` prefix of `REIN` or `BRTVA{CF,HA,HN,RC,GO,NK,PN,CS}` — reaching roughly 7-9% of rows per year by 2022 onward. Many of these are the same sale as a numeric-ML# CVR record, double-counted.

- **1,088 groups** matched cross-MLS by PID+date (vs. 1,031 found by the older address+date+price method — PID catches more).
- **Retain the CVR (numeric ML#) record** when a duplicate is confirmed. Across 1,017 paired cases, CVR has ≥ as many populated fields as its REIN/BRT twin 99.8% of the time. The two fields REIN/BRT records structurally never carry are `Sold Terms` (0% populated) and `Owned By` (1.4%) — that's the whole reason CVR wins.
- **Auto-resolve rule (approved):** if price is within $1,000 and sqft is within 100, treat as the same sale and drop the REIN/BRT twin.
- **Manual-review rule (approved):** if a cross-MLS pair matches on PID/address+date but fails the tolerance above, flag it to a review file rather than resolving it silently. Keep both records unless a human confirms the drop.
- **REIN sale price divergence:** REIN sale prices can differ substantially from CVR for the same closing (e.g., a $77k gap on 7991 Uplands Dr where list price was identical on both records). Likely reflects a different transaction stage captured by REIN. This does not indicate a different property — it reinforces the CVR-wins rule on all conflicts.
- **REIN sqft divergence:** REIN sqft often reflects total building area; CVR sqft reflects finished living area. A 2:1 sqft difference at the same address is not evidence of different properties. Confirmed on 3121 Ponderosa Pine Ln (6,983 vs 3,526 sqft).

**Three outside-tolerance pairs confirmed by manual MLS lookup:**

| CVR ML# | REIN/BRT ML# | Address | Notes | Disposition |
|---|---|---|---|---|
| 2128471 | REIN10401157 | 7991 Uplands Dr, New Kent | List price identical; REIN sale price $77k higher, likely a transaction-stage capture difference; listing agent differs | Drop REIN, keep CVR |
| 2209684 | BRTVAHA2000158 | 10797 Providence Woods Lane, Hanover | REIN sale price $335,000 is a data-entry typo for $435,000; same listing confirmed | Drop REIN, keep CVR |
| 202500335 | REIN10611370 | 3121 Ponderosa Pine Ln | Sqft difference is finished (REIN 3,526) vs total (CVR 6,983); same sale confirmed | Drop REIN, keep CVR |
- **111 groups** that matched on address+date+price exactly turned out to have *disagreeing* PIDs. Not investigated further this session — worth a look before finalizing dedupe logic (could be adjacent-unit coincidences or bad PID data on one side).
- **Exact full-row duplicates:** 42 ML#s (84 rows), all dated 2022-02-10, caused by a one-day overlap between the `mls_rr_2022_01` and `mls_rr_2022_02` export windows. Drop via a plain `ML #` de-dup — no judgment call needed.

## Boundary/export overflow rows

147 rows across the dataset have a Sales Date outside their *own* file's declared close-date window (per `mls_files_date-ranges.txt`). Cause not fully understood — Jonathan's export selection filters on close date, but some rows near each window's edge land outside it anyway.

- 44 of the 147 are already covered by the dedup rules above (mostly the Feb 10, 2022 boundary case).
- **103 are genuinely unique — no duplicate anywhere in the dataset — and should be kept.** No special handling is needed for these: combine all files by actual `Sales Date` (not by each file's declared window), then apply the final analysis-date filter. They pass through on their own.
- A handful of extreme single-row outliers exist (e.g., one row nominally in the Nov–Dec 2020 file dated July 2021). Rare (<0.1% of rows), not systemic — the final analysis-window filter (2020-01-01 to 2026-06-30) will exclude them without any extra logic.

## Address-less BRTVA records

36 rows (all `BRTVAxx`-prefixed) had no value in either address column.

- 14 were resolved immediately: exact match on date+price+zip to a CVR record that does have an address.
- The remaining 22 needed PID matching, fuzzy price/sqft/year matching, and Jonathan's manual research. Final disposition:

**Confirmed duplicate — drop, keep the CVR record:**

| Address-less ML # | Retain CVR ML # | Note |
|---|---|---|
| BRTVAGO2000096 | 2230700 | |
| BRTVANK2000050 | 2219556 | |
| BRTVACF2000588 | 2232279 | |
| BRTVACF2000976 | 2411452 | also keep the separate earlier sale 2109892 for this property — not a duplicate of each other |
| BRTVARC2000104 | 2204178 | price differs 5.8% ($1.3M vs $1.225M), likely a post-close correction; same parcel, same day, same sqft/year built |
| BRTVACF2000312 | 2222426 | source `Sales Price` of $4,000,000 was a **data-entry error** — actual price $400,000, confirmed by matching parcel |
| BRTVAHA2000768 | 2405806 | |
| BRTVAHA2000808 | 2413060 | |
| BRTVAHN2000180 | 2223074 | |

**Same parcel, but a different (legitimate) sale — keep both, not a duplicate:**

| Address-less ML # | Related ML # | Note |
|---|---|---|
| BRTVAHN2000682 | 2032768 | price and sale dates far enough apart to be a separate transaction |

**Same property, confirmed by manual research, but not duplicate transactions — keep both:**

| Address-less ML # | Related ML # / address |
|---|---|
| BRTVAHN2000046 | 2024762 (128 N Elm Ave) |
| BRTVAHN2000066 | 2526875 (4948 Tanfield Dr) |
| BRTVACF2000592 | 2224584 (8730 Nakoda Terrace) |

**No match found by any method — treat as genuinely unique, unrecoverable address:**

- BRTVACF2000106, BRTVACF2000110, BRTVAHN2000078, BRTVAHN2000224, BRTVAGO2000110, BRTVACF2000518, BRTVACF2000946

Of these, `BRTVACF2000588`, `BRTVACF2000518`, `BRTVACF2000592`, and `BRTVACF2000946` originally carried a `PID` value of literally `"NO TAX RECORD"` (not blank) — the source system flagged them as unmatched to a parcel, independent of the address gap.

**Net result:** the address-less gap that can't be geocoded shrinks from 36 down to **7 records** (the "no match found" list above), once cross-MLS duplicates are dropped and same-property-different-transaction records are matched to a usable address.

## Address field for geocoding

- Build a canonical street-address field from `Address`/`Address Line`, stripped of any appended city/state/zip — don't trust either column's format as-is.
- 2,324 rows have a unit/apartment number embedded in the street string itself (e.g., `"Unit#U11"`). Most geocoders handle this fine; strip separately only if parcel-level matching requires it.
- `County/City` holds a **county name**, not necessarily an incorporated place (except Richmond City). Don't pass it as a `city` component to a geocoder — it can mislead lookups for unincorporated addresses.
- Planned geocoding approach: `tidygeocoder::geo(method = "geocodio")` using structured components — `street` (cleaned), `county` (= `County/City`), `state = "Virginia"`, `postalcode` (= `Zip`). Skip the `city` argument entirely; Zip + county is enough for Geocodio to resolve without guessing a place name.

## Recommended combining/cleaning order

1. `rbind` all 80 files (schemas now reconcile to the same 24 fields after the `2025_07` fix).
2. Build canonical address, and numeric fields (price, sqft, beds, baths, year built).
3. Dedupe: PID+date first (falling back to normalized address+date+price when PID is missing/placeholder); auto-resolve within the $1,000 price / 100 sqft tolerance; drop the REIN/BRT twin, keep CVR. Normalize PID by checking placeholders (`NO TAX RECORD`, `TBD`, `Not Yet Assigned`) on the raw string _before_ stripping hyphens and spaces — not after.
4. Route anything that matches but fails the tolerance to a manual-review file — don't resolve silently.
5. Drop the 42 full-row duplicate ML#s from the 2022-02-10 export-boundary overlap.
6. Filter to the analysis window, 2020-01-01 through 2026-06-30.
7. Geocode via `tidygeocoder`/Geocodio using the structured street/county/state/zip components.
