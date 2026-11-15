# ANALYTICS Star-Schema Design Sign-off

**Project:** Order-to-Cash Intelligence Platform  
**Database:** PostgreSQL `olist_analytics`  
**Schema:** `analytics`  
**Design version:** 1.0  
**Status:** APPROVED FOR IMPLEMENTATION — Subject to model-level validation

## 1. Purpose

Establish the approved analytical warehouse design before creating PostgreSQL fact and dimension models and connecting Power BI.

The design prioritizes accurate business measures, preservation of source grains, consistent filter behavior, and traceability to the validated STAGING layer.

## 2. Design Inputs

- [STAGING Warehouse Audit Report](staging_warehouse_audit_report.md)
- [ANALYTICS Model Design](analytics_model_design.md)
- [Business KPI Dictionary](kpi_dictionary.md)
- [Geographic Reference Methodology](geographic_reference_methodology.md)

The STAGING layer has passed completeness, key integrity, relationship, transformation, data-quality and financial reconciliation audits.

## 3. Approved Fact Tables

| Model | Grain | Expected Records | Logical Key |
|---|---|---:|---|
| fact_orders | One order | 99,441 | order_id |
| fact_order_items | One order-item record | 112,650 | order_id, order_item_id |
| fact_payments | One payment entry | 103,886 | order_id, payment_sequential |
| fact_order_reviews | One review record | 99,224 | review_id, order_id |

The facts retain their source-level grains.

Order Items, Payments and Reviews must not be directly joined at detail level in aggregate reporting.

Order-level item and payment totals must be calculated independently before reconciliation.

## 4. Approved Dimensions

| Dimension | Grain | Key |
|---|---|---|
| dim_customer | One observed customer identity | customer_unique_id |
| dim_product | One product | product_id |
| dim_seller | One seller | seller_id |
| dim_order_status | One order status | order_status |
| dim_purchase_date | One purchase-calendar date | date |
| dim_delivery_date | One delivery-calendar date | date |
| dim_review_date | One review-calendar date | date |
| dim_customer_geography | One observed ZIP/city/state combination | customer_location_key |

Actual row counts for calendar and customer-geography dimensions will be calculated and validated during implementation.

Customer geography is based on order-associated customer location records, not a presumed permanent address for each customer identity.

Geographic reference coordinates represent approximate ZIP-level locations.

## 5. Power BI Relationship Rules

- Shared dimensions may filter multiple fact tables.
- Default cardinality: one-to-many.
- Default cross-filter direction: single, dimension to fact.
- No initial direct fact-to-fact relationships.
- No undocumented bidirectional filtering.
- Product and Seller dimensions filter Order Items only.
- Purchase Date filters all four facts using their associated order purchase dates.
- Delivery Date filters the Orders fact.
- Review Date filters the Reviews fact.
- Customer identity, Order Status and Customer Geography filter all four facts through verified keys.
- Order-level drill-through across facts requires explicitly designed filtering logic.

All proposed relationships must be tested after actual table implementation.

## 6. Implementation Conventions

### Identifiers

Preserve original business identifiers for traceability.

Derive customer_location_key deterministically from standardized ZIP, city and state values. Validate uniqueness and rebuild stability.

Preserve ZIP prefixes as text to retain leading zeros.

### Monetary Values

Use exact decimal arithmetic.

Keep recorded item prices, freight amounts, and payment amounts distinct.

Treat missing item or payment records as missing, not as confirmed zero-value transactions.

Avoid claims of recognized revenue, settlement, profit, fraud, or recoverable financial losses without supporting source evidence.

### Dates

Generate calendar coverage from observed source timestamp ranges.

Preserve timestamp semantics without unverified timezone conversions.

Retain orders with missing optional delivery timestamps.

### Data Quality

Preserve relevant STAGING quality flags in the appropriate analytical models.

Keep missing translations, missing category attributes, payment anomalies, multiple reviews, and geographic coverage exceptions visible.

### Reviews

Preserve source review records and their composite logical key.

Compute order-level review existence using a distinct order-ID lookup before enriching the Orders fact.

### Geographic Coordinates

Maintain source customer and seller location records even when no geographic coordinates can be assigned.

Flag and exclude the four selected representative coordinates outside the broad screening rectangle from published maps pending verification, without excluding the associated business records.

## 7. KPI Design

The Business KPI Dictionary contains 55 defined metrics across:

- Orders and financial reconciliation.
- Fulfillment and delivery performance.
- Customer behavior and geographic coverage.
- Product and category performance.
- Seller performance.
- Payment-method analysis.
- Reviews and customer satisfaction.

All KPI implementations must preserve their documented grain, numerator, denominator, filter rules, null handling and business interpretation.

The complete KPI dictionary is a measure catalog, not a requirement to display all 55 measures on the dashboard.

## 8. Required Implementation Validation

Before approving the completed ANALYTICS layer:

1. Confirm all four fact-table row counts.
2. Validate dimension-key uniqueness and expected row counts.
3. Confirm no unexplained foreign-key gaps.
4. Verify dimension enrichment does not multiply fact rows.
5. Reproduce financial reconciliation counts and monetary totals.
6. Confirm Purchase, Delivery and Review Date filtering.
7. Validate customer identity and geography associations.
8. Preserve required source-quality indicators.
9. Confirm appropriate review-record versus reviewed-order measures.
10. Compare SQL KPIs with Power BI DAX results.
11. Test filtering for ambiguous or unexpected cross-fact behavior.
12. Document exceptions and unresolved issues before dashboard publication.

## 9. Implementation Sequence

1. Create and validate reusable dimension models.
2. Create and validate the Orders fact.
3. Create and validate the Order Items fact.
4. Create and validate the Payments fact.
5. Create and validate the Reviews fact.
6. Perform the complete ANALYTICS warehouse audit.
7. Connect the approved analytical tables to Power BI.
8. Configure relationships and validate business measures.
9. Build dashboards and document limitations.

Each model is developed and validated before advancing to the next.

## 10. Design Decision

**Design status: APPROVED FOR IMPLEMENTATION.**

The approved conceptual design consists of four fact tables, eight dimensions and 55 KPI definitions.

This approval authorizes analytical model development. It does not mean that the proposed ANALYTICS tables, their relationships, or their Power BI measures have already been implemented or validated.

**Next phase:** Step 6.2 — Build and validate PostgreSQL ANALYTICS dimensions and facts.