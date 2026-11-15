
# Power BI Dashboard QA — Page 05: Product & Seller Performance

**Project:** Order-to-Cash Intelligence Platform

**PBIX:** `powerbi/Order_to_Cash_Intelligence.pbix`

**Page:** `05 Product and Seller Performance`

**Phase:** Step 7.4 — Task 5

**Status:** PASS — Product and Seller dashboard validated through full-history and Q1 delivered-cohort DAX/SQL reconciliation, category and seller ranking checks, interactions, and final visual QA.

**Source:** PostgreSQL `olist_analytics`, analytics layer

**Currency:** BRL / R$

---

## 1. Business Purpose

This dashboard analyzes:

- Recorded order-item activity
- Item-price and freight contribution
- Distinct products with order-item activity
- Distinct sellers with order-item activity
- Multi-order seller participation
- Top 10 seller item-price concentration
- Top product categories
- Purchase-month item and seller performance

It is a descriptive historical analytics page.

Recorded item-price volume is not recognized
revenue, seller profit, or payment settlement.

---

## 2. Semantic Model

Primary fact:
`analytics.fact_order_items`

Grain:
One order-item entry.

Relevant dimensions:
- dim_product
- dim_seller
- dim_purchase_date
- dim_order_status

Relationships:
Single-direction dimension-to-fact.

Product and Seller dimensions filter the
Order Items fact.

They do not automatically allocate whole-order
payment values to individual sellers or products.

---

## 3. Page Configuration

Canvas:
1280 x 720

Aspect ratio:
16:9

Page heading:
Product & Seller Performance

Template:
Duplicated Page 04.

Theme:
- Navy: #17324D
- Teal: #117F7A
- Blue: #567FA6
- Page background: #F5F7FA
- Visual background: #FFFFFF
- Borders: #E1E8EF

Slicers:
- Purchase Date
- Order Status

Clear all slicers button:
Retained.

---

## 4. KPI Cards

| Card | DAX Measure | Full Dataset |
|---|---|---:|
| Order Item Entries | [Order Item Entries] | 112,650 |
| Recorded Item Price | [Recorded Item Price] | R$13,591,643.70 |
| Products With Items | [Products With Item Records] | 32,951 |
| Active Sellers | [Sellers With Item Records] | 3,095 |
| Multi-Order Seller Share | [Multi-Order Seller Share] | 81.55% |
| Top 10 Seller Concentration | [Top 10 Seller Item-Price Concentration] | 13.15% |

Additional supporting measures:
- [Recorded Freight Amount]
- [Seller-Order Associations]
- [Sellers With Multiple Distinct Orders]
- [Product Category Item-Price Share]
- [Top 10 Seller Item Price (Dashboard)]

---

## 5. Business Definitions

### Order Item Entries

Count of source item entries.

Each row represents an order-item record.

Full baseline:
112,650.

### Recorded Item Price

Sum of source-recorded item prices.

Excludes freight.

Full baseline:
R$13,591,643.70.

### Active Products

Distinct product IDs represented in the
filtered Order Items population.

Full baseline:
32,951.

### Active Sellers

Distinct seller IDs represented in the
filtered Order Items population.

Full baseline:
3,095.

### Seller-Order Associations

Distinct combinations of seller_id and order_id.

An order involving two sellers may contribute
two associations.

Full baseline:
100,010.

### Multi-Order Seller Share

Sellers associated with at least two distinct
orders divided by active sellers in the
selected filter context.

Full baseline:
81.55%.

### Top 10 Seller Concentration

Item-price total attributed to the ten
highest-value eligible sellers divided by
total eligible item-price value.

The ranking uses seller_id as a deterministic
tie-breaker.

Seller filters are removed for the benchmark.
Applicable non-seller filters are preserved.

Full baseline:
13.15%.

---

## 6. Chart Inventory

### Chart 1: Recorded Item Price & Freight by Purchase Month

Type:
Stacked column.

Axis:
dim_purchase_date[Purchase Month Label]

Values:
- [Recorded Item Price]
- [Recorded Freight Amount]

Tooltip:
[Order Item Entries]

The combined monthly column shows recorded
item price plus recorded freight.

It does not represent accounting revenue.

### Chart 2: Top 10 Product Categories by Item Price

Type:
Clustered horizontal bar.

Category:
Actual category reporting label from dim_product.

Value:
[Recorded Item Price]

Tooltips:
- [Product Category Item-Price Share]
- [Order Item Entries]

Filter:
Top 10 by Recorded Item Price.

If only category_status is available, use
Item Price by Catalog Classification instead
and document that distinction.

Untranslated and missing-category item prices
must remain represented in the complete totals.

### Chart 3: Top 10 Sellers by Recorded Item Price

Type:
Clustered horizontal bar.

Category:
dim_seller[Seller Display ID] if unique;
otherwise seller_id.

Value:
[Recorded Item Price]

Tooltips:
- [Seller-Order Associations]
- [Order Item Entries]

Filter:
Top 10 by Recorded Item Price.

The sum of displayed sellers should match
the independently validated Top 10 value.

### Chart 4: Multi-Order Seller Share by Purchase Month

Type:
Line chart.

Axis:
dim_purchase_date[Purchase Month Label]

Value:
[Multi-Order Seller Share]

Tooltips:
- [Sellers With Item Records]
- [Sellers With Multiple Distinct Orders]
- [Seller-Order Associations]

Each purchase-month share is recalculated
within that month's item population.

---

## 7. Full-Dataset Baselines

| Metric | Expected |
|---|---:|
| Item Entries | 112,650 |
| Recorded Item Price | R$13,591,643.70 |
| Recorded Freight | R$2,251,909.54 |
| Item Price + Freight | R$15,843,553.24 |
| Active Products | 32,951 |
| Active Sellers | 3,095 |
| Seller-Order Associations | 100,010 |
| Sellers With Multiple Distinct Orders | 2,524 |
| Multi-Order Seller Share | 81.55% |
| Top 10 Seller Item Price | R$1,787,241.74 |
| Top 10 Seller Concentration | 13.15% |

---

## 8. Product Classification Baselines

| Category Status | Item Price |
|---|---:|
| TRANSLATED | R$13,406,593.94 |
| MISSING_SOURCE_CATEGORY | R$179,535.28 |
| UNTRANSLATED | R$5,514.48 |
| Total | R$13,591,643.70 |

All category-status amounts reconcile to
the recorded item-price total.

The TRANSLATED classification accounts for
98.64% of recorded item-price value.

This is a catalog-label quality measure,
not a product-performance category by itself.

---

## 9. Q1 2018 Delivered-Order Cohort

Purchase Date:
January 1 through March 31, 2018.

Order Status:
delivered.

| Metric | Expected |
|---|---:|
| Item Entries | 23,572 |
| Recorded Item Price | R$2,704,438.38 |
| Active Products | 8,990 |
| Recorded Freight | R$460,215.73 |
| Active Sellers | 1,351 |
| Seller-Order Associations | 20,885 |
| Multi-Order Sellers | 1,064 |
| Multi-Order Seller Share | 78.76% |
| Top 10 Seller Item Price | R$393,589.46 |
| Top 10 Seller Concentration | 14.55% |

Q1 translated category item price:
R$2,653,997.57.

Q1 translated category share:
98.13%.

---

## 10. DAX Validation

### Check F1

Full-history and Q1 product/seller KPIs.

Status:
PASS — reconciled with the expected DAX and PostgreSQL results.

### Check F2

Expected:
- Item and freight difference = 0.00
- Item order coverage difference = 0
- Five population checks = TRUE
- Top 10 numerator difference = 0.00
- Category-status price difference = 0.00

Status:
PASS — reconciled with the expected DAX and PostgreSQL results.

### Check F3

Top 10 Seller ID and item-price ranking.

Expected Top 10 sum:
R$1,787,241.74.

Status:
PASS — reconciled with the expected DAX and PostgreSQL results.

### Check F4

Monthly aggregation.

Expected:
- Item Entries: 112,650
- Item Price: R$13,591,643.70
- Freight: R$2,251,909.54
- All differences: 0

Status:
PASS — reconciled with the expected DAX and PostgreSQL results.

---

## 11. Independent PostgreSQL Validation

SQL file:
sql/46_powerbi_product_seller_dashboard_validation.sql

### SQL-0

Verify category label column names.

Status:
PASS — reconciled with the expected DAX and PostgreSQL results.

### SQL-1

Full-data and Q1 item and seller KPI populations.

Expected:
Two cohorts matching DAX Check F1.

Status:
PASS — reconciled with the expected DAX and PostgreSQL results.

### SQL-2

Top 10 Seller ranking.

Expected:
Ten sellers per cohort, matching DAX.

Status:
PASS — reconciled with the expected DAX and PostgreSQL results.

### SQL-3

Top Product Category totals.

Expected:
Category names and amounts match Power BI,
using the same category-label grouping.

Status:
PASS — reconciled with the expected DAX and PostgreSQL results.

### SQL-4

Monthly item and seller statistics.

Compare at least:
- January 2018
- February 2018
- March 2018

Status:
PASS — reconciled with the expected DAX and PostgreSQL results.

### SQL-5

Catalog classification item-price reconciliation.

Expected:
No missing category-status value is dropped.

Status:
PASS — reconciled with the expected DAX and PostgreSQL results.

---

## 12. Interaction Configuration

Purchase Date slicer:
Filter all six cards and four charts.

Order Status slicer:
Filter all six cards and four charts.

Monthly Item Price & Freight stacked chart:
Outgoing interactions None.

Top 10 Product Categories:
Outgoing interactions None.

Top 10 Sellers:
Outgoing interactions None.

Monthly Multi-Order Seller Share line:
Filters other reporting visuals by purchase month.

Top 10 Seller concentration deliberately
ignores Seller dimension selection while
preserving applicable non-seller filters.

---

## 13. Interaction QA

- [x] Purchase Date filters all six KPI cards.
- [x] Purchase Date filters all four charts.
- [x] Order Status filters all six KPI cards.
- [x] Order Status filters all four charts.
- [x] Full-history values match baselines.
- [x] Q1 2018 delivered values match baselines.
- [x] Seller ranking shows ten distinct sellers.
- [x] Category ranking matches SQL grouping.
- [x] Monthly Seller Share selection filters by month.
- [x] Seller ranking outgoing interactions are None.
- [x] Category ranking outgoing interactions are None.
- [x] Reset restores full historical values.

---

## 14. Visual QA

- [x] Page title is Product & Seller Performance.
- [x] Six KPI cards are correctly formatted.
- [x] Monthly charts use chronological labels.
- [x] Item Price and Freight are distinct series.
- [x] Category chart uses the correct category label.
- [x] Top 10 Seller chart has readable Seller IDs.
- [x] Both Top 10 rankings are sorted descending.
- [x] Monthly Seller Share uses a percentage axis.
- [x] Tooltips provide exact values.
- [x] No chart retains review-related visual filters.
- [x] No redundant autogenerated subtitles.
- [x] Editing gridlines are hidden.
- [x] No clipped text or overlapping visuals.

---

## 15. Data and Modeling Safeguards

1. Item prices exclude freight.

2. Recorded Item Price is not accounting revenue
   or recognized sales.

3. Freight is recorded freight charged in the
   source dataset, not verified carrier cost.

4. Active Products means products represented in
   the filtered Order Items fact.

5. Active Sellers means sellers represented in
   the filtered Order Items fact.

6. Seller-order associations are distinct pairs,
   not distinct marketplace orders.

7. Multi-order seller share is recalculated
   within the active filter context.

8. Full-period seller-share percentages should
   not be calculated as simple averages of
   monthly seller-share percentages.

9. Top 10 seller concentration is based on
   recorded item-price totals.

10. Top 10 concentration does not measure
    seller profit or financial settlement.

11. Source category quality exceptions remain
    included in overall item-price totals.

12. Seller labels are for display; seller_id
    remains the canonical unique identifier.

13. Sparse historical boundary months should
    not be interpreted as confirmed downturns.

14. Purchase Month is the associated order's
    purchase month.

---

## 16. Project References

Power BI report:
powerbi/Order_to_Cash_Intelligence.pbix

DAX:
powerbi/dax/14_product_seller_dashboard_helpers.dax

SQL:
sql/46_powerbi_product_seller_dashboard_validation.sql

QA:
docs/powerbi_dashboard_05_product_seller_qa.md

KPI coverage:
docs/powerbi_kpi_coverage_final_after_task11.csv

---


## 17. Final Sign-Off

**Page:** 05 Product & Seller Performance

**Final status: PASS**

### Full-History Results

| Metric | Result |
|---|---:|
| Order Item Entries | 112,650 |
| Recorded Item Price | R$13,591,643.70 |
| Recorded Freight | R$2,251,909.54 |
| Products With Item Records | 32,951 |
| Active Sellers | 3,095 |
| Seller-Order Associations | 100,010 |
| Multi-Order Sellers | 2,524 |
| Multi-Order Seller Share | 81.55% |
| Top 10 Seller Item Price | R$1,787,241.74 |
| Top 10 Concentration | 13.15% |

### Q1 2018 Delivered Cohort

| Metric | Result |
|---|---:|
| Order Item Entries | 23,572 |
| Recorded Item Price | R$2,704,438.38 |
| Recorded Freight | R$460,215.73 |
| Active Products | 8,990 |
| Active Sellers | 1,351 |
| Seller-Order Associations | 20,885 |
| Multi-Order Sellers | 1,064 |
| Multi-Order Seller Share | 78.76% |
| Top 10 Seller Item Price | R$393,589.46 |
| Top 10 Concentration | 14.55% |

### Completed QA

- [x] Six headline KPI cards validated
- [x] Four charts validated
- [x] DAX F1 through F4 passed
- [x] SQL-0 through SQL-5 passed
- [x] Category grouping verified
- [x] Seller rankings reconciled
- [x] Full-history and Q1 values reconciled
- [x] Month-selection interactions tested
- [x] Ranking chart outgoing interactions verified
- [x] No inherited review-related filters
- [x] Final dashboard screenshot reviewed
- [x] PBIX and QA documentation saved

### Presentation Note

The Top 10 seller and product-category
rankings contain all ten entries.

The compact dashboard layout permits
vertical scrolling within those visuals.

This does not change the Top N filter,
rank order, metric calculation or
SQL reconciliation.

Separate expanded-chart screenshots
may be added for portfolio presentation.

**Final publication status: PASS**

Seller item-price contribution measures
recorded source item prices, not seller
profit or recognized revenue.

Consolidated release reference:
`docs/powerbi_release_qa_7_5.md`
