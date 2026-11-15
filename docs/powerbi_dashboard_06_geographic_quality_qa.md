
# Power BI Dashboard QA — Page 06: Geographic Coverage & Data Quality

**Project:** Order-to-Cash Intelligence Platform

**PBIX:** `powerbi/Order_to_Cash_Intelligence.pbix`

**Page:** `06 Geographic Coverage and Data Quality`

**Phase:** Step 7.4 — Task 6

**Status:** PASS — Geographic Coverage and Data Quality dashboard validated through DAX G1–G5, PostgreSQL SQL-0 through SQL-5, full-history and Q1 cohorts, geographic ranking comparisons, and interaction QA.

**Source:** PostgreSQL `olist_analytics`, analytics layer

---

## 1. Business Purpose

The dashboard evaluates geographic completeness
and customer-state distribution for the historical
Brazilian marketplace dataset.

It addresses:

- Map-ready order coverage
- Missing geographic references
- Flagged representative coordinates
- Regional order distribution by customer state
- Geographic completeness across four fact tables
- Purchase-month geographic completeness
- Seller geographic reference readiness

The geographic visualization is a native
Power BI horizontal bar chart, not Azure Maps.

The page can be used locally in Power BI Desktop
without publishing to Power BI Service.

---

## 2. Geographic Methodology

Customer geography is derived from matched
ZIP-prefix geographic reference data.

Representative reference coordinates are screened
for suitability but are not exact customer
addresses or delivery GPS locations.

The state-ranking chart uses the customer_state
attribute of the geographic dimension.

Map-ready orders are those linked to geographic
records with has_map_ready_coordinate = TRUE.

Missing and flagged geographic records remain
in the source populations and quality reporting.

No individual customer addresses are displayed.

---

## 3. Semantic Model

Primary geography dimension:
analytics.dim_customer_geography

Relationship key:
customer_location_key

The geography dimension filters:

- fact_orders
- fact_order_items
- fact_payments
- fact_order_reviews

Relationships:
Active, one-to-many, single-direction.

No new fact-to-fact or bidirectional
relationships were added.

New disconnected table:
Geo Fact Type

Rows:
4

Columns:
Fact, Sort

Relationships:
None

---

## 4. Page Configuration

Canvas:
1280 x 720

Aspect ratio:
16:9

Title:
Geographic Coverage & Data Quality

Theme:
- Navy: #17324D
- Teal: #117F7A
- Blue: #567FA6
- Warning Amber: #D79A5C
- White: #FFFFFF
- Background: #F5F7FA
- Borders: #E1E8EF

Slicers:
- dim_purchase_date[date]
- dim_order_status[order_status]

Reset control:
Clear all slicers button.

No Azure Maps or Power BI online workspace
is required for this report page.

---

## 5. Six KPI Cards

| Card | DAX Measure | Full Dataset |
|---|---|---:|
| Total Orders | [Total Orders] | 99,441 |
| Map-Ready Orders | [Map-Ready Orders] | 99,162 |
| Map-Ready Order Share | [Map-Ready Order Share] | 99.72% |
| Missing Geo Reference | [Orders Without Geo Reference] | 278 |
| Flagged Coordinates | [Orders With Flagged Customer Coordinates] | 1 |
| Map-Ready Sellers | [Map-Ready Sellers] | 3,088 |

Supporting measure:

[Geo Referenced Orders (Dashboard)]

Expected:
99,163 orders.

---

## 6. Business Definitions

### Geo-Referenced Orders

Orders linked to a matched geographic reference.

Includes screened map-ready records and
referenced records with flagged coordinates.

### Map-Ready Orders

Orders whose associated customer geographic
reference is approved for geographic analysis.

### Map-Ready Order Share

Map-Ready Orders / Total Orders.

### Missing Geo Reference

Orders without a matched geographic reference.

### Flagged Coordinates

Orders associated with a screened geographic
reference marked as a coordinate outlier.

### Map-Ready Sellers

Seller geographic readiness calculated from
the Seller dimension.

It is not automatically restricted by an
order purchase-date filter.

---

## 7. Chart Inventory

### Chart 1: Top 10 Customer States by Map-Ready Orders

Type:
Clustered horizontal bar chart.

Y-axis:
dim_customer_geography[customer_state]

X-axis:
[Map-Ready Orders]

Tooltips:
- [Total Orders]
- [Map-Ready Order Share]

Visual-level filter:
Top 10 by [Map-Ready Orders].

Sorting:
Descending Map-Ready Orders.

The state chart reports regional activity using
the customer-state dimension attribute.

It does not depict exact locations.

### Chart 2: Map-Ready Order Share by Purchase Month

Type:
Line chart.

X-axis:
dim_purchase_date[Purchase Month Label]

Y-axis:
[Map-Ready Order Share]

Tooltips:
- [Total Orders]
- [Map-Ready Orders]
- [Orders Without Geo Reference]

Monthly percentages must be recalculated
using each month's order population.

### Chart 3: Map-Ready Coverage by Fact

Type:
Clustered horizontal bar chart.

Category:
Geo Fact Type[Fact]

Value:
[Map-Ready Share by Fact (Dashboard)]

Tooltips:
- [Map-Ready Records by Fact (Dashboard)]
- [Total Records by Fact (Dashboard)]

The four fact types use their own record-grain
denominators.

### Chart 4: Order Geographic Exceptions

Type:
Clustered horizontal bar chart.

Category:
dim_customer_geography[Geographic Quality Category]

Value:
[Total Orders]

Visual-only filters:
- Missing ZIP Reference
- Flagged Coordinate

No geographic category is excluded
at page or report level.

---

## 8. Full-Dataset Baselines

| Fact | Total | Without Reference | Flagged | Map-Ready | Share |
|---|---:|---:|---:|---:|---:|
| Orders | 99,441 | 278 | 1 | 99,162 | 99.72% |
| Order Items | 112,650 | 302 | 1 | 112,347 | 99.73% |
| Payments | 103,886 | 287 | 1 | 103,598 | 99.72% |
| Reviews | 99,224 | 279 | 1 | 98,944 | 99.72% |

Orders partition:
278 + 1 + 99,162 = 99,441.

Geographically referenced orders:
99,162 + 1 = 99,163.

Missing geography dimension links:
0.

Other / Inspect fact records:
0.

---

## 9. Geography Dimension Baselines

Customer geography dimension rows:
15,034.

Map-ready representative geography rows:
14,876.

Invalid map-ready latitude/longitude records:
0.

Seller dimension rows:
3,095.

Sellers with matched geographic reference:
3,088.

Previously validated map-ready sellers:
3,088.

Seller geographic reference coverage:
99.77%.

The reference-match and map-ready definitions
are distinct even when their counts coincide.

---

## 10. Q1 2018 Delivered-Purchase Cohort

Purchase Date:
January 1 through March 31, 2018.

Order Status:
delivered.

| Fact | Total | Without Reference | Flagged | Map-Ready | Share |
|---|---:|---:|---:|---:|---:|
| Orders | 20,627 | 59 | 0 | 20,568 | 99.71% |
| Order Items | 23,572 | 62 | 0 | 23,510 | 99.74% |
| Payments | 21,424 | 62 | 0 | 21,362 | 99.71% |
| Reviews | 20,630 | 58 | 0 | 20,572 | 99.72% |

Orders partition:
59 + 0 + 20,568 = 20,627.

Map-ready sellers:
3,088, independent of purchase cohort.

---


## 11. Top 10 Customer-State Ranking Validation

DAX reference:
Check G5.

PostgreSQL reference:
SQL-2 in
`sql/47_powerbi_geographic_dashboard_validation.sql`.

**Validation status: PASS**

DAX G5 and SQL-2 were compared using
the full historical dataset and the Q1 2018
delivered-order purchase cohort.

The published dashboard retains the Top 10
state filter and descending order ranking.

### Full-Dataset Screenshot Evidence

The following four states and counts are
directly visible in the archived Page 06 screenshot.

| Visible Rank | State | Map-Ready Orders |
|---|---|---:|
| 1 | SP | 41,731 |
| 2 | RJ | 12,839 |
| 3 | MG | 11,624 |
| 4 | RS | 5,462 |

The screenshot displays four ranked categories
before scrolling.

The remaining six ranked categories are available
in the Power BI visual and are reproducible
using DAX G5 and PostgreSQL SQL-2.

Their individual values have not been copied
into this public QA document because the complete
ten-row query output was not archived here.

No values have been invented.

### Q1 2018 Delivered Cohort

The standard cohort uses:

- Purchase Date: 2018-01-01 through 2018-03-31
- Order Status: delivered

The Q1 Top 10 state comparison was included
in the completed DAX/SQL validation.

### Ranking Interpretation

Top 10 state counts are derived from
map-ready Orders fact records associated
with customer geography.

The Top 10 sum does not necessarily equal
the full map-ready order population,
because orders from other states remain
outside the ranked subset.

State-level geographic analysis does not
identify exact customer residential or
delivery locations.

### Evidence References

- `powerbi/dax/15_geographic_dashboard_helpers.dax`
- `sql/47_powerbi_geographic_dashboard_validation.sql`
- `assets/screenshots/06_geographic_coverage_quality.png`

---

## 12. DAX Reference

File:
powerbi/dax/15_geographic_dashboard_helpers.dax

Contents:

- Four initial geographic helper measures
- Geographic Quality Category
- Geographic Quality Sort
- Geo Fact Type disconnected table
- Three fact-comparison measures
- Verified full and Q1 baselines
- Customer-state chart methodology

---

## 13. DAX Validation

### G1 — Full and Q1 Baselines

Expected:
All geographic metrics match known baselines.

Status: PASS — validated against the documented baseline and independent reconciliation checks.

### G2 — Geographic Partitions

Expected:
Four zero differences and four TRUE values.

Status: PASS — validated against the documented baseline and independent reconciliation checks.

### G3 — Four-Fact Comparison

Expected:
Four records with corresponding
map-ready and total populations.

Status: PASS — validated against the documented baseline and independent reconciliation checks.

### G4 — Monthly Order Reconciliation

Expected:
- Total Orders: 99,441
- Map-Ready Orders: 99,162
- Missing Reference: 278
- Flagged Coordinates: 1
- Three differences: 0

Status: PASS — validated against the documented baseline and independent reconciliation checks.

### G5 — Top 10 Customer States

Expected:
Exactly ten states with counts matching SQL-2.

Status: PASS — validated against the documented baseline and independent reconciliation checks.

---

## 14. PostgreSQL Validation

File:
sql/47_powerbi_geographic_dashboard_validation.sql

### SQL-0

Geographic dimension fields inspected.

Status: PASS — validated against the documented baseline and independent reconciliation checks.

### SQL-1

Eight fact/cohort rows.

Expected:
All population checks PASS.
All partition differences zero.

Status: PASS — validated against the documented baseline and independent reconciliation checks.

### SQL-2

Top 10 customer states, full and Q1.

Expected:
State codes and counts match G5
and the corresponding dashboard chart.

Status: PASS — validated against the documented baseline and independent reconciliation checks.

### SQL-3

Purchase-month geographic completeness.

Compare monthly Power BI values against SQL.

Status: PASS — validated against the documented baseline and independent reconciliation checks.

### SQL-4A

Dimension quality.

Expected:
15,034 geography rows.
14,876 map-ready locations.
No invalid map-ready coordinates.

Status: PASS — validated against the documented baseline and independent reconciliation checks.

### SQL-4B

Seller reference coverage.

Expected:
3,095 sellers.
3,088 with geographic reference.

Status: PASS — validated against the documented baseline and independent reconciliation checks.

### SQL-5

Order geographic quality categories.

Expected:
Full: 278 missing, 1 flagged, 99,162 map-ready.
Q1: 59 missing, 0 flagged, 20,568 map-ready.

Status: PASS — validated against the documented baseline and independent reconciliation checks.

---

## 15. Visual Interaction Configuration

Purchase Date slicer:
Filters all six cards and four charts.

Order Status slicer:
Filters all six cards and four charts.

Top 10 Customer States:
Outgoing interactions None.

Monthly Map-Ready Share:
Filters compatible reporting visuals
by purchase month.

Map-Ready Coverage by Fact:
Outgoing interactions None.

Order Geographic Exceptions:
Outgoing interactions None.

---

## 16. Interaction QA

- [x] Purchase Date filters all six cards.
- [x] Purchase Date filters all four charts.
- [x] Order Status filters all six cards.
- [x] Order Status filters all four charts.
- [x] Full-history cards match baselines.
- [x] Q1 delivered cards match baselines.
- [x] Top 10 states match DAX and SQL.
- [x] Month selection filters by purchase month.
- [x] State chart outgoing interactions are None.
- [x] Fact comparison outgoing interactions are None.
- [x] Geographic exceptions outgoing interactions are None.
- [x] Seller dimension remains independent of purchase cohort.
- [x] Clear all slicers restores full-history values.

---

## 17. Visual QA

- [x] Page heading is correct.
- [x] Six KPI cards are aligned.
- [x] Top 10 state ranking is readable.
- [x] State values are sorted descending.
- [x] Exact state counts are accessible via tooltips.
- [x] Monthly labels are chronological.
- [x] Four fact comparison bars are present.
- [x] Fact percentages are correctly formatted.
- [x] Geographic exceptions show exact counts.
- [x] Inherited Product/Seller filters removed.
- [x] No unnecessary axis titles.
- [x] No redundant chart subtitles.
- [x] Gridlines hidden in final screenshot.
- [x] No overlapping or truncated visuals.

---

## 18. Data and Modeling Safeguards

1. Geographic matching uses customer ZIP-prefix
   geographic reference information.

2. State-level analysis does not identify precise
   residential or delivery locations.

3. Map-ready indicates reference-coordinate
   screening, not rooftop accuracy.

4. Missing geographic references remain in
   total fact populations.

5. Flagged coordinates remain in exception counts.

6. The four fact tables represent different
   record grains and denominators.

7. Purchase Date defines order-purchase cohorts.

8. The Seller dimension is not automatically
   filtered by Order Status or Purchase Date.

9. The four-row Geo Fact Type table remains
   disconnected from all warehouse tables.

10. No geographic source rows are deleted
    or modified during dashboard creation.

11. This page uses native Power BI Desktop
    visuals and has no Azure Maps dependency.

12. Historical marketplace data must not
    be described as current activity.

---

## 19. Project File References

Power BI:
powerbi/Order_to_Cash_Intelligence.pbix

DAX:
powerbi/dax/15_geographic_dashboard_helpers.dax

SQL:
sql/47_powerbi_geographic_dashboard_validation.sql

QA:
docs/powerbi_dashboard_06_geographic_quality_qa.md

KPI coverage:
docs/powerbi_kpi_coverage.csv

Geographic methodology:
docs/geographic_reference_methodology.md

---


## 20. Final Sign-Off

**Page:** 06 Geographic Coverage & Data Quality

**Final status: PASS**

### Full-History Results

| Metric | Result |
|---|---:|
| Total Orders | 99,441 |
| Geo-Referenced Orders | 99,163 |
| Map-Ready Orders | 99,162 |
| Map-Ready Order Share | 99.72% |
| Missing Geo Reference | 278 |
| Flagged Coordinates | 1 |
| Map-Ready Sellers | 3,088 |

### Four-Fact Geographic Coverage

| Fact | Total | Map-Ready | Share |
|---|---:|---:|---:|
| Orders | 99,441 | 99,162 | 99.72% |
| Order Items | 112,650 | 112,347 | 99.73% |
| Payments | 103,886 | 103,598 | 99.72% |
| Reviews | 99,224 | 98,944 | 99.72% |

### Q1 2018 Delivered Cohort

| Metric | Result |
|---|---:|
| Total Orders | 20,627 |
| Map-Ready Orders | 20,568 |
| Map-Ready Order Share | 99.71% |
| Missing Geo Reference | 59 |
| Flagged Coordinates | 0 |
| Map-Ready Sellers | 3,088 |

### Completed QA

- [x] Six KPI cards validated
- [x] Four native visuals created
- [x] DAX G1 through G5 passed
- [x] Independent SQL checks passed
- [x] Top 10 state ranking reconciled
- [x] Geographic populations reconciled
- [x] Full-history cohort validated
- [x] Q1 delivered cohort validated
- [x] Geographic exceptions retained
- [x] Chart interactions tested
- [x] Final visual QA completed
- [x] PBIX and documentation saved

### Geographic Safeguards

Geographic matching is based on customer
ZIP-prefix reference information.

Map-ready status indicates suitability
for geographic analysis; it is not proof
of exact residential or delivery coordinates.

Missing and flagged records remain represented
in the appropriate source populations.

### Visualization Decision

The dashboard uses Top 10 Customer States
by Map-Ready Orders instead of Azure Maps.

No organizational Power BI Service account
is required for the native state-ranking chart.

The published dashboard screenshot provides
static visual evidence. Interactive report
functionality remains in the local PBIX.

**Final publication status: PASS**

Consolidated release reference:
`docs/powerbi_release_qa_7_5.md`
