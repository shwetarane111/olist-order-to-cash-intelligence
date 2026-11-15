
-- ============================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 7.5: SIX-PAGE RELEASE VALIDATION
-- FILE: 48_powerbi_cross_page_release_validation.sql
-- DATABASE: olist_analytics
-- TYPE: READ-ONLY
-- ============================================================

-- Cohorts:
-- ALL: entire historical dataset.
-- Q1_2018_DELIVERED:
-- purchase_date >= 2018-01-01
-- purchase_date <  2018-04-01
-- order_status = delivered.
--
-- Run SQL-R1 through SQL-R4 separately.


-- ============================================================
-- SQL-R1: ORDER, FULFILLMENT AND FINANCIAL RECONCILIATION
-- ============================================================

WITH scoped_orders AS (

    SELECT
        'ALL'::text AS cohort,
        o.*
    FROM analytics.fact_orders AS o

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED'::text AS cohort,
        o.*
    FROM analytics.fact_orders AS o
    WHERE o.purchase_date >= DATE '2018-01-01'
      AND o.purchase_date < DATE '2018-04-01'
      AND o.order_status = 'delivered'
),

results AS (

    SELECT
        cohort,

        COUNT(*) AS total_orders,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
        ) AS delivered_orders,

        COUNT(*) FILTER (
            WHERE is_delivery_evaluable IS TRUE
        ) AS evaluable_delivered_orders,

        COUNT(*) FILTER (
            WHERE is_delivered_on_time IS TRUE
        ) AS on_time_orders,

        COUNT(*) FILTER (
            WHERE is_delivered_late IS TRUE
        ) AS late_orders,

        ROUND(
            AVG(purchase_to_delivery_days)
                FILTER (
                    WHERE is_delivery_evaluable IS TRUE
                )::numeric,
            2
        ) AS average_delivery_days,

        COUNT(*) FILTER (
            WHERE reconciliation_status IN (
                'MATCH', 'MISMATCH'
            )
        ) AS comparable_orders,

        COUNT(*) FILTER (
            WHERE reconciliation_status = 'MATCH'
        ) AS matched_orders,

        COUNT(*) FILTER (
            WHERE reconciliation_status = 'MISMATCH'
        ) AS mismatched_orders,

        COUNT(*) FILTER (
            WHERE reconciliation_status IN (
                'MISSING_ITEMS',
                'MISSING_PAYMENTS',
                'MISSING_BOTH'
            )
        ) AS financial_coverage_gaps,

        COALESCE(
            ROUND(
                SUM(payment_difference)
                    FILTER (
                        WHERE reconciliation_status IN (
                            'MATCH', 'MISMATCH'
                        )
                    )::numeric,
                2
            ),
            0
        ) AS net_payment_difference,

        COALESCE(
            ROUND(
                SUM(absolute_payment_difference)
                    FILTER (
                        WHERE reconciliation_status IN (
                            'MATCH', 'MISMATCH'
                        )
                    )::numeric,
                2
            ),
            0
        ) AS absolute_discrepancy

    FROM scoped_orders
    GROUP BY cohort
)

SELECT
    *,

    ROUND(
        100.0 * on_time_orders
        / NULLIF(evaluable_delivered_orders, 0),
        2
    ) AS on_time_rate_pct,

    ROUND(
        100.0 * matched_orders
        / NULLIF(comparable_orders, 0),
        2
    ) AS financial_match_rate_pct,

    total_orders
        - comparable_orders
        - financial_coverage_gaps
        AS coverage_partition_difference,

    comparable_orders
        - matched_orders
        - mismatched_orders
        AS comparable_partition_difference,

    evaluable_delivered_orders
        - on_time_orders
        - late_orders
        AS delivery_partition_difference

FROM results
ORDER BY cohort;



-- ============================================================
-- SQL-R2: CUSTOMER AND REVIEW METRICS
-- ============================================================

WITH scoped_orders AS (

    SELECT
        'ALL'::text AS cohort,
        order_id,
        customer_unique_id,
        has_review_record
    FROM analytics.fact_orders

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED'::text,
        order_id,
        customer_unique_id,
        has_review_record
    FROM analytics.fact_orders
    WHERE purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
      AND order_status = 'delivered'
),

identity_counts AS (

    SELECT
        cohort,
        customer_unique_id,
        COUNT(*) AS order_count
    FROM scoped_orders
    GROUP BY
        cohort,
        customer_unique_id
),

customer_summary AS (

    SELECT
        cohort,
        COUNT(*) AS customer_identities,

        COUNT(*) FILTER (
            WHERE order_count >= 2
        ) AS repeat_identities

    FROM identity_counts
    GROUP BY cohort
),

order_summary AS (

    SELECT
        cohort,
        COUNT(*) AS total_orders,

        COUNT(*) FILTER (
            WHERE has_review_record IS TRUE
        ) AS orders_with_reviews

    FROM scoped_orders
    GROUP BY cohort
),

scoped_reviews AS (

    SELECT
        'ALL'::text AS cohort,
        order_id,
        review_score,
        has_no_written_feedback
    FROM analytics.fact_order_reviews

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED'::text,
        order_id,
        review_score,
        has_no_written_feedback
    FROM analytics.fact_order_reviews
    WHERE purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
      AND order_status = 'delivered'
),

review_summary AS (

    SELECT
        cohort,

        COUNT(*) AS review_records,

        COUNT(DISTINCT order_id)
            AS distinct_reviewed_orders,

        ROUND(
            AVG(review_score)::numeric,
            2
        ) AS average_review_score,

        COUNT(*) FILTER (
            WHERE review_score IN (4, 5)
        ) AS high_rating_reviews,

        COUNT(*) FILTER (
            WHERE review_score BETWEEN 1 AND 5
        ) AS valid_rating_reviews,

        COUNT(*) FILTER (
            WHERE has_no_written_feedback IS FALSE
        ) AS with_written_feedback,

        COUNT(*) FILTER (
            WHERE has_no_written_feedback IS TRUE
        ) AS without_written_feedback

    FROM scoped_reviews
    GROUP BY cohort
)

SELECT
    o.cohort,
    o.total_orders,
    c.customer_identities,
    c.repeat_identities,

    ROUND(
        100.0 * c.repeat_identities
        / NULLIF(c.customer_identities, 0),
        2
    ) AS repeat_share_pct,

    o.orders_with_reviews,
    r.distinct_reviewed_orders,

    ROUND(
        100.0 * o.orders_with_reviews
        / NULLIF(o.total_orders, 0),
        2
    ) AS review_coverage_pct,

    r.review_records,
    r.average_review_score,
    r.high_rating_reviews,

    ROUND(
        100.0 * r.high_rating_reviews
        / NULLIF(r.valid_rating_reviews, 0),
        2
    ) AS high_rating_share_pct,

    r.with_written_feedback,
    r.without_written_feedback,

    ROUND(
        100.0 * r.with_written_feedback
        / NULLIF(r.review_records, 0),
        2
    ) AS written_feedback_share_pct,

    o.orders_with_reviews
        - r.distinct_reviewed_orders
        AS reviewed_order_difference,

    r.review_records
        - r.with_written_feedback
        - r.without_written_feedback
        AS feedback_partition_difference

FROM order_summary AS o

JOIN customer_summary AS c
    USING (cohort)

JOIN review_summary AS r
    USING (cohort)

ORDER BY o.cohort;



-- ============================================================
-- SQL-R3: ITEMS, SELLERS AND PAYMENTS
-- ============================================================

WITH scoped_items AS (

    SELECT
        'ALL'::text AS cohort,
        order_id,
        product_id,
        seller_id,
        item_price,
        freight_amount
    FROM analytics.fact_order_items

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED'::text,
        order_id,
        product_id,
        seller_id,
        item_price,
        freight_amount
    FROM analytics.fact_order_items
    WHERE purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
      AND order_status = 'delivered'
),

item_summary AS (

    SELECT
        cohort,
        COUNT(*) AS item_entries,
        COUNT(DISTINCT product_id) AS active_products,
        COUNT(DISTINCT seller_id) AS active_sellers,

        ROUND(
            SUM(item_price)::numeric,
            2
        ) AS item_price,

        ROUND(
            SUM(freight_amount)::numeric,
            2
        ) AS freight,

        ROUND(
            SUM(item_price + freight_amount)::numeric,
            2
        ) AS item_plus_freight

    FROM scoped_items
    GROUP BY cohort
),

seller_orders AS (

    SELECT
        cohort,
        seller_id,
        COUNT(DISTINCT order_id) AS distinct_orders
    FROM scoped_items
    GROUP BY cohort, seller_id
),

seller_summary AS (

    SELECT
        cohort,

        SUM(distinct_orders)
            AS seller_order_associations,

        COUNT(*) FILTER (
            WHERE distinct_orders >= 2
        ) AS multi_order_sellers

    FROM seller_orders
    GROUP BY cohort
),

seller_values AS (

    SELECT
        cohort,
        seller_id,
        SUM(item_price) AS seller_item_price
    FROM scoped_items
    GROUP BY cohort, seller_id
),

ranked_sellers AS (

    SELECT
        cohort,
        seller_id,
        seller_item_price,

        ROW_NUMBER() OVER (
            PARTITION BY cohort
            ORDER BY
                seller_item_price DESC,
                seller_id ASC
        ) AS seller_rank

    FROM seller_values
),

top_ten AS (

    SELECT
        cohort,

        ROUND(
            SUM(seller_item_price)::numeric,
            2
        ) AS top_ten_seller_item_price

    FROM ranked_sellers
    WHERE seller_rank <= 10
    GROUP BY cohort
),

scoped_payments AS (

    SELECT
        'ALL'::text AS cohort,
        payment_amount
    FROM analytics.fact_payments

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED'::text,
        payment_amount
    FROM analytics.fact_payments
    WHERE purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
      AND order_status = 'delivered'
),

payment_summary AS (

    SELECT
        cohort,
        COUNT(*) AS payment_entries,

        ROUND(
            SUM(payment_amount)::numeric,
            2
        ) AS recorded_payment_volume

    FROM scoped_payments
    GROUP BY cohort
)

SELECT
    i.cohort,
    i.item_entries,
    i.item_price,
    i.freight,
    i.item_plus_freight,
    i.active_products,
    i.active_sellers,

    s.seller_order_associations,
    s.multi_order_sellers,

    ROUND(
        100.0 * s.multi_order_sellers
        / NULLIF(i.active_sellers, 0),
        2
    ) AS multi_order_seller_share_pct,

    t.top_ten_seller_item_price,

    ROUND(
        100.0 * t.top_ten_seller_item_price
        / NULLIF(i.item_price, 0),
        2
    ) AS top_ten_concentration_pct,

    p.payment_entries,
    p.recorded_payment_volume

FROM item_summary AS i

JOIN seller_summary AS s
    USING (cohort)

JOIN top_ten AS t
    USING (cohort)

JOIN payment_summary AS p
    USING (cohort)

ORDER BY i.cohort;



-- ============================================================
-- SQL-R4: GEOGRAPHIC QUALITY ACROSS FOUR FACTS
-- ============================================================

WITH base_records AS (

    SELECT
        'Orders'::text AS fact_name,
        order_status,
        purchase_date,
        customer_location_key
    FROM analytics.fact_orders

    UNION ALL

    SELECT
        'Order Items',
        order_status,
        purchase_date,
        customer_location_key
    FROM analytics.fact_order_items

    UNION ALL

    SELECT
        'Payments',
        order_status,
        purchase_date,
        customer_location_key
    FROM analytics.fact_payments

    UNION ALL

    SELECT
        'Reviews',
        order_status,
        purchase_date,
        customer_location_key
    FROM analytics.fact_order_reviews
),

scoped_records AS (

    SELECT
        'ALL'::text AS cohort,
        fact_name,
        customer_location_key
    FROM base_records

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED'::text,
        fact_name,
        customer_location_key
    FROM base_records
    WHERE purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
      AND order_status = 'delivered'
),

classified AS (

    SELECT
        s.cohort,
        s.fact_name,

        CASE
            WHEN g.customer_location_key IS NULL
                THEN 'MISSING_DIMENSION_LINK'

            WHEN g.has_geo_reference IS NOT TRUE
                THEN 'MISSING_REFERENCE'

            WHEN g.is_reference_coordinate_outlier IS TRUE
                THEN 'FLAGGED_COORDINATE'

            WHEN g.has_map_ready_coordinate IS TRUE
                THEN 'MAP_READY'

            ELSE 'OTHER_INSPECT'
        END AS quality_status

    FROM scoped_records AS s

    LEFT JOIN analytics.dim_customer_geography AS g
        ON s.customer_location_key = g.customer_location_key
),

summary AS (

    SELECT
        cohort,
        fact_name,
        COUNT(*) AS total_records,

        COUNT(*) FILTER (
            WHERE quality_status = 'MISSING_DIMENSION_LINK'
        ) AS missing_dimension_links,

        COUNT(*) FILTER (
            WHERE quality_status = 'MISSING_REFERENCE'
        ) AS missing_references,

        COUNT(*) FILTER (
            WHERE quality_status = 'FLAGGED_COORDINATE'
        ) AS flagged_coordinates,

        COUNT(*) FILTER (
            WHERE quality_status = 'MAP_READY'
        ) AS map_ready_records,

        COUNT(*) FILTER (
            WHERE quality_status = 'OTHER_INSPECT'
        ) AS other_inspect_records

    FROM classified
    GROUP BY cohort, fact_name
)

SELECT
    cohort,
    fact_name,
    total_records,
    missing_dimension_links,
    missing_references,
    flagged_coordinates,
    map_ready_records,
    other_inspect_records,

    ROUND(
        100.0 * map_ready_records
        / NULLIF(total_records, 0),
        2
    ) AS map_ready_share_pct,

    total_records
        - missing_dimension_links
        - missing_references
        - flagged_coordinates
        - map_ready_records
        - other_inspect_records
        AS partition_difference,

    CASE
        WHEN missing_dimension_links = 0
         AND other_inspect_records = 0
         AND total_records =
             missing_references
             + flagged_coordinates
             + map_ready_records
        THEN 'PASS'
        ELSE 'FAIL'
    END AS audit_status

FROM summary

ORDER BY
    cohort,
    fact_name;

-- ============================================================
-- RELEASE ACCEPTANCE
-- ============================================================

-- SQL-R1:
-- 2 cohort rows.
-- Orders, fulfillment and financial values match DAX-R1.
-- All partition differences = 0.

-- SQL-R2:
-- 2 cohort rows.
-- Customer/review values match DAX-R2.
-- Reviewed-order and feedback differences = 0.

-- SQL-R3:
-- 2 cohort rows.
-- Item/seller/payment values match DAX-R2/R3.
-- Full top-10 seller item price: 1,787,241.74.
-- Q1 top-10 seller item price: 393,589.46.

-- SQL-R4:
-- 8 rows: 2 cohorts x 4 fact tables.
-- All audit_status values = PASS.
-- All partition differences = 0.

-- No statements insert, update or delete data.

-- ============================================================
-- END OF FILE
-- ============================================================
