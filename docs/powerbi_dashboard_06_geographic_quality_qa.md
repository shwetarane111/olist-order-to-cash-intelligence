
# Power BI Dashboard QA — Page 06: Geographic Coverage & Data Quality

**Project:** Order-to-Cash Intelligence Platform

**PBIX:** `powerbi/Order_to_Cash_Intelligence.pbix`

**Page:** `06 Geographic Coverage and Data Quality`

**Phase:** Step 7.4 — Task 6

**Status:** IN PROGRESS — final validation pending

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

SQL reference:
SQL-2 in the geographic dashboard audit.

### Full Dataset

Record the verified state ranking after comparison:

| Rank | State | Map-Ready Orders |
|---|---|---:|
| 1 | PENDING | PENDING |
| 2 | PENDING | PENDING |
| 3 | PENDING | PENDING |
| 4 | PENDING | PENDING |
| 5 | PENDING | PENDING |
| 6 | PENDING | PENDING |
| 7 | PENDING | PENDING |
| 8 | PENDING | PENDING |
| 9 | PENDING | PENDING |
| 10 | PENDING | PENDING |

### Q1 2018 Delivered

Record state ranking and counts
from the Q1 rows of SQL-2.

Acceptance:
State codes and counts must match Power BI
under the same purchase-date and status filters.

Top 10 totals are not expected to equal
all map-ready orders because other states
are also represented.

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

Status: PENDING

### G2 — Geographic Partitions

Expected:
Four zero differences and four TRUE values.

Status: PENDING

### G3 — Four-Fact Comparison

Expected:
Four records with corresponding
map-ready and total populations.

Status: PENDING

### G4 — Monthly Order Reconciliation

Expected:
- Total Orders: 99,441
- Map-Ready Orders: 99,162
- Missing Reference: 278
- Flagged Coordinates: 1
- Three differences: 0

Status: PENDING

### G5 — Top 10 Customer States

Expected:
Exactly ten states with counts matching SQL-2.

Status: PENDING

---

## 14. PostgreSQL Validation

File:
sql/47_powerbi_geographic_dashboard_validation.sql

### SQL-0

Geographic dimension fields inspected.

Status: PENDING

### SQL-1

Eight fact/cohort rows.

Expected:
All population checks PASS.
All partition differences zero.

Status: PENDING

### SQL-2

Top 10 customer states, full and Q1.

Expected:
State codes and counts match G5
and the corresponding dashboard chart.

Status: PENDING

### SQL-3

Purchase-month geographic completeness.

Compare monthly Power BI values against SQL.

Status: PENDING

### SQL-4A

Dimension quality.

Expected:
15,034 geography rows.
14,876 map-ready locations.
No invalid map-ready coordinates.

Status: PENDING

### SQL-4B

Seller reference coverage.

Expected:
3,095 sellers.
3,088 with geographic reference.

Status: PENDING

### SQL-5

Order geographic quality categories.

Expected:
Full: 278 missing, 1 flagged, 99,162 map-ready.
Q1: 59 missing, 0 flagged, 20,568 map-ready.

Status: PENDING

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

- [ ] Purchase Date filters all six cards.
- [ ] Purchase Date filters all four charts.
- [ ] Order Status filters all six cards.
- [ ] Order Status filters all four charts.
- [ ] Full-history cards match baselines.
- [ ] Q1 delivered cards match baselines.
- [ ] Top 10 states match DAX and SQL.
- [ ] Month selection filters by purchase month.
- [ ] State chart outgoing interactions are None.
- [ ] Fact comparison outgoing interactions are None.
- [ ] Geographic exceptions outgoing interactions are None.
- [ ] Seller dimension remains independent of purchase cohort.
- [ ] Clear all slicers restores full-history values.

---

## 17. Visual QA

- [ ] Page heading is correct.
- [ ] Six KPI cards are aligned.
- [ ] Top 10 state ranking is readable.
- [ ] State values are sorted descending.
- [ ] Exact state counts are accessible via tooltips.
- [ ] Monthly labels are chronological.
- [ ] Four fact comparison bars are present.
- [ ] Fact percentages are correctly formatted.
- [ ] Geographic exceptions show exact counts.
- [ ] Inherited Product/Seller filters removed.
- [ ] No unnecessary axis titles.
- [ ] No redundant chart subtitles.
- [ ] Gridlines hidden in final screenshot.
- [ ] No overlapping or truncated visuals.

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
docs/powerbi_kpi_coverage_final_after_task11.csv

Geographic methodology:
docs/geographic_reference_methodology.md

---

## 20. Final Sign-Off

Page:
06 Geographic Coverage and Data Quality

Current status:
IN PROGRESS

Requirements for PASS:

- Six KPI cards correct
- Four native charts created
- All five DAX checks passed
- All independent SQL checks passed
- Top 10 state ranking matched
- Full and Q1 populations reconciled
- Visual interactions tested
- Final visual QA completed
- PBIX and documentation saved

After completion:
Proceed to cross-page dashboard QA,
repository cleanup and GitHub publication.
