# Business KPI Dictionary

**Project:** Order-to-Cash Intelligence Platform  
**Database:** PostgreSQL `olist_analytics`  
**Target layer:** `analytics`  
**Currency:** Brazilian Real (BRL / R$)  
**Status:** Design in progress — Task 3A: Order and Financial KPIs

## 1. Purpose

Define reproducible business KPIs for PostgreSQL analytics and Power BI.

Every KPI must have a documented source, grain, numerator, denominator (where applicable), filtering rules, missing-value treatment, and interpretation.

The metrics describe historical marketplace records. They do not establish recognized revenue, accounting settlement, profit, or recoverable financial losses.

## 2. General Rules

- Preserve the grain of each fact table.
- Apply applicable Customer, Purchase Date, Order Status, and Customer Geography filters through the shared dimensions.
- Product and Seller filtering applies to item-level facts, not automatically to order-level payments or reconciliation metrics.
- Use exact PostgreSQL NUMERIC arithmetic for monetary calculations.
- Treat missing financial records as NULL, not as zero.
- Use distinct-order counts where items or payments can repeat per order.
- For division, return NULL or a clearly formatted blank when the denominator is zero.
- Calculate rate measures as ratios of filtered counts, not averages of precomputed row percentages.
- Distinguish all-record totals from comparable-order totals.

## 3. Order Activity KPIs

### KPI-001 — Total Orders

**Source:** `analytics.fact_orders`  
**Grain:** Order  
**Numerator:** Count of order records  
**Denominator:** Not applicable  
**Formula:** COUNT of orders  
**Filters:** Selected purchase period, status, customer and customer geography  
**Baseline:** 99,441

Includes all source order statuses.

### KPI-002 — Delivered Orders

**Source:** `analytics.fact_orders`  
**Grain:** Order  
**Numerator:** Count of orders with `order_status = 'delivered'`  
**Denominator:** Not applicable  
**Baseline:** 96,478

Measures orders marked delivered in the source, not proof of carrier delivery confirmation.

### KPI-003 — Orders With Items

**Source:** `analytics.fact_orders`  
**Grain:** Order  
**Numerator:** Count of orders with at least one source item record  
**Denominator:** Not applicable  
**Baseline:** 98,666

Use item-record presence rather than assuming all orders have line items.

### KPI-004 — Comparable Orders

**Source:** `analytics.fact_orders`  
**Grain:** Order  
**Numerator:** Count of orders classified MATCH or MISMATCH  
**Denominator:** Not applicable  
**Baseline:** 98,665

A comparable order has both an item-plus-freight total and a recorded payment total.

## 4. Recorded Monetary KPIs

### KPI-005 — Recorded Item Price Total

**Source:** `analytics.fact_order_items`  
**Grain:** Order item  
**Formula:** SUM(item_price)  
**Denominator:** Not applicable

Includes item rows available in the selected filter context.

This is not recognized revenue.

### KPI-006 — Recorded Freight Total

**Source:** `analytics.fact_order_items`  
**Grain:** Order item  
**Formula:** SUM(freight_amount)  
**Denominator:** Not applicable

Represents source-recorded freight charges, not necessarily actual shipping costs.

### KPI-007 — Recorded Item + Freight Total

**Source:** `analytics.fact_order_items`  
**Grain:** Order item  
**Formula:** SUM(item_total_amount)  
**Denominator:** Not applicable

Includes available item records regardless of whether their order has a matching payment record.

### KPI-008 — Recorded Payment Volume

**Source:** `analytics.fact_payments`  
**Grain:** Payment entry  
**Formula:** SUM(payment_amount)  
**Denominator:** Not applicable

Includes payment entries available in the selected filter context, including split and zero-value payments.

The source does not establish actual payment transaction timestamps or settlement.


### Verified Payment Fact Baselines

Source: analytics.fact_payments

- Payment records: 103,886
- Distinct orders with payments: 99,440
- KPI-008 Recorded Payment Volume: R$16,008,872.12
- Comparable-order payment total: R$15,846,280.17
- Difference between populations: R$162,591.95
- Negative payment amounts: 0
- Flagged payment records: 11
- Orders containing flagged payments: 10
- Orders with multiple payment entries: 2,961
- Maximum entries for one order: 29

Payment methods:
- credit_card: 76,795 entries; R$12,542,084.19
- boleto: 19,784 entries; R$2,869,361.27
- voucher: 5,775 entries; R$379,436.87
- debit_card: 1,529 entries; R$217,989.79
- not_defined: 3 entries; R$0.00

Distinct order counts by method are not additive.
Purchase Date refers to the associated order's purchase
date, not a verified payment transaction or settlement date.

### KPI-009 — Comparable Item + Freight Total

**Source:** `analytics.fact_orders`  
**Grain:** Order  
**Formula:** SUM(item_plus_freight_total) only for MATCH and MISMATCH orders  
**Denominator:** Not applicable  
**Baseline:** R$15,843,409.78

Excludes orders lacking either side of the financial comparison.

### KPI-010 — Comparable Payment Total

**Source:** `analytics.fact_orders`  
**Grain:** Order  
**Formula:** SUM(recorded_payment_total) only for MATCH and MISMATCH orders  
**Denominator:** Not applicable  
**Baseline:** R$15,846,280.17

Do not confuse this with Recorded Payment Volume across all payment entries.

### KPI-011 — Delivered Order AOV: Item + Freight

**Source:** `analytics.fact_orders`  
**Grain:** Order

**Numerator:** Sum of item-plus-freight totals for delivered orders with item records.

**Denominator:** Count of delivered orders with item records.

**Formula:** Numerator / Denominator

**Treatment:** Exclude orders without item records from numerator and denominator. Return blank if the denominator is zero.

**Interpretation:** Average recorded item-plus-freight value per delivered, item-backed order.

This is not recognized revenue or profit.

## 5. Financial Reconciliation KPIs

### KPI-012 — Matching Orders

**Source:** `analytics.fact_orders`  
**Grain:** Order  
**Formula:** Count orders where reconciliation_status = MATCH  
**Baseline:** 98,089

### KPI-013 — Mismatched Orders

**Source:** `analytics.fact_orders`  
**Grain:** Order  
**Formula:** Count orders where reconciliation_status = MISMATCH  
**Baseline:** 576

### KPI-014 — Payment Reconciliation Match Rate

**Source:** `analytics.fact_orders`

**Numerator:** Matching Orders

**Denominator:** Comparable Orders

**Formula:** Matching Orders / Comparable Orders × 100

**Baseline:** 99.42%

Orders missing financial records are excluded from the denominator and reported separately.

### KPI-015 — Payment Reconciliation Mismatch Rate

**Source:** `analytics.fact_orders`

**Numerator:** Mismatched Orders

**Denominator:** Comparable Orders

**Formula:** Mismatched Orders / Comparable Orders × 100

**Baseline:** 0.58%

This is a source-record consistency measure, not a fraud or loss rate.

### KPI-016 — Orders Missing Item Records

**Source:** `analytics.fact_orders`  
**Formula:** Count orders where reconciliation_status = MISSING_ITEMS  
**Baseline:** 775

Coverage exception, not automatically an invalid order.

### KPI-017 — Orders Missing Payment Records

**Source:** `analytics.fact_orders`  
**Formula:** Count orders where reconciliation_status = MISSING_PAYMENTS  
**Baseline:** 1

Missing payment records remain NULL; they must not be interpreted as confirmed unpaid transactions.

### KPI-018 — Net Payment Difference

**Source:** `analytics.fact_orders`

**Formula:** Sum of recorded_payment_total − item_plus_freight_total across comparable orders.

**Baseline:** +R$2,870.39

A positive difference means recorded payments exceed item-plus-freight totals in aggregate.

This metric allows positive and negative differences to offset.

### KPI-019 — Absolute Financial Discrepancy

**Source:** `analytics.fact_orders`

**Formula:** Sum of ABS(recorded_payment_total − item_plus_freight_total) at order level across comparable orders.

**Baseline:** R$3,271.95

Absolute value must be applied at the order level before aggregation.

This is not automatically financial loss or overcharging.

## 6. Filter and Denominator Rules

- All baseline figures above refer to the complete historical dataset without report slicers.
- KPI values must be recalculated within the applicable Power BI filter context.
- Reconciliation rates use filtered matching and comparable-order counts.
- Do not average previously calculated monthly match rates to obtain an annual match rate; recalculate using annual numerator and denominator totals.
- Product and Seller slicers must not silently allocate order-level payments or reconciliation differences.
- Purchase-date-linked payment measures refer to payments associated with orders purchased in that period, not necessarily payments executed during that period.
- Missing financial coverage remains a separate status category.

## 7. Future KPI Groups

**Task 3B:** Fulfillment timeliness, customer activity, repeat-customer measures, and geographic coverage.

**Task 3C:** Product performance, seller activity, payment-method analysis, and review/satisfaction measures.

These definitions will be added before analytical SQL implementation.

## 8. Implementation Status

**Task 3A:** Core order and financial definitions documented.

No ANALYTICS fact tables or Power BI measures have been implemented yet.

Final column names will be aligned with the SQL models during implementation, and all KPIs will be validated against the previously audited source baselines.

--------------------------------------------------------------------------------------------
## Task 3B — Fulfillment, Customer and Geographic KPIs

**Status:** Definitions completed; SQL and Power BI implementation pending.

### General Rules

- All full-dataset baselines refer to the historical Olist source without dashboard filters.
- Delivery timeliness is assessed only for orders marked delivered with actual and estimated customer-delivery timestamps.
- Missing dates are not automatically interpreted as late delivery.
- On-time delivery is evaluated at calendar-day precision.
- Repeat-order behavior is based on distinct orders per `customer_unique_id` within the selected filter context.
- Geographic coverage distinguishes matched ZIP references from map-ready representative coordinates.
- All ratios return NULL or blank when the denominator is zero.
- All metrics must be validated against PostgreSQL results before dashboard publication.

## 8. Fulfillment and Delivery KPIs

### KPI-020 — Delivered Order Share

**Source:** `analytics.fact_orders`  
**Grain:** Order  
**Numerator:** Orders where `order_status = 'delivered'`  
**Denominator:** Total orders in the selected filter context  
**Formula:** Delivered Orders / Total Orders × 100  
**Baseline:** 96,478 delivered orders out of 99,441 total orders

**Interpretation:** Share of historical orders marked delivered. Not a carrier-confirmed delivery success rate.

### KPI-021 — Canceled Order Share

**Source:** `analytics.fact_orders`  
**Grain:** Order  
**Numerator:** Orders where `order_status = 'canceled'`  
**Denominator:** Total orders in the selected filter context  
**Formula:** Canceled Orders / Total Orders × 100  
**Baseline:** 625 canceled orders out of 99,441 total orders

**Interpretation:** Share of orders currently classified as canceled in the historical source data.

### KPI-022 — Delivery Evaluation Coverage

**Source:** `analytics.fact_orders`  
**Grain:** Order  
**Numerator:** Delivered orders with both actual customer-delivery and estimated delivery timestamps  
**Denominator:** All delivered orders  
**Formula:** Evaluable Delivered Orders / Delivered Orders × 100

**Missing-value treatment:** Delivered orders lacking either timestamp remain in the denominator but are excluded from the numerator.

**Baseline:** To be verified during ANALYTICS implementation.

### KPI-023 — On-Time Delivery Rate

**Source:** `analytics.fact_orders`  
**Grain:** Order  
**Numerator:** Evaluable delivered orders where actual delivery date is on or before estimated delivery date  
**Denominator:** Evaluable delivered orders  
**Formula:** On-Time Evaluable Delivered Orders / Evaluable Delivered Orders × 100

**Date rule:**
`actual_delivery_timestamp::DATE <= estimated_delivery_timestamp::DATE`

**Baseline:** To be verified.

**Interpretation:** Delivery by the estimated calendar date; not necessarily a contractual SLA.

### KPI-024 — Late Delivery Rate

**Source:** `analytics.fact_orders`  
**Grain:** Order  
**Numerator:** Evaluable delivered orders where actual delivery date is after estimated delivery date  
**Denominator:** Evaluable delivered orders  
**Formula:** Late Evaluable Delivered Orders / Evaluable Delivered Orders × 100

**Date rule:**
`actual_delivery_timestamp::DATE > estimated_delivery_timestamp::DATE`

**Baseline:** To be verified.

For the same filter context, On-Time Delivery Rate plus Late Delivery Rate should equal 100% when at least one evaluable order exists.

### KPI-025 — Average Purchase-to-Delivery Time

**Source:** `analytics.fact_orders`  
**Grain:** Order  
**Numerator:** Sum of elapsed days between purchase timestamp and actual customer-delivery timestamp for eligible delivered orders  
**Denominator:** Delivered orders with both timestamps and nonnegative elapsed durations

**Per-order calculation:**

`EXTRACT(EPOCH FROM (actual_delivery_timestamp - purchase_timestamp)) / 86400.0`

**Aggregate:** Arithmetic mean of eligible per-order durations.

**Missing-value treatment:** Exclude records lacking required timestamps. Exclude and separately flag negative elapsed durations.

**Baseline:** To be verified.

**Interpretation:** Observed elapsed time from recorded purchase to recorded customer delivery, not carrier-only transit time.

- Verified full-dataset baseline: 12.56 days
- Source: analytics.fact_orders
- Population: Delivered orders with valid, nonnegative elapsed durations

### KPI-026 — Average Signed Delivery Variance

**Source:** `analytics.fact_orders`  
**Grain:** Order  
**Numerator:** Sum of signed date differences across evaluable delivered orders  
**Denominator:** Evaluable delivered orders

**Per-order calculation:**

`actual_delivery_timestamp::DATE - estimated_delivery_timestamp::DATE`

**Aggregate:** Arithmetic mean of signed calendar-day differences.

**Interpretation:**
- Negative = earlier than estimated date
- Zero = estimated date
- Positive = later than estimated date

**Baseline:** To be verified.

Averages may conceal a mixture of early and late deliveries, so report with the timeliness rates.

- Verified full-dataset baseline: -11.88 calendar days
- Source: analytics.fact_orders
- Population: Evaluable delivered orders
- Interpretation: Negative values indicate delivery before the estimated date

### KPI-027 — Delivered Orders Missing Actual Delivery Date

**Source:** `analytics.fact_orders`  
**Grain:** Order  
**Formula:** Count of orders with status `delivered` and NULL actual customer-delivery timestamp  
**Denominator:** Not applicable  
**Baseline:** To be verified.

**Interpretation:** Timestamp coverage exception. Do not automatically treat the order as undelivered.

## 9. Customer Behavior KPIs

### KPI-028 — Distinct Observed Customer Identities

**Source:** `analytics.fact_orders`  
**Grain:** Order  
**Formula:** Count distinct `customer_unique_id` values among filtered orders  
**Denominator:** Not applicable  
**Full-dataset baseline:** 96,096

Use the filtered order fact rather than an unfiltered count of `dim_customer` rows for period-specific reporting.

### KPI-029 — Repeat-Order Customer Identities

**Source:** `analytics.fact_orders`  
**Grain:** Customer identity, derived from filtered orders  
**Formula:** Count customer identities associated with two or more distinct `order_id` values within the selected filter context  
**Denominator:** Not applicable  
**Full-dataset baseline:** 2,997

This is repeat ordering within the observed filter context, not proof of completed purchases or lifetime retention.

### KPI-030 — Repeat-Order Identity Share

**Source:** `analytics.fact_orders`  
**Numerator:** Repeat-Order Customer Identities  
**Denominator:** Distinct Observed Customer Identities  
**Formula:** Numerator / Denominator × 100  
**Full-dataset baseline:** Approximately 3.12%

The numerator and denominator must be recalculated together under each selected date/status/customer/geographic filter context.

Do not average monthly repeat-order shares to calculate a yearly share.

### KPI-031 — Average Orders per Observed Identity

**Source:** `analytics.fact_orders`  
**Numerator:** Number of distinct orders in the selected context  
**Denominator:** Number of distinct observed customer identities in the same context  
**Formula:** Distinct Orders / Distinct Customer Identities  
**Baseline:** To be calculated during implementation.

Include all order statuses unless the visual or report explicitly defines a narrower population.

This metric is not equivalent to frequency among completed purchases only.

## 10. Geographic Coverage KPIs

### KPI-032 — Customer ZIP Reference Coverage

**Sources:** `analytics.fact_orders` and `analytics.dim_customer_geography`  
**Grain:** Order-associated customer record  
**Numerator:** Order-associated customer records whose valid ZIP prefix matches `staging.ref_zip_geolocation`  
**Denominator:** Order-associated customer records with valid ZIP prefixes  
**Formula:** Numerator / Denominator × 100  
**Baseline percentage:** To be calculated.

Preserve orders whose ZIP prefix lacks a match. Do not assume distinct ZIP-prefix exceptions equal the number of affected orders.

### KPI-033 — Seller ZIP Reference Coverage

**Source:** `analytics.dim_seller`, enriched from the validated ZIP reference  
**Grain:** Seller  
**Numerator:** Sellers whose valid ZIP prefix matches `staging.ref_zip_geolocation`  
**Denominator:** Sellers with valid ZIP prefixes  
**Formula:** Numerator / Denominator × 100  
**Baseline percentage:** To be calculated.

This is a seller-level coverage measure, not a share of seller orders or item amounts.

### KPI-034 — Map-Ready Customer Order Coverage

**Sources:** `analytics.fact_orders` and `analytics.dim_customer_geography`  
**Grain:** Order-associated customer record  
**Numerator:** Order-associated customer records with valid ZIP prefixes, matching representative coordinates and no outside-broad-screening-box flag  
**Denominator:** Order-associated customer records with valid ZIP prefixes  
**Formula:** Numerator / Denominator × 100  
**Baseline percentage:** To be calculated.

This metric describes readiness for approximate ZIP-level mapping, not precise address validity.

Geographic coverage rates should be displayed without a geography slicer when reporting overall coverage; otherwise selecting only matched regions can make the coverage appear artificially complete.

### Supporting Geographic Quality Diagnostics

| Indicator | Verified count |
|---|---:|
| Distinct unmatched customer ZIP prefixes | 157 |
| Distinct unmatched seller ZIP prefixes | 7 |
| ZIP prefixes with conflicting city/state combinations | 8,558 |
| Source points outside broad Brazil screening rectangle | 31 |
| Selected representative points outside rectangle | 4 |

These are quality indicators, not interchangeable denominators for the coverage rates.

Unmatched records and flagged coordinates must remain visible in quality reporting. Exclude the four selected outside-screening-box coordinates from published maps pending verification without deleting the associated orders or sellers.

## 11. Implementation Validation

Before publishing Task 3B metrics:

1. Independently calculate the eligible-delivery population and missing delivered timestamps.
2. Verify on-time and late counts partition the same evaluable delivered population.
3. Check elapsed-time calculations and any negative-duration anomalies.
4. Recalculate customer identity counts and repeat-order measures for the complete historical dataset.
5. Test repeat-order measures under individual year and order-status filters.
6. Confirm geographic LEFT JOINs do not multiply customer, seller or fact records.
7. Validate record-level geographic coverage separately from distinct-ZIP counts.
8. Confirm reported map-ready points follow the documented coordinate-screening rule.
9. Verify metric names, filters and denominators agree across PostgreSQL and Power BI.

**Task 3B status:** KPI definitions established; analytical SQL implementation and full numerical baselines pending.

--------------------------------------------------------------------------------------------
## Task 3C — Product, Seller, Payment-Method and Review KPIs

**Status:** Business definitions established; analytical SQL and Power BI implementation pending.

### General Rules

- All monetary values are denominated in Brazilian Real (BRL).
- Product and Seller metrics use the order-item fact grain.
- Payment-method metrics use the recorded payment-entry grain.
- Review-level satisfaction metrics use the source review-record grain.
- Order-level review coverage is calculated from the Orders fact with an independently derived review-existence indicator.
- Do not join item, payment, and review detail tables directly to calculate financial metrics.
- Ratios return NULL/blank when the denominator is zero.
- Calculate rates from filtered numerators and denominators rather than averaging previously calculated percentages.
- All quoted baseline counts describe the complete historical dataset, without dashboard filters.

## 12. Product Performance KPIs

### KPI-035 — Order Item Records

**Source:** `analytics.fact_order_items`

**Grain:** Order-item record

**Formula:** Count order-item rows in the selected filter context.

**Denominator:** Not applicable.

**Full-dataset baseline:** 112,650.

**Interpretation:** Number of recorded order-item entries, not distinct marketplace orders. No separate source quantity field is assumed.

### KPI-036 — Distinct Orders Containing Selected Products

**Source:** `analytics.fact_order_items`

**Grain:** Distinct order within the filtered item population

**Formula:** COUNT(DISTINCT order_id).

**Denominator:** Not applicable.

**Full-dataset baseline:** 98,666.

**Filtering:** Product, category, Seller, Purchase Date, Order Status, Customer, and applicable geographic filters.

**Interpretation:** An order containing items from multiple categories may contribute to multiple category-level counts. Do not add those counts and interpret the result as total distinct marketplace orders.

### KPI-037 — Average Item Price

**Source:** `analytics.fact_order_items`

**Numerator:** SUM(item_price).

**Denominator:** Number of item records with a nonmissing item_price.

**Formula:** Numerator / Denominator.

**Baseline:** To be verified during implementation.

**Interpretation:** Average recorded price per item entry, not average order value, seller profit, or recognized revenue.

### KPI-038 — Average Freight per Item

**Source:** `analytics.fact_order_items`

**Numerator:** SUM(freight_amount).

**Denominator:** Number of item records with a nonmissing freight_amount.

**Formula:** Numerator / Denominator.

**Baseline:** To be verified.

**Interpretation:** Average recorded freight amount per item entry, not actual logistics cost or carrier expense.

### KPI-039 — Product Category Item-Price Share

**Source:** `analytics.fact_order_items`

**Dimension:** `analytics.dim_product`

**Numerator:** Recorded item-price total for the selected product category.

**Denominator:** Recorded item-price total across all product categories under the same non-product filters.

**Formula:** Numerator / Denominator × 100.

**Filtering:** Preserve Purchase Date, Order Status, Customer, Customer Geography, and Seller filters. Remove Product dimension filters only for the denominator.

**Category treatment:** Include translated categories, untranslated-category fallbacks, and missing-category reporting labels.

**Baseline:** To be verified.

**Interpretation:** Category contribution to recorded item-price volume, not recognized revenue or profit.

## 13. Seller Performance KPIs

### KPI-040 — Active Sellers With Order Items

**Source:** `analytics.fact_order_items`

**Formula:** COUNT(DISTINCT seller_id) in the filtered item population.

**Denominator:** Not applicable.

**Full-dataset baseline:** 3,095.

**Interpretation:** Sellers associated with recorded item entries, not necessarily sellers currently operating.

### KPI-041 — Seller–Order Associations

**Source:** `analytics.fact_order_items`

**Grain:** Distinct combination of seller_id and order_id.

**Formula:** Count distinct (seller_id, order_id) pairs.

**Denominator:** Not applicable.

**Baseline:** To be verified.

**Interpretation:** Counts an order separately for each seller associated with it. This is not the same as distinct marketplace orders.

### KPI-042 — Sellers With Multiple Distinct Orders

**Source:** `analytics.fact_order_items`

**Numerator:** Number of sellers associated with at least two distinct order IDs within the current filter context.

**Formula:** Group filtered item records by seller_id, count distinct order_id for each seller, then count sellers whose order count exceeds one.

**Denominator:** Not applicable.

**Full-dataset baseline:** 2,524.

**Interpretation:** Observed multi-order seller activity, not proof of ongoing commercial activity or seller retention.

### KPI-043 — Multi-Order Seller Share

**Source:** `analytics.fact_order_items`

**Numerator:** Sellers With Multiple Distinct Orders.

**Denominator:** Active Sellers With Order Items.

**Formula:** Numerator / Denominator × 100.

**Baseline:** To be calculated.

**Filtering:** Both numerator and denominator must use the same filtered population.

### KPI-044 — Top 10 Seller Item-Price Concentration

**Source:** `analytics.fact_order_items`

**Numerator:** Total recorded item prices attributed to the ten sellers with the highest item-price totals.

**Denominator:** Recorded item-price total across all eligible sellers within the same non-seller filter context.

**Formula:** Numerator / Denominator × 100.

**Ranking:** Rank eligible sellers by item-price total descending, using seller_id as a deterministic tie-breaker when needed.

**Filtering:** Preserve Purchase Date, Order Status, Customer, Customer Geography, and Product filters. Remove Seller dimension filters for the concentration benchmark.

**Baseline:** To be verified.

**Interpretation:** Concentration of recorded item-price activity, not seller profit, net sales, or received payments.

## 14. Payment-Method KPIs

### KPI-045 — Payment Entries

**Source:** `analytics.fact_payments`

**Grain:** Payment entry

**Formula:** COUNT of payment records.

**Denominator:** Not applicable.

**Full-dataset baseline:** 103,886.

**Interpretation:** Number of recorded payment entries, not distinct paid orders or confirmed settled payments.

### KPI-046 — Orders With Recorded Payments

**Source:** `analytics.fact_payments`

**Formula:** COUNT(DISTINCT order_id).

**Denominator:** Not applicable.

**Full-dataset baseline:** 99,440.

**Interpretation:** Orders having one or more source payment entries, including any zero-value entries. Not proof of completed settlement.

### KPI-047 — Recorded Payment Amount Share by Method

**Source:** `analytics.fact_payments`

**Numerator:** SUM(payment_amount) for the selected payment_method.

**Denominator:** SUM(payment_amount) across all payment methods under the same non-method filters.

**Formula:** Numerator / Denominator × 100.

**Filtering:** Retain applicable Purchase Date, Order Status, Customer, and Customer Geography filters. Remove only payment_method filters for the denominator.

**Missing/anomalous data:** Preserve zero-value and undefined-method records. Undefined payment methods should remain visible as their own category.

**Baseline:** To be verified.

**Interpretation:** Share of source-recorded payment amounts by method, not share of orders and not a breakdown of recognized revenue.

**Date interpretation:** Purchase Date filters payments associated with orders purchased in that period, not payments confirmed to have occurred during that period.

### KPI-048 — Average Valid Credit-Card Installments

**Source:** `analytics.fact_payments`

**Numerator:** SUM(payment_installments) for records where payment_method = 'credit_card' and payment_installments > 0.

**Denominator:** Count of qualifying credit-card payment entries with positive installment counts.

**Formula:** Numerator / Denominator.

**Baseline:** To be verified.

**Quality treatment:** Preserve zero-installment records in the fact table but exclude them from this positive-installment average. Report anomalies separately.

**Interpretation:** Average recorded installment count per eligible credit-card payment entry, not the number of installments actually paid.

### KPI-049 — Flagged Payment Entry Rate

**Source:** `analytics.fact_payments`

**Numerator:** Count payment entries where has_payment_quality_flag = TRUE.

**Denominator:** Total payment entries in the same filter context.

**Formula:** Numerator / Denominator × 100.

**Full-dataset baselines:** 11 flagged payment entries out of 103,886 payment entries.

**Flag conditions:** Zero-value payment, zero installments, or undefined payment method.

**Interpretation:** Source metadata/record exception rate, not a payment reconciliation mismatch rate, fraud rate, or financial loss rate.

## 15. Customer Review and Satisfaction KPIs

### KPI-050 — Review Records

**Source:** `analytics.fact_order_reviews`

**Grain:** Source review record

**Formula:** COUNT of review records.

**Denominator:** Not applicable.

**Full-dataset baseline:** 99,224.

**Interpretation:** Review records, not distinct reviewed orders or distinct customers.

### KPI-051 — Average Review Score

**Source:** `analytics.fact_order_reviews`

**Numerator:** SUM(review_score) for records with valid review scores between 1 and 5.

**Denominator:** Count of review records with valid scores between 1 and 5.

**Formula:** Numerator / Denominator.

**Full-dataset baseline:** Approximately 4.09.

**Interpretation:** Review-record-weighted average score. Orders with multiple reviews can contribute multiple scores.

### KPI-052 — High-Rating Review Share

**Source:** `analytics.fact_order_reviews`

**Numerator:** Count of review records with review_score IN (4, 5).

**Denominator:** Count of review records with valid scores between 1 and 5.

**Formula:** Numerator / Denominator × 100.

**Verified score distribution:** 19,142 four-star reviews and 57,328 five-star reviews.

**Baseline percentage:** To be verified during implementation.

**Interpretation:** Share of valid review records rated four or five stars. Not a unique-customer satisfaction rate.

### KPI-053 — Written Feedback Availability Rate

**Source:** `analytics.fact_order_reviews`

**Numerator:** Count of reviews where has_no_written_feedback = FALSE.

**Denominator:** Total review records in the same filter context.

**Formula:** Numerator / Denominator × 100.

**Verified source finding:** 56,527 reviews have neither a title nor a written message.

**Baseline percentage:** To be verified.

**Interpretation:** Share of reviews containing at least a written title or message. Reviews lacking written feedback can still contain valid numeric scores.

### KPI-054 — Distinct Reviewed Orders

**Source:** `analytics.fact_order_reviews`

**Formula:** COUNT(DISTINCT order_id) in the filtered review population.

**Denominator:** Not applicable.

**Full-dataset baseline:** 98,673.

**Filtering:** Review Date filters this measure by review creation activity. Purchase Date filters it by the purchase period of the associated order.

**Interpretation:** Number of distinct orders represented by the filtered review records.

### KPI-055 — Review Coverage by Purchase Cohort

**Source:** `analytics.fact_orders`

**Grain:** Order

**Required planned field:** `has_review_record`, independently derived by checking whether any source review references the order.

**Numerator:** Orders in the selected purchase cohort with has_review_record = TRUE.

**Denominator:** All orders in the same selected purchase cohort.

**Formula:** Numerator / Denominator × 100.

**Full-dataset baseline counts:** 98,673 orders with at least one review; 99,441 total orders.

**Filtering:** Respect Purchase Date, Customer, Order Status, and Customer Geography filters. Review Date must not redefine this historical review-existence measure.

**Interpretation:** Share of orders that have at least one review in the available historical source, not response rate within a fixed number of days after purchase.

**Known source characteristic:** 547 orders have multiple review records. A reviewed order is counted once in this measure.

## 16. Cross-Fact Safeguards

1. Product and Seller metrics derive from `fact_order_items` and do not automatically allocate payment amounts.
2. Payment Method metrics derive from `fact_payments` and use payment-entry grain.
3. Review-level averages and distributions derive from `fact_order_reviews` and retain the source review-record grain.
4. Purchase-cohort review coverage derives from `fact_orders`, using an order-level review-existence indicator.
5. Do not join detailed items, payments, and reviews directly to produce aggregate monetary or satisfaction measures.
6. Use appropriate distinct counts for orders, sellers, and customer identities.
7. Preserve source missingness and quality flags without asserting accounting settlement, recognized revenue, profitability, or fraud.
8. Recalculate ratio numerators and denominators within the applicable filter context.
9. Maintain accurate labels distinguishing purchase-date-linked payment analysis from actual payment-event timing.
10. Validate KPI results in PostgreSQL before creating or publishing Power BI measures.

## 17. Implementation Validation

Before publishing the Task 3C metrics:

- Verify 112,650 order-item records and 98,666 distinct associated orders.
- Verify 3,095 active sellers and 2,524 multi-order sellers at the full-dataset level.
- Check that seller–order associations do not get confused with marketplace distinct-order counts.
- Reconcile product and seller monetary totals with recorded item-price fields.
- Confirm payment-entry counts, distinct paid-record orders, and payment anomaly flags.
- Reconcile all payment-method amounts to total recorded payment value under matching filters.
- Verify valid installment eligibility and the treatment of zero-installment entries.
- Reproduce the review-score distribution and approximate mean of 4.09.
- Confirm review counts versus distinct reviewed orders.
- Validate purchase-cohort review coverage independently of Review Date slicers.
- Test Product, Seller, Customer, Date, and Order Status filter behavior in Power BI.
- Explicitly test denominator behavior for category share, payment-method share, and top-seller concentration.

## 18. Design Status

**Task 3A:** Order and financial KPI definitions — Complete.

**Task 3B:** Fulfillment, Customer, and Geographic KPI definitions — Complete.

**Task 3C:** Product, Seller, Payment-Method, and Review KPI definitions — Complete.

**Total defined KPIs:** 55.

No ANALYTICS facts, dimensions, or Power BI measures have been implemented yet.

**Next step:** Step 6.1 Task 4 — Final ANALYTICS model blueprint review and sign-off.

--------------------------------------------------------------------------------------------

### Verified Fulfillment Baselines — ANALYTICS

Source: analytics.fact_orders

- Delivered-status orders: 96,478
- Evaluable delivered orders: 96,470
- Delivered-status orders missing actual delivery: 8
- On-time delivered orders: 89,936
- Late delivered orders: 6,534
- On-time Delivery Rate (KPI-023): 93.23%
- Late Delivery Rate (KPI-024): 6.77%
- Negative purchase-to-delivery durations: 0
- Inconsistent fulfillment records: 0

On-time and late rates use the 96,470 evaluable
delivered orders as their common denominator.

--------------------------------------------------------------------------------------------

### Verified Item-Level Monetary Baselines

Source: analytics.fact_order_items

- Order-item records: 112,650
- Distinct orders containing items: 98,666
- KPI-005 Recorded Item Price Total: R$13,591,643.70
- KPI-006 Recorded Freight Total: R$2,251,909.54
- KPI-007 Recorded Item + Freight Total: R$15,843,553.24
- Missing shipping-limit timestamps: 0

The all-record item-plus-freight total exceeds the
comparable-order item-plus-freight total by R$143.46.

All-record and comparable-order financial measures must
remain separately labeled in SQL and Power BI.
