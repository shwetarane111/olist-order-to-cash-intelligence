
# Power BI Dashboard QA — Page 04: Customer & Satisfaction

**Project:** Order-to-Cash Intelligence Platform

**PBIX:** `powerbi/Order_to_Cash_Intelligence.pbix`

**Page:** `04 Customer and Satisfaction`

**Phase:** Step 7.4 — Task 4

**Status:** PASS — Customer and Satisfaction dashboard validated against historical and Q1 purchase-cohort baselines, DAX and PostgreSQL reconciliations, review-date role checks, and final interaction QA.

**Source:** PostgreSQL `olist_analytics`, analytics layer

---

## 1. Business Purpose

This dashboard analyzes:

- Customer identity counts
- Repeat ordering within selected cohorts
- Review coverage
- Average review scores
- High-rating review share
- Written feedback availability
- Purchase-month customer behavior
- Review-score distribution

It combines order-level customer metrics
with review-record-level satisfaction metrics.

The dashboard is historical, not live.

---

## 2. Semantic Model

### Order-Based Customer Metrics

Primary fact:
`analytics.fact_orders`

Grain:
One order per row.

Customer identity:
`customer_unique_id`

Relevant measures:
- [Customer Identities With Orders]
- [Repeat-Order Customer Identities]
- [Repeat Customer Share (Dashboard)]
- [Orders With Reviews]
- [Review Coverage Rate]

### Review-Based Metrics

Primary fact:
`analytics.fact_order_reviews`

Grain:
One review/order record per row.

Relevant measures:
- [Review Records]
- [Average Review Score]
- [High-Rating Review Records]
- [High-Rating Review Share]
- [Reviews With Written Feedback]
- [Reviews Without Written Feedback]
- [Written Feedback Availability Rate]

Review records and distinct reviewed orders
are not interchangeable.

Some orders have multiple review records.

---

## 3. Date Roles

### Purchase Date

Shared slicer:
`dim_purchase_date[date]`

Used for:
- Customer purchase-cohort analysis
- Review records associated with purchased orders
- All monthly chart axes on Page 04

### Review Creation Date

Dimension:
`dim_review_date`

This is not included as a page slicer.

It filters review activity by review creation
date but does not filter fact_orders.

Review coverage is an order purchase-cohort
metric and must not be interpreted as
review-creation-day coverage.

---

## 4. Design and Layout

Canvas:
1280 × 720

Aspect ratio:
16:9

Design source:
Duplicated Page 03.

Colors:
- Navy: #17324D
- Teal: #117F7A
- Blue: #567FA6
- Gray: #A8B8C7
- White: #FFFFFF
- Background: #F5F7FA
- Borders: #E1E8EF

Slicers:
- Purchase Date (Between)
- Order Status (Dropdown)

Reset:
Clear all slicers button.

---

## 5. KPI Cards

| Card | Measure | Full Dataset |
|---|---|---:|
| Customer Identities | [Customer Identities With Orders] | 96,096 |
| Repeat Customer Share | [Repeat Customer Share (Dashboard)] | 3.12% |
| Review Coverage | [Review Coverage Rate] | 99.23% |
| Average Review Score | [Average Review Score] | 4.09 |
| High-Rating Share | [High-Rating Review Share] | 77.07% |
| Written Feedback | [Written Feedback Availability Rate] | 43.03% |

Supporting populations:
- Total Orders: 99,441
- Repeat Customer Identities: 2,997
- Orders With Reviews: 98,673
- Review Records: 99,224
- High-Rating Reviews: 76,470
- With Written Feedback: 42,697
- Without Written Feedback: 56,527

---

## 6. Business Definitions

### Repeat Customer Share

Repeat-order customer identities divided by
customer identities represented in the
current filtered order population.

A customer is repeat-ordering when they
have more than one order in that cohort.

This is not a longitudinal retention metric.

### Review Coverage

Orders with at least one associated review
divided by all orders in the selected cohort.

This uses the Orders fact.

### Average Review Score

Arithmetic average of review-record scores.

Review-record weighted, not order weighted.


### Average Review Score Validation

- Overall Average Review Score: 4.09
- Direct Review Fact Average: 4.09
- Total Review Records: 99,224
- Unweighted Average of Monthly Scores: 3.82
- Measure validation: PASS

The dashboard uses the review-record-weighted average
of 4.09 for the full historical dataset.

The unweighted mean of monthly averages (3.82)
is not used as the overall satisfaction KPI.

Monthly review scores may differ from the overall
average because each month has a different review
population.


### High-Rating Share

Review records with score 4 or 5 divided by
review records with valid review scores.

### Written Feedback Availability

Review records with at least a written title
or review message divided by all review records.

A review without text may still have
a valid numeric review score.

---

## 7. Chart Inventory

### Chart 1: Repeat Customer Share by Purchase Month

Type:
Line chart.

X-axis:
dim_purchase_date[Purchase Month Label]

Y-axis:
[Repeat Customer Share (Dashboard)]

Tooltips:
- [Customer Identities With Orders]
- [Repeat-Order Customer Identities]

### Chart 2: Average Review Score by Purchase Month

Type:
Line chart.

X-axis:
dim_purchase_date[Purchase Month Label]

Y-axis:
[Average Review Score]

Tooltips:
- [Review Records]

### Chart 3: Review Score Distribution

Type:
Clustered bar chart.

Y-axis:
fact_order_reviews[review_score]

X-axis:
[Review Records]

Sort:
Review score descending.

Expected:
Five score categories.

### Chart 4: Written Feedback by Purchase Month

Type:
Stacked column chart.

X-axis:
dim_purchase_date[Purchase Month Label]

Values:
- [Reviews With Written Feedback]
- [Reviews Without Written Feedback]

Tooltips:
- [Review Records]
- [Written Feedback Availability Rate]

Any inherited financial reconciliation filters
must be removed.

---

## 8. Full-Dataset Baselines

| Metric | Expected |
|---|---:|
| Total Orders | 99,441 |
| Customer Identities | 96,096 |
| Repeat Customer Identities | 2,997 |
| Repeat Customer Share | 3.12% |
| Orders With Reviews | 98,673 |
| Review Coverage | 99.23% |
| Review Records | 99,224 |
| Average Review Score | 4.09 |
| High-Rating Reviews | 76,470 |
| High-Rating Share | 77.07% |
| With Written Feedback | 42,697 |
| Without Written Feedback | 56,527 |
| Written Feedback Share | 43.03% |

---

## 9. Full-Dataset Review Score Distribution

| Score | Review Records |
|---|---:|
| 1 | 11,424 |
| 2 | 3,151 |
| 3 | 8,179 |
| 4 | 19,142 |
| 5 | 57,328 |
| Total | 99,224 |

High ratings:
19,142 + 57,328 = 76,470

Written feedback partition:
42,697 + 56,527 = 99,224

Invalid review-score records:
0

---

## 10. Q1 2018 Delivered-Purchase Cohort

Purchase Date:
January 1 through March 31, 2018.

Order Status:
delivered.

| Metric | Expected |
|---|---:|
| Total Orders | 20,627 |
| Customer Identities | 20,211 |
| Repeat Customer Identities | 400 |
| Repeat Customer Share | 1.98% |
| Orders With Reviews | 20,468 |
| Review Coverage | 99.23% |
| Review Records | 20,630 |
| Average Review Score | 3.94 |
| High-Rating Reviews | 14,994 |
| High-Rating Share | 72.68% |
| With Written Feedback | 8,640 |
| Without Written Feedback | 11,990 |
| Written Feedback Share | 41.88% |

### Q1 Consistency

8,640 + 11,990 = 20,630

Review coverage denominator:
20,627 orders.

Repeat customer denominator:
20,211 distinct customer identities.

Q1 review-score distribution:
Record the five independently validated
SQL-2 values after executing the audit.

---

## 11. DAX Validation

### Check F1

Full-history and Q1 KPI reconciliation.

Status: PASS — validated against the expected baseline and independent audit results.

### Check F2

Expected:
- Customer identity partition difference: 0
- Reviewed order cross-fact difference: 0
- Written feedback partition difference: 0
- High-rating records do not exceed review records: TRUE
- Repeat share difference: 0
- Review coverage difference: 0

Status: PASS — validated against the expected baseline and independent audit results.

### Check F3

Full-data score counts match
the five established review-score baselines.

Status: PASS — validated against the expected baseline and independent audit results.

### Check F4

Expected monthly aggregation:
- Orders: 99,441
- Review Records: 99,224
- With Written Feedback: 42,697
- Without Written Feedback: 56,527
- All partition differences: 0

Status: PASS — validated against the expected baseline and independent audit results.

### Check H7

Review Creation Date role isolation.

Expected:
- Peak-date review records: 463
- Customer Identity difference: 0
- Purchase-cohort Review Coverage difference: 0

Status: PASS — validated against the expected baseline and independent audit results.

---

## 12. Independent PostgreSQL Audit

File:
`sql/45_powerbi_customer_satisfaction_dashboard_validation.sql`

### SQL-1

Full-history and Q1 customer and
review KPI populations.

Status: PASS — validated against the expected baseline and independent audit results.

### SQL-2

Review-score distribution for
full history and Q1 delivered cohort.

Status: PASS — validated against the expected baseline and independent audit results.

### SQL-3

Monthly customer and review performance.

Compare January, February and March 2018
against the Power BI charts.

Status: PASS — validated against the expected baseline and independent audit results.

### SQL-4

Independent review-creation-date analysis.

Status: PASS — validated against the expected baseline and independent audit results.

---

## 13. Interaction Configuration

Purchase Date slicer:
Filters all six cards and four charts.

Order Status slicer:
Filters all six cards and four charts.

Repeat Customer Share monthly line:
Filters other visuals by purchase month.

Average Review Score monthly line:
Filters other visuals by purchase month.

Review Score Distribution:
Outgoing interactions set to None.

Written Feedback stacked chart:
Outgoing interactions set to None.

Reason:
Review-record selections must not silently
rewrite order-grain customer KPIs.

---

## 14. Interaction QA

- [x] Both slicers filter all six cards.
- [x] Both slicers filter all four charts.
- [x] Full-history cards match baselines.
- [x] Q1 delivered cards match baselines.
- [x] Repeat Share line filters by purchase month.
- [x] Average Score line filters by purchase month.
- [x] Score Distribution outgoing interactions are None.
- [x] Written Feedback outgoing interactions are None.
- [x] Clear all slicers restores historical values.
- [x] Chart selections are cleared separately.

---

## 15. Visual QA

- [x] Page title is Customer & Satisfaction.
- [x] Six cards are aligned.
- [x] All measures are formatted correctly.
- [x] Monthly labels are chronological.
- [x] Monthly chart tooltips show populations.
- [x] Five review-score categories are visible.
- [x] Exact review-score counts are accessible.
- [x] Feedback colors and legend are clear.
- [x] Inherited financial filters are removed.
- [x] Editing gridlines are hidden.
- [x] No redundant field-name subtitles.
- [x] No truncated titles or overlaps.

---

## 16. Data Interpretation and Limitations

1. Customer identities are distinct pseudonymous
   customer IDs, not verified real-world individuals.

2. Repeat ordering is measured inside the
   selected purchase cohort.

3. Monthly repeat shares cannot be averaged to
   reproduce full-history repeat share.

4. Review counts use review-record grain.

5. An order may have multiple review records.

6. Review Coverage uses the Orders fact.

7. Average Review Score is review-record weighted.

8. Reviews without written text can still
   contain valid numeric ratings.

9. Monthly review figures are grouped by
   associated order purchase month, not
   review submission month.

10. The report contains historical data.
    Results should not be described as
    current satisfaction levels.

11. Product and Seller filters are not included
    because they do not automatically filter
    customer and review facts in this model.

---

## 17. File References

PBIX:
`powerbi/Order_to_Cash_Intelligence.pbix`

DAX:
`powerbi/dax/13_customer_satisfaction_dashboard_measures.dax`

SQL:
`sql/45_powerbi_customer_satisfaction_dashboard_validation.sql`

QA:
`docs/powerbi_dashboard_04_customer_satisfaction_qa.md`

KPI coverage:
`docs/powerbi_kpi_coverage.csv`

---


## 18. Final Sign-Off

**Page:** 04 Customer & Satisfaction

**Final status: PASS**

### Full-History Results

| Metric | Result |
|---|---:|
| Customer Identities | 96,096 |
| Repeat-Order Customer Identities | 2,997 |
| Repeat Customer Share | 3.12% |
| Review Records | 99,224 |
| Distinct Reviewed Orders | 98,673 |
| Review Coverage | 99.23% |
| Average Review Score | 4.09 |
| High-Rating Share | 77.07% |
| Written Feedback Availability | 43.03% |

### Q1 2018 Delivered Cohort

| Metric | Result |
|---|---:|
| Customer Identities | 20,211 |
| Repeat Customer Identities | 400 |
| Repeat Customer Share | 1.98% |
| Review Records | 20,630 |
| Distinct Reviewed Orders | 20,468 |
| Review Coverage | 99.23% |
| Average Review Score | 3.94 |
| High-Rating Share | 72.68% |
| Written Feedback Availability | 41.88% |

### Review Score Control

The full-history Average Review Score is
calculated from individual review records.

The validated headline value is 4.09 / 5.

A separately observed unweighted mean of
monthly review averages was 3.82.

That unweighted mean is not used as the
dashboard headline metric.

### Completed QA

- [x] Customer identity populations reconciled
- [x] Repeat customer share verified
- [x] Review record and coverage checks passed
- [x] Review score distribution reconciled
- [x] Written feedback partition reconciled
- [x] DAX F1–F4 passed
- [x] DAX H7 review-date role check passed
- [x] SQL-1 through SQL-4 passed
- [x] Purchase-month filtering validated
- [x] Visual interactions validated
- [x] Dashboard screenshot reviewed
- [x] PBIX and QA documentation saved

**Final publication status: PASS**

Review metrics use their documented record
grains and date roles. Purchase-month
satisfaction trends refer to orders purchased
during those months, not necessarily reviews
created within the same months.

Consolidated release reference:
`docs/powerbi_release_qa_7_5.md`
