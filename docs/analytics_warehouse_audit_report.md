# ANALYTICS Warehouse — Final Audit Report

**Project:** Order-to-Cash Intelligence Platform  
**Dataset:** Historical Olist Brazilian E-Commerce Dataset  
**Database:** PostgreSQL `olist_analytics`  
**Schema:** `analytics`  
**Audit version:** 1.0  
**Audit status:** PASS — Approved for Power BI integration, subject to semantic-model validation

## 1. Executive Summary

The ANALYTICS warehouse has been implemented and validated against the audited STAGING and RAW data layers.

The final analytical implementation includes:

- Eight physical dimension tables.
- Four physical fact tables.
- 564,595 records across twelve tables.
- 178 analytical columns.
- Enforced primary keys and 23 validated foreign-key relationships.
- Preserved fact-table grains and source record counts.
- Financial reconciliation and quality checks validated against historical baselines.
- Documented geographic, payment, product, review, and fulfillment exceptions.

All required integrated inventory, grain, relationship, financial, and source-quality baseline checks passed.

**Decision:** The database layer is approved for connection to Power BI. Power BI relationships, DAX measures, filtering, and dashboard outputs require separate validation.

## 2. Final ANALYTICS Model Inventory

| Model | Records | Columns | Grain |
|---|---:|---:|---|
| dim_order_status | 8 | 2 | One status |
| dim_product | 32,951 | 16 | One product |
| dim_seller | 3,095 | 18 | One seller |
| dim_customer | 96,096 | 5 | One customer identity |
| dim_customer_geography | 15,034 | 19 | One customer ZIP/city/state combination |
| dim_purchase_date | 774 | 14 | One calendar date |
| dim_delivery_date | 737 | 14 | One calendar date |
| dim_review_date | 699 | 14 | One calendar date |
| fact_orders | 99,441 | 32 | One order |
| fact_order_items | 112,650 | 13 | One order-item entry |
| fact_payments | 103,886 | 14 | One payment entry |
| fact_order_reviews | 99,224 | 17 | One review record |
| **TOTAL** | **564,595** | **178** | **Multiple grains** |

The combined row count is a model-inventory statistic, not a count of unique marketplace transactions.

All tables passed expected row-count, column-count, logical-key, and physical-primary-key checks.

## 3. Database Relationship Integrity

### Audit Results

- Expected foreign-key relationships: 23.
- Validated and enforced relationships: 23.
- Unexpected dimension gaps: 0.
- Missing parent-order relationships in detailed facts: 0.
- Fact-grain increases after validated joins: 0.
- Cross-fact order-context inconsistencies: 0.

All four fact-to-dimension join paths preserved their original row counts:

| Fact | Validated records |
|---|---:|
| Orders | 99,441 |
| Order Items | 112,650 |
| Payments | 103,886 |
| Reviews | 99,224 |

Shared customer identity, customer geography, order status, and purchase-date keys remain consistent across the facts.

Database foreign keys to the Orders fact enforce referential integrity. They do not authorize direct fact-to-fact filtering relationships in Power BI.

## 4. Financial Integrity

### All-Record Monetary Baselines

| Measure | Amount (BRL) |
|---|---:|
| Recorded item prices | R$13,591,643.70 |
| Recorded freight | R$2,251,909.54 |
| **Recorded item prices + freight** | **R$15,843,553.24** |
| **Recorded payment volume** | **R$16,008,872.12** |

All-record monetary totals matched their corresponding STAGING source amounts and order-level aggregates.

The integrated financial audit returned zero source/fact monetary differences.

### Comparable-Order Reconciliation

| Metric | Verified result |
|---|---:|
| Total orders | 99,441 |
| Comparable orders | 98,665 |
| Matching orders | 98,089 |
| Mismatched orders | 576 |
| Match rate | **99.42%** |
| Orders without item records | 775 |
| Orders without payment records | 1 |
| Orders missing both | 0 |

### Comparable-Order Monetary Totals

| Measure | Amount (BRL) |
|---|---:|
| Item prices + freight | R$15,843,409.78 |
| Recorded payments | R$15,846,280.17 |
| Net payment difference | +R$2,870.39 |
| Sum of absolute differences | R$3,271.95 |
| Sum of positive differences | +R$3,071.17 |
| Sum of negative differences | −R$200.78 |

All reconciliation classifications and missing-value handling checks passed.

One order has R$143.46 in recorded item-plus-freight value but no payment record. This source exception explains the difference between the all-record and comparable-order item totals.

Payment totals outside the comparable population remain distinguishable from comparable-order values.

**Interpretation:** These are comparisons of source-recorded amounts, not verified accounting settlement, recognized revenue, fraud, or recoverable financial losses.

## 5. Fulfillment Performance

| KPI | Verified result |
|---|---:|
| Delivered-status orders | 96,478 |
| Evaluable delivered orders | 96,470 |
| On-time deliveries | 89,936 |
| Late deliveries | 6,534 |
| On-time delivery rate | **93.23%** |
| Late delivery rate | 6.77% |
| Average purchase-to-delivery duration | **12.56 days** |
| Average signed delivery variance | **−11.88 days** |
| Delivered-status orders lacking actual delivery date | 8 |
| Canceled-status orders with actual delivery date | 6 |
| Negative purchase-to-delivery durations | 0 |
| Inconsistent fulfillment classifications | 0 |

Timeliness is calculated at calendar-day precision against the estimated delivery date.

The negative average signed delivery variance indicates delivery occurred, on average, before the estimated date within the evaluable population. It does not imply that every order arrived early.

Missing delivery timestamps and status/date discrepancies are preserved.

## 6. Customer Activity

| Metric | Verified result |
|---|---:|
| Distinct observed customer identities | 96,096 |
| Identities associated with multiple orders | 2,997 |
| Repeat-order identity share | 3.12% |
| Maximum observed orders per identity | 17 |
| Total represented orders | 99,441 |
| Customer-dimension order-count inconsistencies | 0 |

Customer identities use `customer_unique_id`.

Historical dimension attributes describe the full available dataset. Period-specific repeat-customer KPIs must be recalculated from filtered order records.

Repeat ordering is not equivalent to lifetime retention or evidence that all orders were completed purchases.

## 7. Payment Activity and Quality

| Metric | Verified result |
|---|---:|
| Payment entries | 103,886 |
| Orders with payment entries | 99,440 |
| Orders with multiple payment entries | 2,961 |
| Maximum entries for one order | 29 |
| Zero-value entries | 9 |
| Zero-installment entries | 2 |
| Undefined payment methods | 3 |
| Distinct flagged entries | 11 |
| Orders containing flagged entries | 10 |
| Negative payment amounts | 0 |
| Inconsistent payment-quality flags | 0 |

### Recorded Payments by Method

| Method | Entries | Recorded amount (BRL) |
|---|---:|---:|
| Credit card | 76,795 | R$12,542,084.19 |
| Boleto | 19,784 | R$2,869,361.27 |
| Voucher | 5,775 | R$379,436.87 |
| Debit card | 1,529 | R$217,989.79 |
| Not defined | 3 | R$0.00 |

Distinct-order counts across payment methods are not additive because a single order may use multiple payment methods.

The dataset does not establish payment-event timestamps or settlement dates. Payment analysis using Purchase Date must be labeled accordingly.

## 8. Reviews and Customer Satisfaction

| Metric | Verified result |
|---|---:|
| Review records | 99,224 |
| Distinct review IDs | 98,410 |
| Distinct reviewed orders | 98,673 |
| Average review score | 4.09 |
| Four- and five-star review records | 76,470 |
| Reviews without written feedback | 56,527 |
| Reviews containing written feedback | 42,697 |
| Orders with multiple review records | 547 |
| Additional review records beyond one per reviewed order | 551 |
| Maximum review records per order | 3 |
| Orders without review records | 768 |
| Invalid review scores | 0 |
| Inconsistent written-feedback flags | 0 |

The review fact preserves the validated composite key `(review_id, order_id)`.

Review-record-weighted satisfaction measures must be distinguished from order-level review coverage.

The Orders fact includes review-existence indicators so purchase-cohort review coverage can be calculated without multiplying order records.

## 9. Product Data Quality

| Category classification | Products |
|---|---:|
| Translated | 32,328 |
| Untranslated | 13 |
| Missing source category | 610 |
| **Total** | **32,951** |

Additional findings:

- Missing catalog attributes: 610 products.
- Missing physical attributes: 2 products.
- Zero recorded weight: 4 products.
- Missing category display labels after fallback: 0.
- Invalid category classifications: 0.

Source anomalies remain visible through explicit category classifications and quality flags.

## 10. Geographic Quality and Map Coverage

### Customer Geography

The Customer Geography dimension contains 15,034 distinct standardized ZIP/city/state combinations.

It uses a deterministic location key and the validated one-row-per-ZIP geographic reference.

| Fact | Total records | Without ZIP reference | Flagged coordinates | Map-ready records | Coverage |
|---|---:|---:|---:|---:|---:|
| Orders | 99,441 | 278 | 1 | 99,162 | 99.72% |
| Order Items | 112,650 | 302 | 1 | 112,347 | 99.73% |
| Payments | 103,886 | 287 | 1 | 103,598 | 99.72% |
| Reviews | 99,224 | 279 | 1 | 98,944 | 99.72% |

All four geographic integrity checks passed.

The fact-level coverage statistics are measured at different grains and must not be summed as unique customers.

### Seller Geography

| Indicator | Verified result |
|---|---:|
| Total sellers | 3,095 |
| Sellers without geographic reference | 7 |
| Sellers associated with flagged coordinates | 0 |
| Map-ready sellers | 3,088 |
| Map-ready seller coverage | 99.77% |
| Seller/reference label disagreements | 147 |
| Sellers associated with conflicting reference labels | 1,566 |

Unmatched geographic references do not remove corresponding customers, sellers, orders, items, payments, or reviews.

Representative ZIP coordinates are approximate, not precise addresses.

Points flagged outside the broad Brazil screening rectangle remain excluded from published coordinate-based maps pending verification. The rectangle is a heuristic geographic screening rule rather than an authoritative national boundary.

## 11. Date Dimension Integrity

| Dimension | Start date | End date | Calendar rows |
|---|---|---|---:|
| Purchase Date | 2016-09-04 | 2018-10-17 | 774 |
| Delivery Date | 2016-10-11 | 2018-10-17 | 737 |
| Review Date | 2016-10-02 | 2018-08-31 | 699 |

All three calendars passed uniqueness, continuity, attribute-fidelity and source-relationship checks.

Calendar date roles are intentionally separate:

- Purchase Date filters all four facts by associated order purchase date.
- Delivery Date filters Orders by actual customer-delivery date.
- Review Date filters Reviews by review creation date.

No unsupported timezone conversion has been introduced.

## 12. Power BI Readiness Requirements

The PostgreSQL analytical warehouse is ready to connect to Power BI, subject to the following semantic-model checks:

- [ ] Import only the approved analytical fact and dimension models for the primary reporting model.
- [ ] Confirm four fact tables and eight dimensions have the expected row counts after refresh.
- [ ] Configure one-to-many relationships from dimension keys to fact foreign keys.
- [ ] Use single-direction filtering from dimensions to facts.
- [ ] Avoid creating direct fact-to-fact relationships or ambiguous alternate filter paths.
- [ ] Validate Purchase, Delivery and Review Date roles.
- [ ] Configure date labels and chronological sorting.
- [ ] Test monetary aggregations against audited PostgreSQL baselines.
- [ ] Validate ratio measures using filtered numerators and denominators.
- [ ] Verify product and seller filtering does not silently allocate order-level payments.
- [ ] Apply geographic map-ready rules while preserving unmatched records in non-map reporting.
- [ ] Verify review-record versus reviewed-order calculations.
- [ ] Recalculate repeat-customer measures under date and status slicers.
- [ ] Format monetary values as Brazilian Real.
- [ ] Test order-level drill-through deliberately, without enabling broad bidirectional filtering.

The KPI Dictionary contains 55 business definitions. These definitions are not all considered DAX-validated merely because the underlying SQL warehouse passed its integrated audit.

## 13. Outstanding Source Exceptions and Limitations

The following conditions are documented and remain visible:

- 576 financially comparable orders with recorded-amount mismatches.
- 775 orders missing item records.
- One order missing payment records.
- Eight delivered-status orders without actual customer-delivery timestamps.
- Six canceled-status orders with actual customer-delivery timestamps.
- Eleven distinct flagged payment entries.
- Thirteen products lacking English category translations.
- Six hundred ten products lacking source categories.
- Multiple review records for some orders.
- Unmatched geographic ZIP references.
- Geographic label conflicts and flagged coordinate candidates.

These are documented source conditions, not automatically transformation failures.

The dataset is historical. It does not support claims about current marketplace conditions, accounting settlement, profit, customer lifetime retention, or precise property-level geographic locations.

Physical ANALYTICS tables are source snapshots. Changes to STAGING require a controlled analytical refresh and repeat validation.

## 14. Reproducibility

### Analytical Model SQL

- `sql/18_analytics_dim_order_status.sql`
- `sql/19_analytics_dim_product.sql`
- `sql/20_analytics_dim_seller.sql`
- `sql/21_analytics_dim_customer.sql`
- `sql/22_analytics_dim_customer_geography.sql`
- `sql/23_analytics_dim_purchase_date.sql`
- `sql/24_analytics_dim_delivery_date.sql`
- `sql/25_analytics_dim_review_date.sql`
- `sql/27_analytics_fact_orders.sql`
- `sql/28_analytics_fact_order_items.sql`
- `sql/29_analytics_fact_payments.sql`
- `sql/30_analytics_fact_order_reviews.sql`

### Integrated Audit SQL

- `sql/26_analytics_dimensions_audit.sql`
- `sql/31_analytics_inventory_grain_audit.sql`
- `sql/32_analytics_relationship_integrity_audit.sql`
- `sql/33_analytics_financial_kpi_quality_audit.sql`

### Supporting Documentation

- `docs/raw_warehouse_audit_report.md`
- `docs/staging_warehouse_audit_report.md`
- `docs/analytics_model_design.md`
- `docs/analytics_design_signoff.md`
- `docs/kpi_dictionary.md`
- `docs/geographic_reference_methodology.md`

## 15. Final Audit Decision

**ANALYTICS DATABASE AUDIT: PASS**

All twelve analytical tables passed their required structure and grain checks.

All 23 expected PostgreSQL foreign keys were validated.

The four fact-to-dimension relationship paths preserved their source populations, with no unexplained missing associations or join fanout.

Financial, fulfillment, customer, payment, product and review baseline audits passed.

Geographic coverage exceptions were preserved without deleting business records.

**Approval:** Ready for Power BI integration and semantic-model development.

**Not yet approved:** Final dashboard publication. Power BI relationship behavior, DAX formulas, slicer interactions, visual totals and presentation quality require separate testing.

**Next phase:** Step 7 — Power BI Data Connection, Semantic Model and KPI Validation.

--------------------------------------------------------------------------------------------

## Power BI Semantic Model — Relationship Validation

- Planned relationships created: 20
- Relationship cardinality: One-to-many
- Cross-filter direction: Single
- Active relationships: 20
- Direct fact-to-fact relationships: 0

### Product and Seller Filtering Tests

- Selected product item records: 527
- Selected seller item records: 2,033
- Dimension-vs-fact filtering differences: 0

### Date-Role Filtering Tests

- Selected delivery-date order records: 446
- Selected review-date review records: 463
- Delivery-date filtering difference: 0
- Review-date filtering difference: 0

### Delivery Calendar Validation

- Physical delivery calendar dates: 737
- Distinct dates with actual deliveries: 645
- Calendar dates without delivery activity: 92
- Orders lacking actual delivery dates: 2,965

The initial DAX VALUES-based activity query returned 646
because it included a virtual blank date member.

The corrected check excludes this member and preserves
the documented source population.

Power BI relationship filters were validated against
the corresponding fact-table values.
