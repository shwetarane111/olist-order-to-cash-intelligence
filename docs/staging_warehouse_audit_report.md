# STAGING Warehouse Audit Report

**Project:** Order-to-Cash Intelligence Platform  
**Source:** Historical Olist Brazilian E-Commerce Dataset  
**Database:** PostgreSQL `olist_analytics`  
**Schema:** `staging`  
**Audit status:** PASS — Approved for ANALYTICS development with documented exceptions

## 1. Executive Summary

The SQL STAGING layer has been developed and validated against the previously audited RAW warehouse.

The implementation includes:

- Eight source-oriented SQL staging views.
- One materialized ZIP-level geographic reference.
- Standardized timestamp, geographic, category, monetary, and review fields.
- Explicit data-quality indicators.
- Preserved record-level grains and logical keys.
- Reproducible SQL validation of relationships and financial reconciliation.

All required completeness, key integrity, relationship, transformation fidelity, and quality-baseline checks passed.

The STAGING layer is approved for downstream analytical modeling, subject to documented data-quality exceptions and business-definition limitations.

## 2. STAGING Model Inventory

| Model | Records | Columns | Audit |
|---|---:|---:|---|
| stg_orders | 99,441 | 8 | PASS |
| stg_order_items | 112,650 | 8 | PASS |
| stg_order_payments | 103,886 | 9 | PASS |
| stg_customers | 99,441 | 7 | PASS |
| stg_products | 32,951 | 17 | PASS |
| stg_sellers | 3,095 | 6 | PASS |
| stg_order_reviews | 99,224 | 11 | PASS |
| stg_geolocation | 1,000,163 | 9 | PASS |
| **Total** | **1,550,851** | **75** | **PASS** |

The 71 Category Translation source records are incorporated through the Products staging transformation rather than a separate staging view.

### Additional Geographic Reference

`staging.ref_zip_geolocation` is a materialized view containing 19,015 records, with exactly one representative geographic record per ZIP prefix.

These are derived records and are excluded from the source-preservation total above.

## 3. Structural and Transformation Integrity

### Logical Keys

Eight logical-key checks passed:

- Orders: `order_id`
- Order Items: `(order_id, order_item_id)`
- Payments: `(order_id, payment_sequential)`
- Customers: `customer_id`
- Products: `product_id`
- Sellers: `seller_id`
- Reviews: `(review_id, order_id)`
- ZIP Reference: `geolocation_zip_code_prefix`

The source-grain Geolocation staging view has no verified unique key.

### Relationships

All six core relationships passed with zero unmatched child records and no join-induced record inflation:

- Orders → Customers
- Order Items → Orders
- Order Items → Products
- Order Items → Sellers
- Payments → Orders
- Reviews → Orders

### Transformation Fidelity

Seven source-to-staging transformation checks passed with zero inconsistent rows.

The tested fields include timestamp conversions, monetary values, text normalization, product translations, and review comments.

Geolocation was separately verified through source-row preservation, quality checks, ZIP cardinality, and geographic-reference validation.

## 4. Payment Data Quality

| Indicator | Records |
|---|---:|
| Total payment records | 103,886 |
| Zero-value payments | 9 |
| Zero-installment payments | 2 |
| Undefined payment methods | 3 |
| Distinct flagged payment records | 11 |
| Orders containing flagged payments | 10 |
| Zero-value and undefined-method overlap | 3 |

The overall payment-quality flag was independently validated against its component conditions.

Flagged payments are preserved for traceability. A flag does not independently establish an incorrect payment or financial loss.

## 5. Product Data Quality

| Category classification | Products |
|---|---:|
| Translated | 32,328 |
| Untranslated | 13 |
| Missing source category | 610 |
| **Total** | **32,951** |

Two Portuguese categories lack English translation mappings, affecting 13 products.

Additional source conditions:

- 610 products have missing catalog attributes.
- Two products have missing physical measurement attributes.
- Four products have zero recorded weight.
- No products have missing category display labels after applying the documented fallback.

Missing source categories and missing translations remain distinguishable through explicit flags.

## 6. Review Data Quality

| Indicator | Records |
|---|---:|
| Total review records | 99,224 |
| Missing review titles, including blanks | 87,658 |
| Missing review messages, including blanks | 58,256 |
| Reviews without any written feedback | **56,527** |
| Invalid review scores | 0 |
| Missing creation timestamps | 0 |
| Missing answer timestamps | 0 |

The STAGING transformation converts blank or whitespace-only written feedback to NULL while preserving numeric review scores.

Review IDs alone are not unique. The validated logical key is `(review_id, order_id)`.

Multiple reviews per order are retained; subsequent order-level models must aggregate reviews appropriately.

## 7. Financial Reconciliation

### Method

1. Aggregate item prices and freight to order level.
2. Independently aggregate payment amounts to order level.
3. Join the aggregated results to Orders.
4. Compare amounts using exact decimal arithmetic.
5. Classify missing records separately from financial mismatches.

### Verified Reconciliation Results

| Metric | Value |
|---|---:|
| Total orders | 99,441 |
| Comparable orders | 98,665 |
| Matching orders | 98,089 |
| Mismatched orders | 576 |
| Match rate among comparable orders | **99.42%** |
| Orders missing items | 775 |
| Orders missing payments | 1 |
| Orders missing both | 0 |

### Financial Totals

| Metric | Amount (BRL) |
|---|---:|
| Item prices + freight | R$15,843,409.78 |
| Recorded payments | R$15,846,280.17 |
| Net payment difference | +R$2,870.39 |
| Sum of absolute differences | R$3,271.95 |
| Positive differences | +R$3,071.17 |
| Negative differences | −R$200.78 |

The results agree across Python, RAW PostgreSQL, and STAGING PostgreSQL.

Of the 576 mismatches, 569 occur in delivered orders, four in shipped orders, two in canceled orders, and one in an invoiced order.

The reconciliation measures equality between recorded payment totals and recorded item prices plus freight for orders with both amounts available.

It does not establish recognized revenue, payment settlement, overcharging, fraud, or recoverable financial losses.

## 8. Geographic Reference Validation

| Metric | Verified result |
|---|---:|
| Original geolocation records | 1,000,163 |
| Distinct ZIP prefixes | 19,015 |
| ZIPs with multiple source records | 17,972 |
| ZIPs with conflicting city/state combinations | 8,558 |
| Coordinates outside broad Brazil screening rectangle | 31 |
| Selected representative points outside rectangle | 4 |
| Missing representative coordinates | 0 |
| Unmatched distinct customer ZIP prefixes | 157 |
| Unmatched distinct seller ZIP prefixes | 7 |

The ZIP reference uses a documented deterministic selection rule based on the modal city/state combination and an observed coordinate near the group's medians.

A unique index enforces the one-row-per-ZIP grain.

Customer and Seller LEFT JOIN row counts were verified unchanged.

The broad Brazil screening rectangle is a heuristic, not an official geographic boundary. Four selected points outside the rectangle require additional geographic verification before inclusion in published maps.

Full methodology is documented in `docs/geographic_reference_methodology.md`.

## 9. Outstanding Exceptions and Analytical Treatment

| Exception | Planned treatment |
|---|---|
| 576 payment reconciliation mismatches | Preserve signed differences and mismatch classifications |
| One delivered order without a payment record | Preserve missing payment as NULL, not zero |
| Missing original product categories | Use explicit reporting label and retain missing-source flag |
| Missing English category translations | Preserve Portuguese category as fallback |
| Blank review comments | Standardize to NULL without discarding valid ratings |
| Multiple reviews per order | Define aggregation grain explicitly before joining to financial facts |
| Repeated geolocation records | Use unique ZIP-level reference for analytical joins |
| Four selected geographic outlier candidates | Exclude from published coordinate-based maps pending verification |
| Unmatched ZIP prefixes | Retain Customers and Sellers using LEFT JOINs; preserve missing geography |

## 10. Reproducibility

The following SQL files establish the STAGING models and validation logic:

- `sql/06_staging_orders.sql`
- `sql/07_staging_order_items.sql`
- `sql/08_staging_order_payments.sql`
- `sql/09_staging_customers.sql`
- `sql/10_staging_products.sql`
- `sql/11_staging_sellers.sql`
- `sql/12_staging_order_reviews.sql`
- `sql/13_staging_geolocation.sql`
- `sql/14_staging_geo_zip_reference.sql`
- `sql/15_staging_warehouse_audit.sql`
- `sql/16_staging_integrity_audit.sql`
- `sql/17_staging_quality_financial_audit.sql`

Supporting evidence includes the RAW audit report, data dictionary, Python quality-check outputs, reconciliation investigation, and geographic reference methodology.

## 11. Limitations

- Source data is historical, not a live representation of current marketplace operations.
- Passing validation does not establish that every source value reflects real-world truth.
- STAGING models retain documented source anomalies.
- The geographic reference contains approximate representative points, not authoritative address geocodes.
- The reference is materialized and requires deliberate refresh when the underlying source changes.
- Financial reconciliation is not equivalent to recognized revenue or accounting settlement.
- Customer retention, seller performance, and fulfillment metrics require carefully defined analytical grains and business rules.

## 12. Final Audit Decision

**PASS — Approved for ANALYTICS star-schema development with documented exceptions.**

The completed STAGING layer has passed its required structural, relationship, transformation, quality-baseline, and reconciliation checks.

The next development phase will define analytical fact and dimension models, their grains and keys, reusable metrics, and further model-level validation before connecting Power BI.