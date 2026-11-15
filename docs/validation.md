
# Validation & Quality Assurance

## 1. Validation Objective

The Order-to-Cash Intelligence Platform uses independent PostgreSQL and Power BI DAX checks to validate its historical business metrics.

The purpose is to confirm that dashboard results are consistent with the analytical warehouse and with the expected data grain.

A visual rendering successfully is not sufficient evidence of data correctness.

## 2. Quality Assurance Levels

### Source Profiling

Check source data for:

- Row counts
- Duplicate business keys
- Missing values
- Data-type consistency
- Invalid or anomalous records

### Warehouse Validation

Verify:

- Analytical table population
- Grain and primary-key expectations
- Dimension-reference completeness
- Source-to-analytics reconciliation
- Financial consistency
- Geographic-reference quality

### Power BI Validation

Verify:

- Model relationships
- Date-role behavior
- KPI denominators
- DAX measures
- Slicer filtering
- Cross-visual interactions
- Expected full-history and selected-cohort results

### Release Validation

Recheck all six dashboard pages together.

## 3. Validated Historical Population

| Fact | Record Count |
|---|---:|
| Orders | 99,441 |
| Order Items | 112,650 |
| Payments | 103,886 |
| Reviews | 99,224 |

Additional populations:

- Customer identities with orders: 96,096
- Active products: 32,951
- Active sellers: 3,095
- Customer geographic reference rows: 15,034

## 4. Standard Test Cohorts

### Full Historical Dataset

Purchase Date: All

Order Status: All

### Q1 2018 Delivered

Purchase Date:
2018-01-01 through 2018-03-31

Order Status:
delivered

The date filter is based on order purchase date.

## 5. Dashboard-Level SQL Audit Files

| Page | File |
|---|---|
| Executive Overview | `42_powerbi_executive_overview_validation.sql` |
| Order Fulfillment | `43_powerbi_order_fulfillment_dashboard_validation.sql` |
| Financial Reconciliation | `44_powerbi_financial_reconciliation_dashboard_validation.sql` |
| Customer & Satisfaction | `45_powerbi_customer_satisfaction_dashboard_validation.sql` |
| Product & Seller Performance | `46_powerbi_product_seller_dashboard_validation.sql` |
| Geographic Coverage & Data Quality | `47_powerbi_geographic_dashboard_validation.sql` |

All are located in the `sql/` directory.

The earlier warehouse-development and data-quality SQL files remain available in the same project directory.

## 6. Consolidated Release Validation

PostgreSQL:

`sql/48_powerbi_cross_page_release_validation.sql`

DAX Query View:

`powerbi/dax/16_cross_page_release_checks.dax`

These checks independently compare:

- Orders and delivery populations
- Financial reconciliation results
- Customer identities and review activity
- Item price, freight, and payment amounts
- Product and seller activity
- Geographic completeness
- Full-history versus Q1 2018 delivered cohorts

## 7. Key Financial Reconciliation

Full historical dataset:

| Metric | Result |
|---|---:|
| Total Orders | 99,441 |
| Comparable Orders | 98,665 |
| Matched Orders | 98,089 |
| Mismatched Orders | 576 |
| Coverage Gaps | 776 |
| Financial Match Rate | 99.42% |
| Net Comparable Difference | R$2,870.39 |
| Absolute Financial Discrepancy | R$3,271.95 |

Population checks:

98,089 + 576 = 98,665.

98,665 + 776 = 99,441.

The absolute discrepancy is greater than or equal to the magnitude of the net discrepancy.

## 8. Delivery Reconciliation

Full historical dataset:

| Metric | Result |
|---|---:|
| Delivered Orders | 96,478 |
| Evaluable Delivered Orders | 96,470 |
| On-Time Orders | 89,936 |
| Late Orders | 6,534 |

89,936 + 6,534 = 96,470.

The remaining eight delivered orders are not delivery-evaluable under the implemented rules.

The on-time rate is calculated using 96,470 delivery-evaluable orders.

## 9. Review Reconciliation

| Metric | Result |
|---|---:|
| Review Records | 99,224 |
| Distinct Reviewed Orders | 98,673 |
| High-Rating Reviews | 76,470 |
| Reviews With Written Feedback | 42,697 |
| Reviews Without Written Feedback | 56,527 |

Written-feedback partition:

42,697 + 56,527 = 99,224.

The full-history review-record-weighted average score is 4.09.

The unweighted mean of monthly review-score averages was independently observed as 3.82 and is not used for the headline KPI.

## 10. Geographic Reconciliation

Full history:

| Fact | Total | Map-Ready |
|---|---:|---:|
| Orders | 99,441 | 99,162 |
| Order Items | 112,650 | 112,347 |
| Payments | 103,886 | 103,598 |
| Reviews | 99,224 | 98,944 |

Order geographic partition:

99,162 map-ready
+ 278 missing references
+ 1 flagged coordinate
= 99,441 orders.

Missing customer-geography dimension links:
0.

## 11. Cross-Page Release Results

The project completed the following final release checks:

| Release Check | Status |
|---|---|
| 36 KPI cards | PASS |
| Full-history regression | PASS |
| Q1 2018 delivered regression | PASS |
| DAX-R1 | PASS |
| DAX-R2 | PASS |
| DAX-R3 | PASS |
| PostgreSQL SQL-R1 | PASS |
| PostgreSQL SQL-R2 | PASS |
| PostgreSQL SQL-R3 | PASS |
| PostgreSQL SQL-R4 | PASS |
| Model relationship audit | PASS |
| Chart interactions and slicers | PASS |
| Six-page screenshot review | PASS |

These statuses record the results of the completed local project release QA.

They do not mean that the original dataset is free from every conceivable data-quality issue.

## 12. Data Interpretation Controls

The QA process explicitly distinguishes:

- Total orders from comparable orders
- Matched orders from records with missing financial coverage
- Recorded payment amounts from recognized revenue
- Order-item entries from order counts
- Customer identities from order records
- Review records from distinct reviewed orders
- Purchase dates from review creation dates
- Seller-order associations from marketplace order counts
- Map-ready records from geographic exceptions

## 13. Limitations

Validation confirms consistency against the implemented source and rules.

It does not independently verify:

- Actual bank settlement
- Accounting revenue recognition
- Seller profitability
- Customer identity beyond the pseudonymous source key
- Actual residential or delivery coordinates
- Current marketplace activity
- External business causality

## 14. Detailed Release Evidence

The full six-page sign-off is recorded in:

`docs/powerbi_release_qa_7_5.md`

Each dashboard also has a page-level QA file in `docs/`.

These files should be preserved as part of the project audit trail.
