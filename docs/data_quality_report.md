# Order-to-Cash Intelligence Platform — Source Data Quality Assessment

**Project:** Olist Brazilian E-Commerce Analytics  
**Phase:** Step 3.10B — Consolidated data-quality report  
**Version:** 1.0 — 2026-11-10  
**Status:** Source profiling complete; remediation and cross-table business validation pending  
**Dataset:** [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (historical 2016–2018 data)

> **Evidence and limitations:** Every count in this report comes from the nine local Python profiling outputs shared by the project owner during Steps 3.1–3.9. The report summarizes those outputs; it is **not yet generated automatically by a testing pipeline**. No cleaning, SQL ingestion, or business reconciliation has been performed. "Exception" means a record or pattern deserves evaluation, **not** that it is necessarily an error. Counts from different checks may overlap and must not be added as if they identify distinct affected records.

## Executive summary

- **9 source CSVs; 1,550,922 source rows in total; 52 columns across the files.** This is a sum of table sizes, *not* the number of distinct transactions, customers, or entities.
- **Strong basic identifier integrity:** Orders, Order Items, Payments, Customers, Products, Sellers, and Category Translation passed the uniqueness checks on their selected identifiers/composite keys; Reviews has no duplicate (`review_id`, `order_id`) pair, though its component IDs repeat. All foreign-key membership checks performed against Orders, Products, and Sellers returned 0 unmatched child rows.
- **Most consequential modeling risks:** direct joins across order items, payments, and reviews can inflate aggregates; raw geolocation has many observations per ZIP prefix; some order-linked records are absent from other tables.
- **Observed completeness/quality gaps:** missing order lifecycle dates, optional review text, incomplete product descriptions, missing category translations, payment anomalies, coordinate outlier candidates, and geographic lookup coverage gaps.
- **No quantified revenue loss, financial discrepancies, business uplift, or cleaned record counts should be claimed yet.** Those require later analysis.

## Source inventory

| CSV / logical table | Rows | Columns | Grain | Identifier / relationship finding |
|---|---:|---:|---|---|
| Orders | 99,441 | 8 | One order | `order_id` unique, non-null |
| Order Items | 112,650 | 7 | One purchased item | (`order_id`, `order_item_id`) unique; 0 unmatched Order references |
| Payments | 103,886 | 5 | One payment record | (`order_id`, `payment_sequential`) unique; 0 unmatched Order references |
| Customers | 99,441 | 5 | One order-associated customer record | `customer_id` unique; 0 unmatched Orders |
| Products | 32,951 | 9 | One product | `product_id` unique; 0 unmatched Order Items references |
| Sellers | 3,095 | 4 | One seller | `seller_id` unique; 0 unmatched Order Items references |
| Reviews | 99,224 | 7 | One review row | 0 duplicate (`review_id`, `order_id`) pairs; both IDs repeat individually |
| Geolocation | 1,000,163 | 5 | One geographic observation | ZIP prefixes are non-unique; 261,831 exact repeated rows |
| Category Translation | 71 | 2 | One Portuguese→English category | 71 unique source keys; 2 product categories lack a mapping |
| **Total across tables** | **1,550,922** | **52** | — | Do not interpret summed rows as orders |

## Passed baseline checks

| ID | Test | Observed outcome | Scope |
|---|---|---|---|
| PASS-01 | Orders key | 99,441 distinct, 0 null, 0 duplicated `order_id` | Orders |
| PASS-02 | Item composite key and child references | 0 duplicate (`order_id`, `order_item_id`); 0 item rows without an Order | Order Items → Orders |
| PASS-03 | Payment composite key and child references | 0 duplicate (`order_id`, `payment_sequential`); 0 payment rows without an Order | Payments → Orders |
| PASS-04 | Customer ID and membership | 0 duplicate `customer_id`; 0 Orders without Customer records; 0 unused Customers | Customers ↔ Orders |
| PASS-05 | Product ID and item references | 0 duplicate/missing `product_id`; 0 item rows without Products | Products ↔ Items |
| PASS-06 | Seller ID and item references | 0 duplicate/missing `seller_id`; 0 item rows without Sellers | Sellers ↔ Items |
| PASS-07 | Review structural validity | 0 duplicate (`review_id`, `order_id`) pairs; 0 invalid review scores; 0 review rows without Orders; 0 invalid/missing review date parses; 0 responses predating survey creation | Reviews |
| PASS-08 | Translation source integrity | 0 null/blank fields; 0 duplicate Portuguese keys; 71 distinct English labels | Translation |
| PASS-09 | Geographic basic validity | 0 missing values, invalid ZIP-format rows, invalid 2-uppercase-letter state-format rows, or globally out-of-range latitude/longitude | Geolocation |

> Passing a format/uniqueness check is not evidence that a value is geographically or commercially correct. For example, valid latitude and longitude ranges are broader than the Brazilian territory.

## Issue and investigation register

**Priority definitions:** *High* = likely to materially distort a key metric or join if handled incorrectly; *Medium* = affects completeness, interpretation, or a subset of analyses; *Low* = informational/optional field or localized exceptional case. Priority is for project triage, **not a confirmed production incident severity**.

**Status key:** `OPEN — investigate` means behavior needs deeper review; `OPEN — design rule` means a deliberate modeling or labeling rule is needed; `EXPECTED / document` means a pattern is not by itself a defect.

| ID | Area | Evidence observed | Priority | Status | Proposed handling / next validation |
|---|---|---|---|---|---|
| DQ-01 | Order lifecycle timestamps | 160 missing approval, 1,783 carrier handoff, 2,965 final delivery dates | Medium | OPEN — investigate | Cross-tab missing timestamps by `order_status`; review any delivered orders without delivery dates; never invent timestamps |
| DQ-02 | Orders missing item rows | 775 Orders have no Order Items | Medium | OPEN — investigate | Inspect order status and financial records; define eligibility for merchandise-value calculations |
| DQ-03 | Order missing payment row | 1 Order has no Payments | Medium | OPEN — investigate | Inspect status and item activity; distinguish missing payment data from a recorded zero-value payment |
| DQ-04 | Payment exception candidates | 9 payments of zero value; 2 zero-installment rows; 3 `not_defined` payment methods | Medium | OPEN — investigate | Inspect raw example rows, order status, payment type and amount; flags may overlap; do not remove without justification |
| DQ-05 | Payment fan-out risk | 2,961 orders have multiple payment records; max 29 records for one order | High | OPEN — design rule | Aggregate payment amount per `order_id` before comparison with item totals; test join cardinalities |
| DQ-06 | Multiple review representations | 814 repeated `review_id` occurrences; 547 orders have multiple review rows; max 3 per order; 768 Orders have no Reviews | High | OPEN — design rule | Investigate repeated identifiers and chronology; select/document an order-level review method; avoid duplicate weighting |
| DQ-07 | Optional review text | 87,656 missing titles (+2 non-null blank); 58,247 missing messages (+27 non-null blank) | Low | EXPECTED / document | Treat whitespace-only comments as missing during cleaning; do not assume missing written feedback is a failed rating |
| DQ-08 | Product descriptive fields | 610 nulls each in category, name length, description length, photo count; co-occurrence untested | Medium | OPEN — investigate | Check whether nulls occur on same products; flag missing catalog fields; retain products in KPIs |
| DQ-09 | Product physical attributes | 2 nulls each in weight/length/height/width; 4 zero-weight products | Medium | OPEN — investigate | Examine these products before delivery-weight/dimension analysis; never impute weights without a documented rule |
| DQ-10 | Category translation coverage | 73 non-null product categories, only 71 translated; 13 products in 2 untranslated categories; 610 products lack a source category | Medium | OPEN — design rule | Use LEFT JOIN; preserve Portuguese label fallback for 13; label 610 missing categories `Unknown / Unclassified` |
| DQ-11 | Geolocation duplicates | 261,831 exact duplicates among 1,000,163 rows (26.18%); 17,972 ZIPs appear multiple times | High | OPEN — design rule | Retain immutable raw data; derive distinct/deduplicated observations and one defensible representative per ZIP before lookup joins |
| DQ-12 | Coordinate outlier candidates | 29 records outside approximate Brazil bounding box; latitude −36.61 to +45.07, longitude −101.47 to +121.11 | Medium | OPEN — investigate | Examine source rows; bounding-box rule is not a definitive country-boundary test; do not silently clamp or delete |
| DQ-13 | Geographic coverage gaps | 157 distinct customer ZIPs and 7 distinct seller ZIPs absent from Geolocation | Medium | OPEN — investigate | Quantify affected customer/seller *rows*, not only distinct prefixes; keep unmatched business records during joins |
| DQ-14 | Geographic join fan-out | 19,015 unique ZIP prefixes in 1,000,163 geolocation rows; max 1,146 rows for one ZIP | High | OPEN — design rule | Never join raw Geolocation directly to Customers/Sellers for finance KPIs; first make a one-row-per-ZIP reference |
| DQ-15 | Transaction reconciliation | Not yet tested; item totals and payments live at different grains | High | NOT TESTED | Aggregate item `price + freight_value` and payment `payment_value` separately by `order_id`; compare on eligible orders; inspect exceptions, status and semantics before claiming discrepancies |

### Detailed verified order-status counts

| Order status | Rows |
|---|---:|
| delivered | 96,478 |
| shipped | 1,107 |
| canceled | 625 |
| unavailable | 609 |
| invoiced | 314 |
| processing | 301 |
| created | 5 |
| approved | 2 |
| **Total** | **99,441** |

Interpret missing lifecycle dates in relation to these statuses, not independently. Date-like CSV columns were read as strings and need explicit datetime parsing.

### Other verified context

- Order Items: 98,666 unique orders with items, 9,803 multi-item orders, maximum 21 items per order; 0 nulls and 0 negative prices or freight amounts.
- Payments: 99,440 unique orders with payments; 0 nulls or negative payment amounts; order-level join required before reconciliation.
- Customers: 96,096 unique customer identifiers across 99,441 order-linked records; 2,997 customers have multiple order-associated records (3.12%). This is **not yet a retention rate**.
- Reviews: 99,224 record-level ratings averaging **4.09/5**; 0 invalid scores; review-level mean is not necessarily the same as order-level mean.
- Product translations: missing category (610) and untranslated non-null category (13) are separate sets, producing 623 Products without an English label from the provided lookup (1.89% of Products).

## Rules for safe KPI development (proposed, not yet implemented)

1. **Separate grains:** Orders, Items, Payments, Reviews and Geolocation have different row meanings. Record the intended grain of each analytical table and measure.
2. **No fan-out for financial totals:** Calculate order-level item and payment summaries in separate tables before joining them to the one-row-per-order summary; test counts and sums before/after joins.
3. **Explicit eligibility:** Define which order statuses count for completed orders, placed orders, fulfillment SLA and other metrics. Keep canceled/unavailable cases visible where relevant.
4. **No silent data repair:** Preserve raw CSVs; derive documented cleaned fields and flags. Do not manufacture dates, payments, weights or category values.
5. **Distinguish expected optionality:** Missing review text is not automatically a defect; missing lifecycle dates might be status dependent.
6. **Explicit source-currency labels:** Item `price`, freight and payments are in BRL. Do not call item totals profit or automatically equate every payment amount with recognized revenue.
7. **Historical scope:** This dataset describes transactions in 2016–2018, not live marketplace KPIs.

## Planned verification work (Step 3.10C and PostgreSQL phase)

- [ ] Convert the profiling checks into repeatable Python assertions and machine-readable test results (CSV/JSON).
- [ ] Inspect order statuses for missing lifecycle dates, 775 itemless Orders, the paymentless Order, and 768 Orders without Reviews.
- [ ] Inspect zero-payment, zero-installment, undefined payment-method, and repeated-review cases.
- [ ] Test category-missing-field co-occurrence and identify products with zero weight.
- [ ] Quantify customer/seller **row** coverage against ZIP lookup, not only distinct missing prefixes.
- [ ] Define geographic coordinate aggregation after examining duplicates and outlier candidates.
- [ ] Create source-to-raw PostgreSQL loading logic and row-count reconciliation.
- [ ] Perform order-level item/payment reconciliation; report true observed differences with their applicable business caveats.
- [ ] Define and test each Power BI KPI against controlled SQL queries.

## Evidence provenance

**Local run outputs supplied in this conversation:** `profile_orders.py`, `profile_order_items.py`, `profile_payments.py`, `profile_customers.py`, `profile_products.py`, `profile_sellers.py`, `profile_reviews.py`, `profile_geolocation.py`, and `profile_category_translation.py`.

**Related document:** `docs/data_dictionary.md` (source columns, meanings, keys, relationships, and profiling findings).

**Next milestone:** Step 3.10C — automate these validations, then ingest the raw sources into PostgreSQL. Do not mark any issue `RESOLVED` until the handling rule has been implemented and its effect has been tested.
