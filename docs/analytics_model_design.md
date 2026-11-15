# ANALYTICS Star Schema — Model Design

**Project:** Order-to-Cash Intelligence Platform  
**Database:** PostgreSQL `olist_analytics`  
**Target schema:** `analytics`  
**Source layer:** Validated SQL STAGING models  
**Status:** Design in progress — fact grains and dimension relationships defined

## 1. Objective

Design a reliable analytical warehouse for order-to-cash reporting, financial reconciliation, customer behavior, product and seller performance, fulfillment, and customer satisfaction.

The warehouse will support PostgreSQL analysis and Power BI reporting while preventing double-counting across source tables with different grains.

## 2. Fact Table Design

### Fact 1 — analytics.fact_orders

**Grain:** One row per order.

**Logical key:** `order_id`.

**Expected records:** 99,441.

**Source:** `staging.stg_orders`, with independently aggregated Order Items and Payments and validated customer lookup attributes.

**Planned analysis:**
- Orders by status and purchase period.
- Item-price and freight totals.
- Recorded payment totals.
- Financial reconciliation classifications and differences.
- Delivery timeliness and fulfillment performance.

**Rules:**
- Preserve all orders, regardless of status.
- Aggregate Items and Payments separately before joining.
- Preserve missing financial records as NULL rather than zero.
- Do not classify recorded payment amounts as recognized accounting revenue.
- Maintain exactly one row per order.

### Fact 2 — analytics.fact_order_items

**Grain:** One row per source order-item record.

**Logical key:** `(order_id, order_item_id)`.

**Expected records:** 112,650.

**Source:** `staging.stg_order_items`, enriched with order-level dimension keys.

**Planned analysis:**
- Product and seller activity.
- Item prices and freight.
- Product category performance.
- Distinct associated orders.

**Rules:**
- Preserve product and seller identifiers.
- Preserve exact source monetary values.
- Distinguish item counts from distinct order counts.
- Do not copy order-level payment amounts onto item rows.

### Fact 3 — analytics.fact_payments

**Grain:** One row per recorded payment entry.

**Logical key:** `(order_id, payment_sequential)`.

**Expected records:** 103,886.

**Source:** `staging.stg_order_payments`, enriched with order-level dimension keys.

**Planned analysis:**
- Recorded payments by method.
- Installment distributions.
- Split payments.
- Payment-quality exceptions.

**Rules:**
- Preserve zero-value and multi-payment records.
- Preserve original payment amounts and quality flags.
- Aggregate payments by order before financial reconciliation.
- Do not infer payment dates from purchase dates.

### Fact 4 — analytics.fact_order_reviews

**Grain:** One row per source review record.

**Logical key:** `(review_id, order_id)`.

**Expected records:** 99,224.

**Source:** `staging.stg_order_reviews`, enriched with order-level dimension keys.

**Planned analysis:**
- Review scores and distributions.
- Written feedback coverage.
- Review creation trends.
- Delivery experience and rating associations.

**Rules:**
- Preserve multiple reviews for an order.
- Distinguish review-record counts from distinct reviewed orders.
- Do not replicate order-level financial values onto review records.
- Define review aggregation explicitly when producing order-level satisfaction metrics.

## 3. Cross-Fact Modeling Rules

- Never directly combine item-level, payment-level and review-level detail without accounting for their different grains.
- Use one-row-per-order aggregations for financial reconciliation.
- Keep source identifiers for traceability.
- Preserve missing financial data rather than manufacturing zero amounts.
- Do not infer refunds, settlement, profit, recognized revenue, or recoverable loss without supporting evidence.
- Validate analytical row counts, keys, relationships and totals before publishing reports.
- Enrich facts with identifying/filtering keys, not replicated financial measures.

## 4. Dimension Table Design

### Dimension 1 — analytics.dim_customer

**Grain:** One row per observed customer identity.

**Key:** `customer_unique_id`.

**Expected records:** 96,096.

**Source:** Distinct customer identities from `staging.stg_customers`.

**Purpose:** Customer identity filtering, observed ordering behavior, and repeat-customer analysis.

**Important rules:**
- Do not use `customer_id` as the dimension key.
- Preserve `customer_id` in appropriate fact records for traceability.
- Do not assign one permanent geographic location to a customer identity without evidence.
- Calculate period-specific customer KPIs from filtered fact records, not unfiltered dimension counts.

### Dimension 2 — analytics.dim_product

**Grain:** One row per product.

**Key:** `product_id`.

**Expected records:** 32,951.

**Source:** `staging.stg_products`.

**Attributes:** Portuguese category, English category, display category, category status, physical measurements, and source-quality indicators.

**Relationship:** One-to-many to `fact_order_items`.

### Dimension 3 — analytics.dim_seller

**Grain:** One row per seller.

**Key:** `seller_id`.

**Expected records:** 3,095.

**Source:** `staging.stg_sellers`, optionally enriched through the validated ZIP reference.

**Attributes:** Seller ZIP prefix, city, state, optional representative coordinates, and geographic-quality flags.

**Relationship:** One-to-many to `fact_order_items`.

Seller geography remains independent of customer geography to avoid ambiguous filter paths.

### Dimension 4 — analytics.dim_order_status

**Grain:** One row per distinct order status.

**Key:** `order_status`.

**Expected records:** 8, based on the audited dataset.

**Source:** Distinct values from `staging.stg_orders`.

**Purpose:** Consistent status filtering across all four facts.

### Dimension 5 — analytics.dim_purchase_date

**Grain:** One row per calendar date.

**Key:** `date` (PostgreSQL DATE).

**Source:** Calendar generated from the observed purchase-date range.

**Attributes:** Date, year, quarter, month number, month name, year-month, day of week and other validated calendar attributes.

**Relationships:** One-to-many to all four fact tables using purchase date.

For detailed facts, purchase date is inherited from the associated order.

**Interpretation:** Purchase-date filtering is not equivalent to payment-event-date or review-event-date filtering.

### Dimension 6 — analytics.dim_delivery_date

**Grain:** One row per calendar date.

**Key:** `date`.

**Purpose:** Analyze actual customer delivery dates.

**Relationship:** One-to-many to `fact_orders` using the date component of actual customer delivery timestamp.

Orders without a recorded delivery date must remain present in `fact_orders`.

### Dimension 7 — analytics.dim_review_date

**Grain:** One row per calendar date.

**Key:** `date`.

**Purpose:** Analyze review activity by review creation date.

**Relationship:** One-to-many to `fact_order_reviews`.

This dimension is separate from Purchase Date so both time perspectives can be analyzed explicitly.

### Dimension 8 — analytics.dim_customer_geography

**Grain:** One row per distinct observed combination of customer ZIP prefix, city and state.

**Key:** A stable, validated `customer_location_key` derived from the normalized location fields.

**Sources:** `staging.stg_customers`, with optional coordinates from `staging.ref_zip_geolocation`.

**Attributes:** Customer ZIP prefix, original standardized city/state labels, optional representative coordinates, missing-geolocation indicator and geographic-screening indicators.

**Purpose:** Customer-region filtering and approximate geographic visualization across all four facts.

**Rules:**
- Preserve the customer location labels from the actual customer record.
- Do not assume the representative ZIP coordinate is the customer's precise location.
- Retain unmatched geographic references with NULL coordinates.
- Exclude the four flagged representative coordinate outliers from published maps pending verification, without deleting associated customers or orders.
- Validate uniqueness of `customer_location_key` and preserve all source customer associations.

The final number of distinct customer location combinations will be verified during dimension development.

## 5. Fact-to-Dimension Relationships

The following relationships are proposed as active, one-to-many, single-direction relationships from dimensions to facts.

| Dimension | fact_orders | fact_order_items | fact_payments | fact_order_reviews |
|---|---|---|---|---|
| dim_customer | Yes | Yes | Yes | Yes |
| dim_purchase_date | Yes | Yes | Yes | Yes |
| dim_order_status | Yes | Yes | Yes | Yes |
| dim_customer_geography | Yes | Yes | Yes | Yes |
| dim_product | No | Yes | No | No |
| dim_seller | No | Yes | No | No |
| dim_delivery_date | Yes | No | No | No |
| dim_review_date | No | No | No | Yes |

Each fact will receive the necessary keys from its associated order and customer record through validated one-to-one or many-to-one SQL lookups.

All relationship cardinalities and filter paths will be checked in Power BI before dashboard development.

## 6. Filtering and Modeling Restrictions

### One-way filtering

Use dimension-to-fact filtering by default.

Avoid introducing bidirectional relationships merely to make different fact tables filter one another.

### No initial fact-to-fact relationships

Do not directly connect the four fact tables in the Power BI model.

`order_id` remains available within each fact as a degenerate identifier for traceability and deliberately designed order-level drill-through.

### Product and Seller filtering

Product and Seller dimensions filter `fact_order_items`.

They do not automatically filter recorded payments or allocate order-level payments across products or sellers.

Product- or seller-scoped distinct-order metrics should be calculated using the appropriate item-level fact or a separately validated order-set calculation.

### Customer filtering

Use `customer_unique_id` to filter all four facts.

Period-specific distinct-customer measures should use filtered fact-level identity keys.

A count of rows in the Customer dimension is not automatically a valid period-specific active-customer measure.

### Date filtering

Use Purchase Date for analyses of activity associated with order purchase periods.

Use Delivery Date specifically for fulfillment timelines.

Use Review Date specifically for review creation activity.

Do not label purchase-date-linked payment totals as amounts paid on those calendar dates.

### Customer geography

Customer geography filters facts through a validated customer location key.

Seller geography is embedded in `dim_seller` for the initial design.

Avoid creating competing direct and indirect geography paths that could make filtering ambiguous.

### Missing data

Keep missing dimension associations and geographic coverage gaps visible.

Do not remove fact records because representative coordinates are missing or flagged.

## 7. Planned KPI Definitions

The next design task will formally define:

- Total orders and order status metrics.
- Recorded item-price and freight totals.
- Recorded payment totals.
- Average order value with explicit amount and denominator definitions.
- Financial reconciliation rate and discrepancy amounts.
- Delivery timeliness and fulfillment durations.
- Repeat-customer share and distinct purchasing identities.
- Product and seller order activity.
- Review-score and review-coverage measures.

Each KPI must document its fact source, grain, formula, filters, denominator, missing-value treatment and interpretation.

## 8. Implementation and Validation Requirements

Before publishing the Power BI model:

1. Verify each dimension's expected grain and uniqueness.
2. Confirm all fact foreign keys match their related dimensions or documented unknown members.
3. Verify row counts are unchanged after dimension-key enrichment.
4. Ensure that repeated dimension keys do not create join fanout.
5. Validate date range coverage for all three date roles.
6. Confirm geographic joins preserve fact counts and retain unmatched coverage.
7. Reconcile financial measures with the independently validated Python and SQL baselines.
8. Test single-direction filtering and detect ambiguous relationship paths.
9. Confirm that product/seller filtering does not misleadingly reallocate recorded payments.
10. Document any measures requiring explicit cross-fact order-set logic.

## 9. Design Status

**Task 1:** Fact grains defined — Complete.

**Task 2:** Dimension grains and relationships defined — Pending final review.

**Task 3:** KPI definitions — Next.

**Task 4:** Final model blueprint sign-off — Pending.

No ANALYTICS fact or dimension tables have been created yet.

--------------------------------------------------------------------------------------------

**Implementation status:** Completed and validated.

- Source: staging.stg_orders
- First purchase date: 2016-09-04
- Last purchase date: 2018-10-17
- Calendar records: 774
- Distinct dates with orders: 634
- Calendar days without orders: 140
- Missing purchase timestamps: 0
- Missing calendar dates: 0
- Inconsistent calendar attributes: 0
- Order join validation: PASS, 99,441 rows preserved

--------------------------------------------------------------------------------------------

**Implementation status:** Completed and validated.

- Source: staging.stg_orders
- Earliest actual delivery date: 2016-10-11
- Latest actual delivery date: 2018-10-17
- Calendar records: 737
- Distinct dates containing deliveries: 645
- Calendar dates without deliveries: 92
- Orders with actual delivery timestamps: 96,476
- Orders missing actual delivery timestamps: 2,965
- Delivered-status orders missing actual delivery: 8
- Canceled-status orders with actual delivery: 6
- Missing calendar dates: 0
- Inconsistent calendar attributes: 0
- Order relationship validation: PASS, all 99,441 orders preserved

--------------------------------------------------------------------------------------------

**Implementation status:** Completed and validated.

- Source: staging.stg_order_reviews
- Date field: review_creation_timestamp
- Earliest review date: 2016-10-02
- Latest review date: 2018-08-31
- Calendar records: 699
- Distinct dates with reviews: 636
- Calendar days without reviews: 63
- Missing review creation timestamps: 0
- Missing calendar dates: 0
- Inconsistent calendar attributes: 0
- Review join validation: PASS, 99,224 records preserved
