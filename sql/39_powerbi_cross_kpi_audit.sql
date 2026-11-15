
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 7.3 - TASK 9
-- FILE: 39_powerbi_cross_kpi_audit.sql
-- PURPOSE: Independent cross-functional KPI validation
-- =====================================================

WITH orders AS (
    SELECT
        COUNT(*) AS delivered_orders,

        COUNT(*) FILTER (
            WHERE is_delivered_on_time
        ) AS on_time_deliveries,

        COUNT(*) FILTER (
            WHERE is_delivered_late
        ) AS late_deliveries,

        COUNT(*) FILTER (
            WHERE reconciliation_status = 'MATCH'
        ) AS matched_orders,

        COUNT(*) FILTER (
            WHERE reconciliation_status = 'MISMATCH'
        ) AS mismatched_orders,

        COUNT(DISTINCT customer_unique_id)
            AS customer_identities,

        COUNT(*) FILTER (
            WHERE has_review_record
        ) AS orders_with_reviews

    FROM analytics.fact_orders

    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
),

repeat_customers AS (
    SELECT
        COUNT(*) AS repeat_order_identities

    FROM (
        SELECT customer_unique_id
        FROM analytics.fact_orders

        WHERE order_status = 'delivered'
          AND purchase_date >= DATE '2018-01-01'
          AND purchase_date < DATE '2018-04-01'

        GROUP BY customer_unique_id
        HAVING COUNT(*) > 1
    ) AS repeated
),

items AS (
    SELECT
        COUNT(*) AS item_entries,
        SUM(item_total_amount) AS item_plus_freight

    FROM analytics.fact_order_items

    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
),

payments AS (
    SELECT
        COUNT(*) AS payment_entries,
        SUM(payment_amount) AS recorded_payments

    FROM analytics.fact_payments

    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
),

reviews AS (
    SELECT
        COUNT(*) AS review_records

    FROM analytics.fact_order_reviews

    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
),

geo AS (
    SELECT
        COUNT(*) FILTER (
            WHERE fact_name = 'Orders'
        ) AS map_ready_orders,

        COUNT(*) FILTER (
            WHERE fact_name = 'Items'
        ) AS map_ready_items,

        COUNT(*) FILTER (
            WHERE fact_name = 'Payments'
        ) AS map_ready_payments,

        COUNT(*) FILTER (
            WHERE fact_name = 'Reviews'
        ) AS map_ready_reviews

    FROM (
        SELECT
            'Orders' AS fact_name,
            customer_location_key
        FROM analytics.fact_orders
        WHERE order_status = 'delivered'
          AND purchase_date >= DATE '2018-01-01'
          AND purchase_date < DATE '2018-04-01'

        UNION ALL

        SELECT 'Items', customer_location_key
        FROM analytics.fact_order_items
        WHERE order_status = 'delivered'
          AND purchase_date >= DATE '2018-01-01'
          AND purchase_date < DATE '2018-04-01'

        UNION ALL

        SELECT 'Payments', customer_location_key
        FROM analytics.fact_payments
        WHERE order_status = 'delivered'
          AND purchase_date >= DATE '2018-01-01'
          AND purchase_date < DATE '2018-04-01'

        UNION ALL

        SELECT 'Reviews', customer_location_key
        FROM analytics.fact_order_reviews
        WHERE order_status = 'delivered'
          AND purchase_date >= DATE '2018-01-01'
          AND purchase_date < DATE '2018-04-01'
    ) AS facts

    JOIN analytics.dim_customer_geography AS g
        ON facts.customer_location_key = g.customer_location_key

    WHERE g.has_map_ready_coordinate
)

SELECT
    o.delivered_orders,
    o.on_time_deliveries,
    o.late_deliveries,
    o.matched_orders,
    o.mismatched_orders,
    i.item_entries,
    i.item_plus_freight,
    p.payment_entries,
    p.recorded_payments,
    o.customer_identities,
    rc.repeat_order_identities,
    r.review_records,
    o.orders_with_reviews,
    g.map_ready_orders,
    g.map_ready_items,
    g.map_ready_payments,
    g.map_ready_reviews

FROM orders AS o
CROSS JOIN repeat_customers AS rc
CROSS JOIN items AS i
CROSS JOIN payments AS p
CROSS JOIN reviews AS r
CROSS JOIN geo AS g;
