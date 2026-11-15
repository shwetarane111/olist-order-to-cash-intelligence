
# Power BI Release QA — Six-Page Dashboard

**Project:** Order-to-Cash Intelligence Platform

**Phase:** Step 7.5 — Final Cross-Page QA

**Release candidate:**
`powerbi/Order_to_Cash_Intelligence_release_candidate.pbix`

**Status:** IN PROGRESS — release validation pending

**Validation database:** PostgreSQL `olist_analytics`

**Currency:** BRL / R$

**Historical scope:** Olist marketplace dataset

---

## 1. Release Objective

Validate the complete six-page Power BI report
as one consistent analytical deliverable.

Release acceptance requires:

- Reproducible DAX calculations
- Independent PostgreSQL reconciliation
- Correct dimensional filtering
- Accurate business metric definitions
- Correct date-role interpretation
- Consistent visual interactions
- Clean presentation
- Complete supporting documentation
- A locally saved release-candidate PBIX

No Power BI online publication is required.

---

## 2. Dashboard Inventory

| Page | Dashboard |
|---|---|
| 01 | Executive Overview |
| 02 | Order Fulfillment |
| 03 | Financial Reconciliation |
| 04 | Customer & Satisfaction |
| 05 | Product & Seller Performance |
| 06 | Geographic Coverage & Data Quality |

Expected:
- 6 dashboard pages
- 36 headline KPI cards
- 24 analytical charts
- Purchase Date slicer on all pages
- Order Status slicer on all pages
- Clear all slicers control on all pages

---

## 3. Semantic Model

Imported warehouse tables: 12

Original warehouse relationships: 20

Relationship design:
- Active
- One-to-many
- Dimension-to-fact
- Single-direction

Fact-to-fact relationships: 0

Bidirectional relationships: 0

Date dimensions:
- dim_purchase_date
- dim_delivery_date
- dim_review_date

Power BI auto date/time: Disabled

Measure home table: _Measures

Additional display-only calculated table:
Geo Fact Type

Geo Fact Type rows: 4

Geo Fact Type relationships: 0

---

## 4. Core Measurement Rules

### Orders

Fact:
analytics.fact_orders

Grain:
One row per order.

### Order Items

Fact:
analytics.fact_order_items

Grain:
One row per order-item record.

Item prices are source-recorded monetary values,
not recognized accounting revenue.

### Payments

Fact:
analytics.fact_payments

Grain:
One row per payment entry.

Recorded payment volume is not a verified
settlement or cash-receipt amount.

### Reviews

Fact:
analytics.fact_order_reviews

Grain:
One row per review record.

Review records are not necessarily equivalent
to distinct reviewed orders.

### Customer Identities

customer_unique_id identifies pseudonymous
customer identities in the source dataset.

It is not a verified real-world person count.

### Geography

Geographic matching uses customer ZIP-prefix
reference data.

Map-ready does not mean an exact customer
address or verified delivery GPS position.

---

## 5. Date Role Rules

The Purchase Date slicer represents the
order purchase cohort.

It filters all four order-related fact tables
through the approved model relationships.

Delivery Date filters delivery-related
fact activity through its own date role.

Review Creation Date filters review activity
through its own date role.

Review creation date is not substituted for
order purchase date in Page 04.

Payment entries do not have a separate
validated payment-event date in this model.

---

## 6. Standard QA Cohorts

### ALL

Full historical dataset.

Purchase Date:
Complete available range.

Order Status:
All.

### Q1_2018_DELIVERED

Purchase Date:
2018-01-01 through 2018-03-31 inclusive.

Order Status:
delivered.

The filter is applied independently to
each report page for regression testing.

Page slicers are not assumed synchronized
unless deliberately configured and tested.

---

## 7. Executive Overview Baselines

| Metric | ALL | Q1 Delivered |
|---|---:|---:|
| Total Orders | 99,441 | 20,627 |
| Delivered Orders | 96,478 | 20,627 |
| Item + Freight | 15,843,553.24 | 3,164,654.11 |
| Recorded Payments | 16,008,872.12 | 3,165,795.74 |
| On-Time Rate | 93.23% | 87.12% |
| Financial Mismatch Rate | 0.58% | 0.62% |

Status: PENDING release recheck

---

## 8. Order Fulfillment Baselines

| Metric | ALL | Q1 Delivered |
|---|---:|---:|
| Delivered Orders | 96,478 | 20,627 |
| Evaluable Delivered | 96,470 | 20,627 |
| On-Time | 89,936 | 17,970 |
| Late | 6,534 | 2,657 |
| On-Time Rate | 93.23% | 87.12% |
| Late Rate | 6.77% | 12.88% |
| Average Delivery Days | 12.56 | 15.74 |
| Signed Delivery Variance Days | -11.88 | -9.25 |

Late deliveries must reconcile to the
previously validated severity bands.

Status: PENDING release recheck

---

## 9. Financial Reconciliation Baselines

| Metric | ALL | Q1 Delivered |
|---|---:|---:|
| Comparable Orders | 98,665 | 20,627 |
| Matched Orders | 98,089 | 20,499 |
| Mismatched Orders | 576 | 128 |
| Coverage Gaps | 776 | 0 |
| Match Rate | 99.42% | 99.38% |
| Net Difference | 2,870.39 | 1,141.63 |
| Absolute Discrepancy | 3,271.95 | 1,142.37 |

Absolute discrepancy must not be less than
the absolute value of the net difference.

Status: PENDING release recheck

---

## 10. Customer & Satisfaction Baselines

| Metric | ALL | Q1 Delivered |
|---|---:|---:|
| Customer Identities | 96,096 | 20,211 |
| Repeat Customer Identities | 2,997 | 400 |
| Repeat Share | 3.12% | 1.98% |
| Review Records | 99,224 | 20,630 |
| Review Coverage | 99.23% | 99.23% |
| Average Review Score | 4.09 | 3.94 |
| High-Rating Share | 77.07% | 72.68% |
| Written Feedback Share | 43.03% | 41.88% |

Overall Average Review Score was independently
checked using the review fact.

The review-record-weighted full average is 4.09.

The unweighted mean of monthly review-score
averages is 3.82 and is not the headline KPI.

Status: PENDING release recheck

---

## 11. Product & Seller Baselines

| Metric | ALL | Q1 Delivered |
|---|---:|---:|
| Item Entries | 112,650 | 23,572 |
| Item Price | 13,591,643.70 | 2,704,438.38 |
| Freight | 2,251,909.54 | 460,215.73 |
| Active Products | 32,951 | 8,990 |
| Active Sellers | 3,095 | 1,351 |
| Seller-Order Associations | 100,010 | 20,885 |
| Multi-Order Sellers | 2,524 | 1,064 |
| Multi-Order Seller Share | 81.55% | 78.76% |
| Top 10 Seller Item Price | 1,787,241.74 | 393,589.46 |
| Top 10 Concentration | 13.15% | 14.55% |

Top 10 values use the seller ranking from
recorded item-price contribution.

Status: PENDING release recheck

---

## 12. Geographic Coverage Baselines

| Metric | ALL | Q1 Delivered |
|---|---:|---:|
| Total Orders | 99,441 | 20,627 |
| Map-Ready Orders | 99,162 | 20,568 |
| Map-Ready Order Share | 99.72% | 99.71% |
| Missing Geo Orders | 278 | 59 |
| Flagged Geo Orders | 1 | 0 |
| Map-Ready Items | 112,347 | 23,510 |
| Map-Ready Payments | 103,598 | 21,362 |
| Map-Ready Reviews | 98,944 | 20,572 |
| Map-Ready Sellers | 3,088 | 3,088 |

Geographic exceptions must remain represented
in the headline total-order denominator.

Page 06 uses a native state-ranking bar chart,
not Azure Maps.

Status: PENDING release recheck

---

## 13. DAX Release Validation

File:
powerbi/dax/16_cross_page_release_checks.dax

### DAX-R1

Orders, fulfillment and financial reconciliation.

Expected:
Two cohorts matching Section 7, 8 and 9
where those metrics overlap.

Status: PENDING

### DAX-R2

Customers, reviews, products and sellers.

Expected:
Two cohorts matching Section 10 and 11.

Status: PENDING

### DAX-R3

Item+freight, payment volume and geographic
population reconciliation.

Expected:
Two cohorts matching Section 7 and 12.

Status: PENDING

---

## 14. PostgreSQL Release Validation

File:
sql/48_powerbi_cross_page_release_validation.sql

### SQL-R1

Orders, fulfillment and financial reconciliation.

Expected:
Two rows.
All partition differences zero.

Status: PENDING

### SQL-R2

Customer and review reconciliation.

Expected:
Two rows.
Reviewed-order difference zero.
Written-feedback partition difference zero.

Status: PENDING

### SQL-R3

Items, sellers and payments.

Expected:
Two rows.
All values match DAX release checks.

Status: PENDING

### SQL-R4

Geographic completeness across four facts.

Expected:
Eight rows.
All audit statuses PASS.
All partition differences zero.
No missing dimension links.

Status: PENDING

---

## 15. Cross-Page Interaction QA

### Page 01

- [ ] Purchase Date filters all relevant visuals
- [ ] Order Status filters all relevant visuals
- [ ] Monthly charts filter by month as designed
- [ ] Reconciliation Status outgoing filtering disabled
- [ ] Clear all slicers works

### Page 02

- [ ] Purchase Date and Status filters work
- [ ] Monthly On-Time trend filters by month
- [ ] Stacked delivery chart outgoing filtering disabled
- [ ] Late Delivery Bands outgoing filtering disabled
- [ ] Clear all slicers works

### Page 03

- [ ] Purchase Date and Status filters work
- [ ] Monthly financial trend filtering works
- [ ] Financial Exceptions outgoing filtering disabled
- [ ] No inherited Late Delivery Band restrictions
- [ ] Clear all slicers works

### Page 04

- [ ] Purchase Date and Status filters work
- [ ] Monthly customer and review trends filter by month
- [ ] Review Score Distribution outgoing filtering disabled
- [ ] Written Feedback outgoing filtering disabled
- [ ] No inherited financial filters
- [ ] Clear all slicers works

### Page 05

- [ ] Purchase Date and Status filters work
- [ ] Monthly Multi-Order Seller Share filters by month
- [ ] Top 10 Sellers outgoing filtering disabled
- [ ] Top 10 Categories outgoing filtering disabled
- [ ] Stacked Item Price/Freight outgoing filtering disabled
- [ ] Clear all slicers works

### Page 06

- [ ] Purchase Date and Status filters work
- [ ] Top 10 Customer States responds to slicers
- [ ] Monthly geographic share filters by month
- [ ] Four-Fact Coverage outgoing filtering disabled
- [ ] Geographic Exceptions outgoing filtering disabled
- [ ] Clear all slicers works

---

## 16. Visual Formatting QA

- [ ] All six page headings are consistent
- [ ] All 36 KPI cards are readable
- [ ] All 24 analytical charts are available
- [ ] No duplicate or outdated chart titles
- [ ] No inherited incorrect axis titles
- [ ] All month labels are chronological
- [ ] BRL financial formatting is consistent
- [ ] Percentage measures have appropriate precision
- [ ] Top 10 rankings retain all ten categories
- [ ] Scrollbars do not conceal data permanently
- [ ] No editing gridlines in release screenshots
- [ ] No selected visual resize handles
- [ ] No clipped KPI values
- [ ] No unintended report/page-level filters

---

## 17. Screenshot Inventory

Folder:
assets/screenshots/

Required files:

1. 01_executive_overview.png
2. 02_order_fulfillment.png
3. 03_financial_reconciliation.png
4. 04_customer_satisfaction.png
5. 05_product_seller_performance.png
6. 06_geographic_coverage_quality.png

Status:
PENDING capture and review.

---

## 18. Known Analytical Limitations

1. Data is historical rather than live.

2. Recorded payments are not confirmed
   settled cash or recognized revenue.

3. Item prices exclude freight unless
   expressly combined.

4. Seller item-price contribution is not profit.

5. Customer repeat metrics are defined inside
   the selected order cohort.

6. Review metrics use review-record grain
   unless explicitly defined as order-level.

7. Review creation date is a separate date role.

8. Geographic coordinates represent screened
   ZIP-prefix reference locations, not
   precise delivery destinations.

9. Missing geographic references are retained
   in denominator populations.

10. Seller dimension totals are not automatically
    filtered by order purchase-date selections.

11. Top 10 categories and sellers are ranked
    within the relevant filter context.

12. Visual category selections deliberately
    do not filter unrelated fact-grain KPIs.

---

## 19. Local Development and Account Independence

The release candidate is developed locally
in Power BI Desktop.

The Page 06 geographic chart uses native
Power BI bar charts.

Azure Maps is not required.

Power BI Service publishing is not required.

The report must not depend on a university
Microsoft tenant for its local viewing.

Project source files and the PBIX should be
saved outside university-managed cloud storage.

Any connection credentials must be excluded
from public repository documentation.

---

## 20. Release Sign-Off Checklist

- [ ] All 36 KPI cards validated
- [ ] All six Q1 cohort regressions validated
- [ ] DAX-R1 passed
- [ ] DAX-R2 passed
- [ ] DAX-R3 passed
- [ ] SQL-R1 passed
- [ ] SQL-R2 passed
- [ ] SQL-R3 passed
- [ ] SQL-R4 passed
- [ ] All interaction tests passed
- [ ] Inherited filters reviewed
- [ ] Visual consistency audit passed
- [ ] Six final screenshots captured
- [ ] Release-candidate PBIX saved
- [ ] No credentials present in planned public files
- [ ] Source QA documentation retained

---

## 21. Release Decision

Current release decision:
PENDING

Release candidate:
Order_to_Cash_Intelligence_release_candidate.pbix

If every acceptance criterion passes:
Change release decision to PASS.

If any check fails:
Record the metric, affected page, actual value,
expected value, root cause and corrective action.

Do not mark the release PASS solely because
the visuals render successfully.

---

## 22. Next Project Phase

Step 7.6:
Portfolio packaging and GitHub publication.

Planned work:
- Repository organization
- README narrative
- Architecture and data-model diagrams
- SQL and DAX reproducibility instructions
- Screenshots and dashboard walkthrough
- Dataset licensing and attribution
- Privacy and credential review
- GitHub publication
- Portfolio presentation

Do not start publication until release QA passes.

---

**End of release QA document**
