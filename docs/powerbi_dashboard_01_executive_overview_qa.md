
# Power BI Dashboard QA — Page 01: Executive Overview

**Project:** Order-to-Cash Intelligence Platform  
**Report:** `powerbi/Order_to_Cash_Intelligence.pbix`  
**Page:** `01 Executive Overview`  
**Phase:** Step 7.4 — Task 1  
**Status:** FUNCTIONAL PASS — visual polish items noted below  
**Data:** Historical Olist Brazilian E-Commerce records (2016–2018)  
**Currency:** Brazilian real (BRL / R$)

## 1. Purpose and scope

The Executive Overview summarizes order activity, delivery reliability, recorded item and freight value, recorded payment volume, and source-record financial reconciliation. It is an interactive historical analysis, **not** a live operating report, settlement statement, or recognized-revenue report.

The six KPI cards and four charts have been tested against full-history and Q1 2018 delivered-purchase-cohort baselines. The user confirmed completion of the Power BI DAX, independent PostgreSQL, slicer, and interaction tests.

## 2. Semantic model and filter conventions

- Source: PostgreSQL `olist_analytics`, `analytics` layer.
- Power BI model: 12 imported analytical tables; 20 active, single-direction dimension-to-fact relationships.
- Shared filters: `dim_purchase_date[date]` and `dim_order_status[order_status]`.
- Purchase Month Label: `dim_purchase_date[Purchase Month Label]`, sorted by `dim_purchase_date[Purchase Month Sort]`.
- The payment trend is grouped by the **associated order's purchase date**, not a verified payment-event or settlement timestamp.
- Product and Seller dimensions filter the item fact; they do not automatically filter the Orders or Payments facts. These slicers are intentionally absent from this page.
- Review Date is unrelated to the measures used on this page.
- No raw fact-to-fact relationship or bidirectional relationship was added to support the visuals.

## 3. Page and visual specification

- Canvas: 1280 × 720, 16:9.
- Page background: `#F5F7FA`.
- Main heading: `Order-to-Cash Intelligence`.
- Font: Segoe UI (or the report's chosen consistent sans-serif).
- Heading/text: `#17324D`.
- Positive/primary accent: `#117F7A`.
- Secondary chart accent: `#567FA6`.
- Warning: `#D79A5C`; critical exception: `#C35656`.
- Visual background: `#FFFFFF`; subtle borders: `#E1E8EF`.
- Six KPI cards are displayed in one row, with two time/status slicers above them and four charts in a 2 × 2 arrangement below.

### KPI cards

| # | Display title | DAX measure | Unfiltered expected display |
|---|---|---|---:|
| 1 | Total Orders | `[Total Orders]` | 99,441 |
| 2 | Delivered Orders | `[Delivered Orders]` | 96,478 |
| 3 | On-Time Delivery | `[On-Time Delivery Rate]` | 93.23% |
| 4 | Recorded Item + Freight | `[Recorded Item and Freight Value]` | R$15.84M |
| 5 | Recorded Payments | `[Recorded Payment Volume]` | R$16.01M |
| 6 | Financial Mismatch Rate | `[Financial Mismatch Rate]` | 0.58% |

**Exact underlying monetary baselines:** Recorded Item + Freight = **R$15,843,553.24**; Recorded Payment Volume = **R$16,008,872.12**. The millions-formatted card values are display abbreviations only.

### Filters and controls

| Control | Source field | Style | Default |
|---|---|---|---|
| Purchase Date | `dim_purchase_date[date]` | Between | Full historical period |
| Order Status | `dim_order_status[order_status]` | Dropdown; multi-select | All statuses |
| Clear all slicers | Native Power BI button | Clear slicers | Optional page-level reset |

### Charts

| # | Visual title | Chart | Axis / category | Value |
|---|---|---|---|---|
| 1 | Orders Purchased by Month | Line | `dim_purchase_date[Purchase Month Label]` | `[Total Orders]` |
| 2 | Recorded Payments by Purchase Month | Clustered column | `dim_purchase_date[Purchase Month Label]` | `[Recorded Payment Volume]` |
| 3 | Order Status Distribution | Clustered bar | `dim_order_status[order_status]` | `[Total Orders]` |
| 4 | Financial Reconciliation Status | Clustered bar | `fact_orders[reconciliation_status]` | `[Total Orders]` |

Optional tooltip measures include `[Delivered Orders]` for the monthly Orders chart and `[Payment Entries]` for the monthly Payments chart. These should not be mistaken for additional Y-axis series.

## 4. Full-history numerical validation

| KPI or status | Expected result | Outcome |
|---|---:|---|
| Total Orders | 99,441 | PASS |
| Delivered Orders | 96,478 | PASS |
| On-Time Delivery Rate | 93.23% | PASS |
| Recorded Item + Freight | R$15,843,553.24 | PASS |
| Recorded Payment Volume | R$16,008,872.12 | PASS |
| Financial Mismatch Rate | 0.58% | PASS |
| Reconciliation status: MATCH | 98,089 | PASS |
| Reconciliation status: MISMATCH | 576 | PASS |
| Reconciliation status: MISSING_ITEMS | 775 | PASS |
| Reconciliation status: MISSING_PAYMENTS | 1 | PASS |
| Reconciliation status: MISSING_BOTH | 0 | PASS |
| Canceled orders | 625 | PASS |

The order-reconciliation status population totals **99,441 orders**. The monthly Orders series sums to **99,441**, and the monthly Recorded Payments series sums to **R$16,008,872.12** over the unfiltered historical period.

## 5. Q1 2018 delivered-purchase-cohort validation

**Purchase Date:** January 1–March 31, 2018 (inclusive).  
**Order Status:** `delivered`.

| Metric | Expected result | Outcome |
|---|---:|---|
| Total Orders | 20,627 | PASS |
| Delivered Orders | 20,627 | PASS |
| On-Time Delivery Rate | 87.12% | PASS |
| Recorded Item + Freight | R$3,164,654.11 | PASS |
| Recorded Payment Volume | R$3,165,795.74 | PASS |
| Financial Mismatch Rate | 0.62% | PASS |
| Reconciliation: MATCH | 20,499 | PASS |
| Reconciliation: MISMATCH | 128 | PASS |

The monthly charts restrict to January, February and March 2018 under the Q1 slicer selection. The user confirmed that the filtered card and chart results matched previously reconciled DAX and SQL baselines.

## 6. Interaction configuration

| Selected source visual | Targets | Behavior |
|---|---|---|
| Purchase Date slicer | All six cards and all four charts | Filter |
| Order Status slicer | All six cards and all four charts | Filter |
| Monthly Orders | Six cards and the other three charts | Filter |
| Monthly Payments | Six cards and the other three charts | Filter |
| Order Status Distribution | Six cards and the other three charts | Filter |
| Financial Reconciliation Status | All other visuals | None |

The Reconciliation Status chart has no outgoing cross-visual filtering because its status column belongs to `fact_orders`; it cannot consistently scope the separate item and payment facts through the approved model. Incoming slicer filtering remains enabled.

### Interaction test results

- Full-history default view: PASS.
- Delivered status selection returns 96,478 Total Orders: PASS.
- Selecting monthly trend marks filters compatible target visuals: PASS.
- Clicking a reconciliation-status bar does not alter other cards/charts: PASS.
- Q1 2018 delivered slicers return the independently verified population: PASS.
- Clearing chart selections and resetting slicers restores historical totals: PASS.
- Native Clear all slicers button added to the page: OBSERVED in screenshot. Keep it if usability and positioning remain satisfactory.

## 7. Independent validation and audit artifacts

- DAX validation: monthly aggregation, source order-status counts, reconciliation-status counts, full-history baseline, and Q1 delivered cohort.
- PostgreSQL validation: `sql/42_powerbi_executive_overview_validation.sql`.
- KPI requirements coverage: `docs/powerbi_kpi_coverage_final_after_task11.csv` (55 of 55 documented KPI requirements marked PASS after Task 11).
- Earlier financial, fulfillment, customer, payment, item, geography, and review reconciliation SQL files provide supporting evidence for these values.

**Outcome:** The user reported successful DAX/SQL reconciliation and all interaction checks for Page 01. This report documents those confirmed outcomes; it does not imply a fresh programmatic inspection of the local PBIX file.

## 8. Visual QA from the supplied dashboard screenshot

### Confirmed

- The complete 1280 × 720 report page displays six aligned KPI cards and the four intended charts.
- All six headline card values match their full-history expected displays.
- Both slicers are visible and the Order Status slicer reads `All`.
- All chart titles are visible; the white-card/light-background design is consistent.
- A Clear all slicers button is visible.
- The dashboard is compact enough that an additional methodology footer should **not** be forced onto this page.

### Optional presentation refinements before portfolio screenshots

1. **Hide editing gridlines:** Turn off View → Gridlines (and optionally Snap to grid when layout work is finished) so the dotted editing grid does not appear in screenshots.
2. **Show month labels:** In both monthly charts, enable the X-axis labels. Reduce text size or label density if needed, and confirm chronological sorting. The supplied screenshot does not visibly display month labels, making the time series difficult to interpret on its own.
3. **Improve exact counts in status charts:** Set bar-chart data-label Display units to `None` where practical. In the screenshot, small statuses such as 625 canceled orders and 576 mismatches are rounded to `1K`; full precision should at least be available in tooltips.
4. **Reduce redundant auto-generated text:** The sentences under the monthly chart titles restate the fields (for example, `Total Orders and Delivered Orders by Purchase Month Label`). Remove or simplify these subtitles if they are not needed; keep clear chart titles and informative tooltips.
5. **Inspect scrollbars:** Narrow charts can show category-axis or horizontal scrollbars. Ensure users can access all eight order statuses, all nonzero reconciliation statuses, and the entire monthly history. A compact scrollbar is acceptable if labels and tooltips remain legible.
6. **Review Clear all slicers button placement:** The blue button is prominent at the top. Keep it aligned with the filter row, without covering the heading or crowding date inputs.
7. **Treat sparse ending periods carefully:** The historical extract has limited observations near its boundaries. Apparent sharp end-of-series declines should not be described as confirmed real-world marketplace performance declines without checking dataset completeness.

The items above are presentation enhancements, not known numeric or model-integrity failures. Once refined, recheck the layout and take one clean screenshot with the editing grid hidden.

## 9. Methodology and interpretation notes

The following explanation belongs in this QA file and project README because the 1280 × 720 page is already crowded:

> Historical marketplace records (2016–2018). Recorded item values, freight charges and payment entries are descriptive source totals, not recognized revenue or confirmed settlement. The payment trend uses associated order purchase dates. On-time delivery excludes delivered-status orders without evaluable delivery dates. Financial mismatches are source-record differences, not confirmed fraud, recoverable losses or overcharges.

The source extract covers historical data only and does not imply current performance.

## 10. Final sign-off and next phase

**Functional page status:** PASS — according to completed checks reported by the user.  
**Presentation status:** Minor visual refinements recommended; do not block continued project development.  
**Model changes required:** None.  
**New DAX measures required:** None.  
**Next task:** Step 7.4 — Task 2: Order Fulfillment dashboard (Page 02).

**Before portfolio publication:** Save the PBIX, capture a final screenshot without editing gridlines, verify tooltip readability and chart labels, and keep this QA document with the repository.
