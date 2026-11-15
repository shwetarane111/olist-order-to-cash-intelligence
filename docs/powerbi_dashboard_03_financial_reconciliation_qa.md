
# Power BI Dashboard QA — Page 03: Financial Reconciliation

**Project:** Order-to-Cash Intelligence Platform

**Power BI report:** `powerbi/Order_to_Cash_Intelligence.pbix`

**Page:** `03 Financial Reconciliation`

**Phase:** Step 7.4 — Task 3

**Status:** PASS — Financial Reconciliation dashboard validated against full-history and Q1 delivered-cohort records, DAX F1–F3, PostgreSQL SQL-1 through SQL-3, and interaction tests.

**Source:** PostgreSQL `olist_analytics`, analytics layer

**Currency:** BRL / R$

---

## 1. Business Purpose

The Financial Reconciliation dashboard measures:

- Financially comparable orders
- Matching and mismatched orders
- Match rate
- Missing financial-record coverage
- Net recorded payment differences
- Absolute order-level financial discrepancies
- Monthly reconciliation performance
- Source-record financial exceptions

The dashboard evaluates consistency between
recorded item-plus-freight values and recorded
payment values.

It does not measure recognized revenue,
accounting settlement, fraud, customer
overcharging, or confirmed financial losses.

---

## 2. Source and Semantic Model

Primary analytical source:

`analytics.fact_orders`

Grain:
One order per fact row.

Relevant order-level fields:

- order_id
- reconciliation_status
- item_plus_freight_total
- recorded_payment_total
- payment_difference
- absolute_payment_difference
- purchase_date

Relevant shared dimensions:

- dim_purchase_date
- dim_order_status

Product and Seller dimensions do not automatically
filter order-level reconciliation calculations.

No bidirectional relationships or fact-to-fact
relationships were added.

---

## 3. KPI Definitions

### Comparable Orders

Orders classified MATCH or MISMATCH.

Both item-plus-freight and recorded-payment
amounts must be available.

### Matched Orders

Comparable orders whose recorded amounts
satisfy the project's established matching rule.

### Mismatched Orders

Comparable orders whose recorded amounts
fail the project's established matching rule.

### Financial Match Rate

Matched Orders / Comparable Orders.

Missing financial records are excluded from
the denominator.

### Financial Coverage Gaps

Total Orders - Comparable Orders.

Includes orders missing required item or
payment records.

### Net Payment Difference

Sum of signed payment-minus-item differences
across comparable orders.

Positive values mean recorded payment totals
exceed item-plus-freight totals.

### Absolute Financial Discrepancy

Sum of order-level absolute payment differences
across comparable orders.

This is not the absolute value of the
aggregate net payment difference.

---

## 4. Page Configuration

- Canvas: 1280 x 720
- Aspect ratio: 16:9
- Design source: Duplicated Page 02
- Heading: Financial Reconciliation
- Background: #F5F7FA
- Cards: White
- Borders: #E1E8EF
- Navy: #17324D
- Teal: #117F7A
- Secondary Blue: #567FA6
- Warning Amber: #D79A5C

### Filters

Purchase Date:
dim_purchase_date[date]

Order Status:
dim_order_status[order_status]

Reset control:
Clear all slicers.

Monthly charts use the order's purchase date,
not a verified payment transaction date.

---

## 5. Six KPI Cards

| Card | DAX Measure | Full Dataset |
|---|---|---:|
| Comparable Orders | [Comparable Orders] | 98,665 |
| Financial Match Rate | [Financial Match Rate (Dashboard)] | 99.42% |
| Mismatched Orders | [Mismatched Orders] | 576 |
| Financial Coverage Gaps | [Financial Coverage Gaps (Dashboard)] | 776 |
| Net Payment Difference | [Net Comparable Payment Difference] | +R$2,870.39 |
| Absolute Discrepancy | [Absolute Financial Discrepancy] | R$3,271.95 |

### Additional Baselines

Total Orders: 99,441

Matched Orders: 98,089

Comparable Item + Freight:
R$15,843,409.78

Comparable Recorded Payments:
R$15,846,280.17

---

## 6. Chart Inventory

### Chart 1: Financial Match Rate by Purchase Month

Type:
Line chart.

X-axis:
dim_purchase_date[Purchase Month Label]

Y-axis:
[Financial Match Rate (Dashboard)]

Tooltips:
- [Comparable Orders]
- [Matched Orders]
- [Mismatched Orders]

The chart uses filtered matching and
comparable order counts.

### Chart 2: Matched vs Mismatched Orders by Purchase Month

Type:
Stacked column chart.

X-axis:
dim_purchase_date[Purchase Month Label]

Values:
- [Matched Orders]
- [Mismatched Orders]

Tooltips:
- [Comparable Orders]
- [Financial Match Rate (Dashboard)]

Monthly stacked counts partition the
comparable order population.

### Chart 3: Net Payment Difference by Purchase Month

Type:
Clustered column chart.

X-axis:
dim_purchase_date[Purchase Month Label]

Y-axis:
[Net Comparable Payment Difference]

Tooltips:
- [Comparable Item and Freight Value]
- [Comparable Recorded Payment Value]
- [Absolute Financial Discrepancy]

Positive and negative values retain their
original mathematical signs.

### Chart 4: Financial Exceptions by Type

Type:
Clustered bar chart.

Category:
fact_orders[reconciliation_status]

Value:
[Total Orders]

Visual-level filtering:
Exclude MATCH.

Do not retain the previous Page 02
Late Delivery Band visual filter.

Expected exception categories:

- MISSING_ITEMS: 775
- MISMATCH: 576
- MISSING_PAYMENTS: 1

Expected exception total: 1,352.

---

## 7. Full-History Financial Baselines

| Metric | Expected |
|---|---:|
| Total Orders | 99,441 |
| Comparable Orders | 98,665 |
| Matched Orders | 98,089 |
| Mismatched Orders | 576 |
| Financial Match Rate | 99.42% |
| Financial Mismatch Rate | 0.58% |
| Financial Coverage Gaps | 776 |
| Missing Items | 775 |
| Missing Payments | 1 |
| Missing Both | 0 |
| Comparable Item + Freight | R$15,843,409.78 |
| Comparable Recorded Payments | R$15,846,280.17 |
| Net Payment Difference | +R$2,870.39 |
| Absolute Financial Discrepancy | R$3,271.95 |

### Mathematical Consistency

98,089 + 576 = 98,665

98,665 + 776 = 99,441

775 + 1 = 776

15,846,280.17 - 15,843,409.78 = 2,870.39

Absolute discrepancy must be greater than
or equal to the absolute net discrepancy.

---

## 8. Q1 2018 Delivered-Order Cohort

Purchase Date:
January 1 through March 31, 2018.

Order Status:
delivered.

| Metric | Expected |
|---|---:|
| Total Orders | 20,627 |
| Comparable Orders | 20,627 |
| Matched Orders | 20,499 |
| Mismatched Orders | 128 |
| Financial Match Rate | 99.38% |
| Financial Mismatch Rate | 0.62% |
| Financial Coverage Gaps | 0 |
| Comparable Item + Freight | R$3,164,654.11 |
| Comparable Recorded Payments | R$3,165,795.74 |
| Net Payment Difference | +R$1,141.63 |
| Absolute Financial Discrepancy | R$1,142.37 |

### Reconciliation

20,499 + 128 = 20,627

20,627 + 0 = 20,627

3,165,795.74 - 3,164,654.11 = 1,141.63

The Q1 values are purchase-cohort results.
They do not represent payments actually
settled during January-March 2018.

---

## 9. DAX Validation

### Check F1

Full-history and Q1 2018 baseline comparison.

Status: PASS — verified during Page 03 QA and consolidated release validation.

### Check F2

Expected consistency results:

- Order population difference: 0
- Comparable population difference: 0
- Coverage-gap difference: 0
- Signed amount difference: 0.00
- Rate partition difference: 0
- Absolute discrepancy >= absolute net difference: TRUE

Status: PASS — verified during Page 03 QA and consolidated release validation.

### Check F3

Monthly aggregation expected:

- Comparable Orders: 98,665
- Matched Orders: 98,089
- Mismatched Orders: 576
- Net Payment Difference: +R$2,870.39
- Absolute Financial Discrepancy: R$3,271.95

Monthly aggregation differences must be zero.

Status: PASS — verified during Page 03 QA and consolidated release validation.

---

## 10. Independent PostgreSQL Validation

SQL reference:

sql/44_powerbi_financial_reconciliation_dashboard_validation.sql

### SQL-1

Validates full-history and Q1 reconciliation
populations and monetary amounts.

Expected:
Two cohorts matching DAX F1.

Status: PASS — verified during Page 03 QA and consolidated release validation.

### SQL-2

Validates purchase-month financial results.

Compare at least:
- January 2018
- February 2018
- March 2018

Compare:
- Comparable Orders
- Matched Orders
- Mismatched Orders
- Match Rate
- Comparable Item + Freight
- Comparable Recorded Payments
- Net Payment Difference
- Absolute Financial Discrepancy

Status: PASS — verified during Page 03 QA and consolidated release validation.

### SQL-3

Validates reconciliation status populations
for the complete dataset and Q1 delivered cohort.

Status: PASS — verified during Page 03 QA and consolidated release validation.

---

## 11. Interaction Configuration

### Purchase Date Slicer

Outgoing interactions:
Filter all six cards and four charts.

### Order Status Slicer

Outgoing interactions:
Filter all six cards and four charts.

### Monthly Match Rate

Outgoing interactions:
Filter compatible reporting visuals.

Do not change slicer selections.

### Matched vs Mismatched Stacked Chart

Outgoing interactions:
None.

Rationale:
The stacked series are separate measures,
not a single shared status dimension.

### Monthly Net Difference

Outgoing interactions:
Filter compatible reporting visuals by
purchase month.

### Financial Exceptions Chart

Outgoing interactions:
None.

Rationale:
The reconciliation_status attribute belongs
to the Orders fact and must not implicitly
filter separate item and payment facts.

---

## 12. Interaction QA Checklist

- [x] Purchase Date filters all cards.
- [x] Purchase Date filters all charts.
- [x] Order Status filters all cards.
- [x] Order Status filters all charts.
- [x] Monthly Match Rate point filters by month.
- [x] Monthly Net Difference column filters by month.
- [x] Stacked chart has no outgoing interactions.
- [x] Exception chart has no outgoing interactions.
- [x] Selecting MISMATCH leaves headline cards unchanged.
- [x] Q1 2018 delivered filters match baselines.
- [x] Clearing filters restores full-history values.

---

## 13. Visual QA Checklist

- [x] Page title is Financial Reconciliation.
- [x] Six cards are aligned and readable.
- [x] Currency displays use BRL.
- [x] Rates show two decimal places.
- [x] Monthly chart labels are chronological.
- [x] Chart titles are descriptive.
- [x] Redundant subtitles are removed.
- [x] Match and mismatch colors are distinct.
- [x] Negative net differences remain negative.
- [x] Exception chart counts are displayed accurately.
- [x] No inherited Late Delivery Band filter remains.
- [x] No clipped labels or overlapping visuals.
- [x] Editing gridlines are hidden in screenshots.
- [x] Clear all slicers button is functional.

---

## 14. Data Quality and Business Safeguards

1. Missing payment records must not automatically
   be interpreted as unpaid orders.

2. Missing item records must not automatically
   be interpreted as invalid purchases.

3. Recorded payment volumes are not confirmed
   accounting settlements.

4. Recorded item and freight totals are not
   equivalent to recognized revenue.

5. Source-record mismatches are not necessarily
   fraud, recoverable losses, or overcharges.

6. Absolute discrepancy is computed from
   order-level absolute differences.

7. Net difference permits positive and
   negative discrepancies to offset.

8. Ratios are recalculated within the
   selected filter context.

9. Financial comparisons use order-grain
   measures and comparable order populations.

10. The dashboard does not silently allocate
    order-level payment amounts to sellers
    or products.

---

## 15. Project File References

PBIX:
powerbi/Order_to_Cash_Intelligence.pbix

DAX support:
powerbi/dax/12_financial_dashboard_support_measures.dax

SQL audit:
sql/44_powerbi_financial_reconciliation_dashboard_validation.sql

Page 01 QA:
docs/powerbi_dashboard_01_executive_overview_qa.md

Page 02 QA:
docs/powerbi_dashboard_02_order_fulfillment_qa.md

Page 03 QA:
docs/powerbi_dashboard_03_financial_reconciliation_qa.md

KPI coverage:
docs/powerbi_kpi_coverage.csv

---


## 16. Final Sign-Off

**Page:** 03 Financial Reconciliation

**Final status: PASS**

### Full-History Financial Results

| Metric | Result |
|---|---:|
| Total Orders | 99,441 |
| Comparable Orders | 98,665 |
| Matched Orders | 98,089 |
| Mismatched Orders | 576 |
| Financial Coverage Gaps | 776 |
| Financial Match Rate | 99.42% |
| Net Comparable Payment Difference | R$2,870.39 |
| Absolute Financial Discrepancy | R$3,271.95 |

### Q1 2018 Delivered Cohort

| Metric | Result |
|---|---:|
| Total Orders | 20,627 |
| Comparable Orders | 20,627 |
| Matched Orders | 20,499 |
| Mismatched Orders | 128 |
| Financial Coverage Gaps | 0 |
| Financial Match Rate | 99.38% |
| Net Comparable Payment Difference | R$1,141.63 |
| Absolute Financial Discrepancy | R$1,142.37 |

### Reconciliation Controls

Full-history order partition:

98,665 comparable + 776 coverage gaps
= 99,441 total orders.

Comparable-order partition:

98,089 matched + 576 mismatched
= 98,665 comparable orders.

Absolute financial discrepancy is greater
than or equal to the absolute net difference.

### Completed QA

- [x] Six headline KPI cards validated
- [x] DAX F1 passed
- [x] DAX F2 passed
- [x] DAX F3 passed
- [x] PostgreSQL SQL-1 passed
- [x] PostgreSQL SQL-2 passed
- [x] PostgreSQL SQL-3 passed
- [x] Full-history and Q1 results reconciled
- [x] Chart interactions tested
- [x] No inherited Late Delivery Band filter
- [x] Visual QA completed
- [x] PBIX and QA documentation saved

**Final publication status: PASS**

Recorded monetary amounts represent source
transactions and reconciliation results,
not recognized accounting revenue or
independently verified cash settlement.

Consolidated release reference:
`docs/powerbi_release_qa_7_5.md`

Next page:
Step 7.4 Task 4 — Customer and Satisfaction.
