
# Power BI Dashboard QA — Page 02: Order Fulfillment

**Project:** Order-to-Cash Intelligence Platform

**PBIX:** `powerbi/Order_to_Cash_Intelligence.pbix`

**Page:** `02 Order Fulfillment`

**Phase:** Step 7.4 — Task 2

**Status:** PASS — Fulfillment dashboard validated against full-history and Q1 2018 delivered-cohort baselines, independent PostgreSQL checks, DAX checks, interaction tests, and final screenshots.

**Data:** Historical Olist marketplace extract, 2016–2018

---

## 1. Business Purpose

The Order Fulfillment dashboard analyzes:

- Delivered order volumes
- Delivery evaluation coverage
- On-time delivery performance
- Late delivery performance
- Average purchase-to-delivery time
- Average signed delivery variance
- Late-delivery severity
- Missing actual delivery dates

The report describes historical order fulfillment outcomes.

It is not a live shipping-monitoring system or
a contractual carrier SLA report.

---

## 2. Business Definitions

### Delivered Orders

Orders whose source order status is `delivered`.

Full-dataset baseline: 96,478.

### Evaluable Delivered Orders

Delivered orders with the actual and estimated
customer-delivery dates required to evaluate timeliness.

Full-dataset baseline: 96,470.

### Delivery Evaluation Coverage

Evaluable Delivered Orders / Delivered Orders.

Full-dataset baseline: 99.99%.

### On-Time Delivery Rate

On-Time Deliveries / Evaluable Delivered Orders.

An order is on time when actual customer-delivery
calendar date is on or before estimated delivery date.

Full-dataset baseline: 93.23%.

### Late Delivery Rate

Late Deliveries / Evaluable Delivered Orders.

An order is late when actual customer-delivery
calendar date is after estimated delivery date.

Full-dataset baseline: 6.77%.

### Average Purchase-to-Delivery Days

Average elapsed days between purchase timestamp
and actual customer-delivery timestamp for eligible
delivered orders with valid nonnegative durations.

Full-dataset baseline: 12.56 days.

### Average Signed Delivery Variance

Actual delivery date minus estimated delivery date.

A negative result indicates delivery before the
estimated calendar date.

Full-dataset baseline: -11.88 days.

### Missing Delivery Dates

Delivered-status orders missing actual
customer-delivery date.

Full-dataset baseline: 8.

These records are not automatically classified
as late deliveries.

---

## 3. Page Configuration

- Canvas: 1280 x 720
- Aspect ratio: 16:9
- Template: Duplicated Executive Overview
- Page title: Order Fulfillment
- Report theme: Light executive dashboard

### Design Colors

- Navy: #17324D
- Teal: #117F7A
- Secondary Blue: #567FA6
- Warning Amber: #D79A5C
- Page Background: #F5F7FA
- Visual Background: #FFFFFF
- Borders: #E1E8EF

### Page Slicers

Purchase Date:
`dim_purchase_date[date]`

Style: Between.

Order Status:
`dim_order_status[order_status]`

Style: Dropdown with multiselect enabled.

Clear all slicers button:
Retained from Page 01.

### Date Axis

`dim_purchase_date[Purchase Month Label]`

Sorted by:
`dim_purchase_date[Purchase Month Sort]`

All monthly charts represent associated
order purchase months, not delivery-event months.

---

## 4. Six KPI Cards

| Card | DAX Measure | Full Dataset |
|---|---|---:|
| Delivered Orders | `[Delivered Orders]` | 96,478 |
| Evaluation Coverage | `[Delivery Evaluation Coverage]` | 99.99% |
| On-Time Delivery | `[On-Time Delivery Rate]` | 93.23% |
| Late Delivery | `[Late Delivery Rate]` | 6.77% |
| Avg Delivery Time (days) | `[Average Purchase-to-Delivery Days]` | 12.56 |
| Avg Signed Variance (days) | `[Average Signed Delivery Variance Days]` | -11.88 |

### Supporting Measures

- Evaluable Delivered Orders: 96,470
- On-Time Deliveries: 89,936
- Late Deliveries: 6,534
- Delivered Orders Missing Actual Delivery Date: 8

All metrics use the existing validated Power BI
semantic model.

---

## 5. Four Dashboard Charts

### Chart 1: On-Time Delivery Rate by Purchase Month

Visual: Line chart.

X-axis:
`dim_purchase_date[Purchase Month Label]`

Y-axis:
`[On-Time Delivery Rate]`

Tooltips:
- `[Evaluable Delivered Orders]`
- `[On-Time Deliveries]`

The line must represent the filtered eligible-delivery
rate, not an average of monthly percentages.

### Chart 2: On-Time vs Late Deliveries by Purchase Month

Visual: Stacked column chart.

X-axis:
`dim_purchase_date[Purchase Month Label]`

Values:
- `[On-Time Deliveries]`
- `[Late Deliveries]`

Tooltips:
- `[Evaluable Delivered Orders]`
- `[Delivery Evaluation Coverage]`

Monthly on-time and late counts must add up to
monthly evaluable delivered orders.

### Chart 3: Average Purchase-to-Delivery Days by Month

Visual: Line chart.

X-axis:
`dim_purchase_date[Purchase Month Label]`

Y-axis:
`[Average Purchase-to-Delivery Days]`

Tooltips:
- `[Evaluable Delivered Orders]`
- `[Delivered Orders Missing Actual Delivery Date]`

Elapsed days are measured from purchase to customer
delivery, not from carrier dispatch.

### Chart 4: Late Delivery Severity

Visual: Clustered bar chart.

Y-axis:
`fact_orders[Late Delivery Band]`

X-axis:
`[Total Orders]`

Visual-level filter:
Exclude BLANK Late Delivery Band.

Sort:
`fact_orders[Late Delivery Band Sort]`

Severity bands:
- 1-3 days late
- 4-7 days late
- 8-14 days late
- 15+ days late

The severity filter must apply to this visual only.
No nonlate orders should be deleted from the model.

---

## 6. Calculated Columns

The following calculated columns were created
in `fact_orders`:

1. `Late Delivery Band`
2. `Late Delivery Band Sort`

Reference:

`powerbi/dax/11_fulfillment_late_delivery_bands.dax`

### Band Rules

| Band | Variance |
|---|---|
| 1-3 days late | +1 to +3 calendar days |
| 4-7 days late | +4 to +7 calendar days |
| 8-14 days late | +8 to +14 calendar days |
| 15+ days late | +15 or more calendar days |

Only delivered, evaluable, late orders receive
a severity band.

Other orders return BLANK.

---

## 7. Verified Full-Dataset Baselines

| KPI | Verified Result |
|---|---:|
| Delivered Orders | 96,478 |
| Evaluable Delivered Orders | 96,470 |
| On-Time Deliveries | 89,936 |
| Late Deliveries | 6,534 |
| Delivery Evaluation Coverage | 99.99% |
| On-Time Delivery Rate | 93.23% |
| Late Delivery Rate | 6.77% |
| Average Purchase-to-Delivery Days | 12.56 |
| Average Signed Delivery Variance Days | -11.88 |
| Delivered Orders Missing Actual Date | 8 |
| Negative Purchase-to-Delivery Durations | 0 |

### Fulfillment Consistency

Delivered Orders:
96,478 = 96,470 + 8

Evaluable Delivered Orders:
96,470 = 89,936 + 6,534

All population differences must equal zero.

---

## 8. Verified Late-Delivery Severity Results

Source:
Power BI DAX validation of `fact_orders`.

| Severity Band | Sort | Orders |
|---|---:|---:|
| 1-3 days late | 1 | 1,870 |
| 4-7 days late | 2 | 1,802 |
| 8-14 days late | 3 | 1,478 |
| 15+ days late | 4 | 1,384 |
| **Total** | | **6,534** |

### Mathematical Validation

1,870 + 1,802 + 1,478 + 1,384 = 6,534

Existing measure:
`[Late Deliveries] = 6,534`

Difference:
0

### Interpretation

The band distribution is based on actual delivery
being later than the estimated calendar date.

The band categories are mutually exclusive.

This is not a measurement of carrier-only transit
delay or contractual SLA penalties.

---

## 9. Q1 2018 Delivered-Order Cohort

### Filter Definition

Purchase Date:
January 1 through March 31, 2018, inclusive.

Order Status:
delivered.

### Validated Q1 Baselines

| Metric | Verified Result |
|---|---:|
| Delivered Orders | 20,627 |
| Evaluable Delivered Orders | 20,627 |
| On-Time Deliveries | 17,970 |
| Late Deliveries | 2,657 |
| Delivery Evaluation Coverage | 100.00% |
| On-Time Delivery Rate | 87.12% |
| Late Delivery Rate | 12.88% |
| Delivered Orders Missing Actual Date | 0 |
| Average Purchase-to-Delivery Days | 15.74 |
| Average Signed Delivery Variance Days | -9.25 |

### Mathematical Validation

20,627 = 17,970 + 2,657

Evaluation coverage difference:
0

Delivery classification difference:
0

### Average Purchase-to-Delivery Days

Q1 2018 delivered cohort: 15.74 days.

This is the mean of eligible order-level elapsed
purchase-to-delivery durations.

### Average Signed Delivery Variance

Q1 2018 delivered cohort: -9.25 days.

This indicates that, on average, evaluable orders
in the cohort were delivered 9.25 calendar days
before their estimated delivery dates.

This average does not mean every order was early;
2,657 evaluable orders were delivered late.


### Q1 Late Severity Distribution

Cohort:
Delivered orders purchased January 1–March 31, 2018.

| Severity Band | Orders |
|---|---:|
| 1-3 days late | 628 |
| 4-7 days late | 708 |
| 8-14 days late | 641 |
| 15+ days late | 680 |
| **Total** | **2,657** |

Validation:
628 + 708 + 641 + 680 = 2,657

Previously validated Q1 late-delivery count: 2,657.

Reconciliation difference: 0.

### Q1 Fulfillment Averages

Average Purchase-to-Delivery Days: 15.74

Average Signed Delivery Variance Days: -9.25

These results use the Q1 2018 delivered-order
purchase cohort, not orders delivered during Q1.

### Full-Dataset Severity Baselines

1-3 days late: 1,870
4-7 days late: 1,802
8-14 days late: 1,478
15+ days late: 1,384

Total: 6,534

### Visual QA

- Page heading: PASS
- Six KPI cards: PASS
- Monthly fulfillment charts: PASS
- Late Delivery Severity chart: PASS
- Four severity bands: PASS
- Chronological month sorting: PASS
- Consistent Page 01 styling: PASS
- Dashboard numerical labels: PASS

### Remaining Sign-Off

- Confirm SQL-1 full/Q1 reconciliation: PASS
- Confirm SQL-2 band-by-band SQL match: PASS
- Confirm SQL-3 monthly comparison: PASS
- Confirm final page interactions: PASS

---

## 10. Independent SQL Validation

Reference:

`sql/43_powerbi_order_fulfillment_dashboard_validation.sql`

The file contains three SQL queries.


### SQL-1: Fulfillment Baselines

Status:
PASS — Full-history and Q1 2018 delivered-order
populations, evaluation coverage, on-time and
late counts, delivery averages, and consistency
checks reconciled with Power BI.

### SQL-2: Late Severity Distribution

Status:
PASS — Full-history and Q1 severity bands
reconciled with DAX and the Power BI dashboard.

Full-history severity bands:

| Late Delivery Band | Orders |
|---|---:|
| 1–3 days | 1,870 |
| 4–7 days | 1,802 |
| 8–14 days | 1,478 |
| 15+ days | 1,384 |
| **Total** | **6,534** |

Q1 2018 delivered severity bands:

| Late Delivery Band | Orders |
|---|---:|
| 1–3 days | 628 |
| 4–7 days | 708 |
| 8–14 days | 641 |
| 15+ days | 680 |
| **Total** | **2,657** |

### SQL-3: Monthly Purchase-Cohort Validation

Status:
PASS — Monthly fulfillment counts, on-time
rates and average delivery days reconciled
between PostgreSQL and Power BI.

January, February and March 2018 were included
in the monthly comparison.

---

## 11. Cross-Visual Interactions

### Incoming Slicer Interactions

Purchase Date:
Filters all six cards and four charts.

Order Status:
Filters all six cards and four charts.

### Monthly On-Time Rate Chart

Filters other reporting visuals by selected
purchase month.

Does not rewrite slicer selections.

### Monthly Delivery Days Chart

Filters other reporting visuals by selected
purchase month.

Does not rewrite slicer selections.

### On-Time vs Late Stacked Chart

Outgoing interactions:
None.

Reason:
On-time and late are measure series, not a
shared status dimension.

### Late Delivery Severity Chart

Outgoing interactions:
None.

Reason:
Avoid unexpectedly restricting headline measures
to fact-level late-severity selections.

### Reset

Clear all slicers button restores default
unfiltered data.

Monthly chart point selections may require
independent clearing.

---

## 12. Dashboard Interaction QA

- [x] Purchase Date filters all six cards.
- [x] Purchase Date filters all four charts.
- [x] Order Status filters all six cards.
- [x] Order Status filters all four charts.
- [x] Monthly on-time line filters by purchase month.
- [x] Monthly average-days line filters by purchase month.
- [x] Stacked-column outgoing interactions are None.
- [x] Severity-chart outgoing interactions are None.
- [x] Q1 delivered filters return verified Q1 metrics.
- [x] Clear all slicers restores full-history values.
- [x] Chart selections are cleared separately.

---

## 13. Visual Design QA

- [x] Page title displays `Order Fulfillment`.
- [x] Six KPI cards are aligned and not truncated.
- [x] All four chart titles are readable.
- [x] Monthly X-axis labels are visible.
- [x] Month sorting is chronological.
- [x] Rate charts use percentage formatting.
- [x] Day-based KPIs show two decimal places.
- [x] Stacked chart uses teal for on-time.
- [x] Stacked chart uses amber for late.
- [x] Severity chart displays all four bands.
- [x] Severity chart uses ascending severity order.
- [x] Severity counts are exact integers.
- [x] Tooltips show appropriate eligible populations.
- [x] Editing gridlines are hidden.
- [x] No redundant auto-generated chart subtitles.
- [x] No clipped labels or overlapping elements.

---

## 14. Data Quality Safeguards

1. The original order population remains 99,441.
2. The delivered-status population remains 96,478.
3. Eight delivered orders lack actual delivery dates.
4. Missing delivery dates are excluded from the
   evaluable-delivery rate denominator.
5. Evaluable delivery outcomes are partitioned into
   on-time and late categories.
6. Severity bands apply only to evaluable late orders.
7. A negative signed delivery variance is not a
   negative elapsed shipping duration.
8. The source records do not establish carrier SLA
   compliance or real-time fulfillment monitoring.
9. Purchase Date is the date role for monthly charts.
10. No PostgreSQL records were deleted or overwritten
    to create late-delivery classifications.

---

## 15. Limitations

### Historical Data

The source covers historical marketplace activity
between 2016 and 2018.

It does not represent current operations.

### Delivery Timeliness

On-time and late calculations are relative to the
source's estimated delivery date at calendar-day
precision.

They do not establish contractual carrier SLA
achievement or financial penalties.

### Missing Timestamps

Orders lacking required delivery timestamps remain
in the Delivered Orders population but are excluded
from evaluable-delivery rates.

### Monthly Averages

Average monthly durations should not be averaged
without weighting to calculate a full-period mean.

The validated DAX measures operate at the eligible
order level.

### Sparse Data

Historical boundary months may contain fewer
eligible orders and should be interpreted cautiously.

### Signed Variance

Negative signed variance indicates earlier delivery
relative to the estimated date.

It does not indicate negative shipping time.

---

## 16. Project File References

Power BI report:
`powerbi/Order_to_Cash_Intelligence.pbix`

Calculated columns:
`powerbi/dax/11_fulfillment_late_delivery_bands.dax`

SQL validation:
`sql/43_powerbi_order_fulfillment_dashboard_validation.sql`

Executive Overview SQL:
`sql/42_powerbi_executive_overview_validation.sql`

Executive Overview QA:
`docs/powerbi_dashboard_01_executive_overview_qa.md`

Order Fulfillment QA:
`docs/powerbi_dashboard_02_order_fulfillment_qa.md`

KPI coverage:
`docs/powerbi_kpi_coverage_final_after_task11.csv`

---


## 17. Final Sign-Off

**Page:** 02 Order Fulfillment

**Final status: PASS**

### Validated Full-History Results

| Metric | Result |
|---|---:|
| Delivered Orders | 96,478 |
| Evaluable Delivered Orders | 96,470 |
| On-Time Orders | 89,936 |
| Late Orders | 6,534 |
| Delivery Evaluation Coverage | 99.99% |
| On-Time Delivery Rate | 93.23% |
| Late Delivery Rate | 6.77% |
| Average Purchase-to-Delivery Days | 12.56 |
| Signed Delivery Variance Days | -11.88 |

### Validated Q1 2018 Delivered Cohort

| Metric | Result |
|---|---:|
| Delivered Orders | 20,627 |
| Evaluable Delivered Orders | 20,627 |
| On-Time Orders | 17,970 |
| Late Orders | 2,657 |
| On-Time Delivery Rate | 87.12% |
| Late Delivery Rate | 12.88% |
| Average Purchase-to-Delivery Days | 15.74 |
| Signed Delivery Variance Days | -9.25 |

### Completed QA

- [x] Full-history DAX baselines verified
- [x] Q1 delivered-cohort baselines verified
- [x] All four late-delivery bands reconciled
- [x] SQL-1 passed
- [x] SQL-2 passed
- [x] SQL-3 passed
- [x] Monthly chart comparisons passed
- [x] Slicer interactions tested
- [x] Outgoing chart interactions tested
- [x] Dashboard visual QA completed
- [x] PBIX and documentation saved

**Final publication status: PASS**

The dashboard retains the complete source
population and uses delivery-evaluable orders
as the denominator for timeliness metrics.

Consolidated release reference:
`docs/powerbi_release_qa_7_5.md`
