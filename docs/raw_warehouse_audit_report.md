# RAW Warehouse Audit Report

**Project:** Order-to-Cash Intelligence Platform  
**Source:** Olist Brazilian E-Commerce Dataset (historical data, primarily 2016–2018)  
**Database:** PostgreSQL `olist_analytics`  
**Schema:** `raw`  
**Audit status:** PASS — Approved for STAGING with documented source exceptions

## 1. Executive Summary

The RAW warehouse contains all nine Olist source datasets, totaling **1,550,922 rows and 52 columns**.

Independent PostgreSQL checks verified:

- Source-to-destination record and column counts.
- Eight logical candidate keys.
- Six cross-table relationships.
- Previously identified source data-quality anomalies.
- Full order-level payment reconciliation.
- Agreement between Python and PostgreSQL financial calculations.

The warehouse is approved for downstream SQL STAGING development. Known source-quality exceptions will be preserved and explicitly handled rather than silently corrected.

## 2. Source Table Inventory

| RAW table | Records | Columns | Audit |
|---|---:|---:|---|
| orders | 99,441 | 8 | PASS |
| order_items | 112,650 | 7 | PASS |
| order_payments | 103,886 | 5 | PASS |
| customers | 99,441 | 5 | PASS |
| products | 32,951 | 9 | PASS |
| sellers | 3,095 | 4 | PASS |
| order_reviews | 99,224 | 7 | PASS |
| geolocation | 1,000,163 | 5 | PASS |
| category_translation | 71 | 2 | PASS |
| **Total** | **1,550,922** | **52** | **PASS** |

All row and column counts match the previously verified CSV profiling baselines.

## 3. Key and Relationship Integrity

### Logical Keys

All eight logical key checks passed:

- `orders`: order_id
- `order_items`: (order_id, order_item_id)
- `order_payments`: (order_id, payment_sequential)
- `customers`: customer_id
- `products`: product_id
- `sellers`: seller_id
- `order_reviews`: (review_id, order_id)
- `category_translation`: product_category_name

Geolocation has no verified unique source key and is excluded from these uniqueness checks.

### Referential Integrity

All six tested relationships passed with zero unmatched child records:

- Orders → Customers
- Order Items → Orders
- Order Items → Products
- Order Items → Sellers
- Order Payments → Orders
- Order Reviews → Orders

These were SQL validation checks, not database-enforced RAW constraints.

### Coverage Exceptions

| Finding | Count |
|---|---:|
| Orders without item records | 775 |
| Orders without payment records | 1 |
| Orders without review records | 768 |

Coverage exceptions are retained for downstream analysis and are not automatically classified as invalid relationships.

## 4. Financial Reconciliation

### Methodology

1. Aggregate item prices and freight to one row per order.
2. Separately aggregate payment amounts to one row per order.
3. Join the aggregated results to the complete Orders table.
4. Compare recorded payment amounts against item-plus-freight amounts.
5. Classify missing records separately from financial mismatches.
6. Preserve exact currency precision.

Independent implementations using Python integer cents and PostgreSQL NUMERIC produced matching results.

### Verified Results

| Metric | Result |
|---|---:|
| Total orders | 99,441 |
| Comparable orders | 98,665 |
| Matching orders | 98,089 |
| Mismatched orders | 576 |
| Match rate among comparable orders | 99.42% |
| Orders missing items | 775 |
| Orders missing payments | 1 |
| Orders missing both | 0 |
| Item prices + freight, comparable orders | R$15,843,409.78 |
| Recorded payments, comparable orders | R$15,846,280.17 |
| Net payment difference | +R$2,870.39 |
| Sum of absolute differences | R$3,271.95 |
| Positive differences | +R$3,071.17 |
| Negative differences | −R$200.78 |

### Mismatch Distribution

- 367 orders have payments greater than item-plus-freight totals.
- 209 orders have payments lower than item-plus-freight totals.
- 273 orders differ by exactly R$0.01.
- 98 orders have absolute differences exceeding R$10.
- 569 of the 576 mismatches belong to delivered orders.

The 99.42% match rate measures source-record financial consistency among comparable orders. It does not represent recognized revenue accuracy, proof of payment settlement, or financial recovery.

## 5. Documented Source-Quality Exceptions

### Payment Data

| Finding | Count |
|---|---:|
| Zero-value payment records | 9 |
| Zero-installment payment records | 2 |
| Undefined payment-type records | 3 |
| Negative payment records | 0 |

One delivered order has no payment record despite R$143.46 in item prices and freight. The missing record must not automatically be treated as a zero-value payment or confirmed revenue loss.

### Product Data

- 610 products have missing source categories.
- Two source categories lack English translation mappings.
- Those untranslated categories affect 13 product records.
- Two products have missing physical measurement attributes.
- Four products have zero recorded weight.

### Review Data

| Finding | Count |
|---|---:|
| NULL review titles | 87,656 |
| Blank/whitespace-only review titles | 2 |
| Effectively missing titles | 87,658 |
| NULL review messages | 58,247 |
| Blank/whitespace-only review messages | 9 |
| Effectively missing messages | 58,256 |
| Missing review scores | 0 |

The distinction between NULL and blank text is preserved in RAW and will be standardized in STAGING.

### Geolocation Data

- 1,000,163 source records.
- 19,015 distinct ZIP prefixes.
- 261,831 exact duplicate row occurrences.
- 17,972 ZIP prefixes have multiple geolocation records.
- 157 distinct customer ZIP prefixes lack a geolocation match.
- Seven distinct seller ZIP prefixes lack a geolocation match.
- Earlier Python screening flagged 29 coordinate records outside a broad Brazil bounding box; these remain candidates for investigation, not confirmed errors.

The original geolocation records are retained. A one-row-per-ZIP analytical reference model will be created later to avoid join fanout.

## 6. STAGING Transformation Requirements

The following rules will guide the next development phase:

1. Preserve original RAW source values and records.
2. Standardize timestamp text into appropriate SQL timestamp types, with validation.
3. Convert blank or whitespace-only text into standardized NULL values where appropriate.
4. Preserve postal codes as TEXT to retain leading zeros.
5. Standardize product category labels while distinguishing untranslated categories from missing source categories.
6. Preserve and flag payment anomalies without manufacturing payment amounts.
7. Maintain explicit order-level reconciliation classifications and differences.
8. Aggregate geolocation to an appropriate ZIP-level grain before analytical joins.
9. Handle multiple review records without inflating order counts or monetary measures.
10. Add repeatable quality checks to curated models.

## 7. Audit Limitations

- The row-count audit verifies completeness at the table-count level, not byte-for-byte equality with every source CSV.
- The tested relationships are valid in the audited database state but are not enforced as RAW foreign-key constraints.
- Source anomalies are documented, not necessarily resolved.
- Payment equality does not establish accounting settlement or recognized revenue.
- Geographic coordinates have not been independently validated against an authoritative spatial reference.
- The findings describe a historical dataset, not current marketplace operations.

## 8. Reproducibility and Evidence

The following project files support the RAW audit:

- `sql/01_create_schemas.sql`
- `sql/02_create_raw_tables.sql`
- `sql/03_raw_warehouse_audit.sql`
- `sql/04_raw_keys_relationships_audit.sql`
- `sql/05_raw_quality_financial_audit.sql`
- `scripts/load_raw_orders.py`
- `scripts/load_raw_tables.py`
- `tests/run_quality_checks.py`
- `docs/quality_check_results.csv`
- `docs/full_payment_reconciliation_summary.csv`
- `docs/mismatch_status_summary.csv`

Original source files and detailed local reconciliation outputs remain separate from the SQL definitions and audit documentation.

## 9. Final Assessment

**Decision: PASS — Approved for SQL STAGING development with known source exceptions.**

All required RAW table-count, logical-key, relationship, source-quality baseline, and financial reconciliation checks passed.

The RAW warehouse is suitable as the source layer for subsequent transformations, subject to documented limitations and continued data-quality testing.

**Next phase:** SQL STAGING — standardization, controlled transformations, explicit exception flags, and automated validation of curated models.