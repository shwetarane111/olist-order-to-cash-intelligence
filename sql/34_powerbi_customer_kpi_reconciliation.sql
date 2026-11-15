
-- =====================================================
-- STEP 7.3 - TASK 4
-- Independent SQL customer KPI reconciliation
-- =====================================================

WITH scoped_orders AS (

    SELECT
        'ALL' AS cohort,
        customer_unique_id,
        order_id
    FROM analytics.fact_orders

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED' AS cohort,
        customer_unique_id,
        order_id
    FROM analytics.fact_orders
    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'

),

customer_order_counts AS (

    SELECT
        cohort,
        customer_unique_id,
        COUNT(*)::BIGINT AS order_count
    FROM scoped_orders
    GROUP BY cohort, customer_unique_id

)

SELECT
    cohort,

    SUM(order_count) AS total_orders,

    COUNT(*) AS customer_identities,

    COUNT(*) FILTER (
        WHERE order_count = 1
    ) AS single_order_identities,

    COUNT(*) FILTER (
        WHERE order_count > 1
    ) AS repeat_order_identities,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE order_count > 1
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_order_share_pct,

    SUM(order_count - 1)
        AS orders_beyond_first,

    COALESCE(
        SUM(order_count) FILTER (
            WHERE order_count > 1
        ), 0
    ) AS orders_from_repeat_identities,

    ROUND(
        SUM(order_count)::NUMERIC
        / NULLIF(COUNT(*), 0),
        4
    ) AS average_orders_per_identity,

    MAX(order_count)
        AS maximum_orders_per_identity

FROM customer_order_counts

GROUP BY cohort

ORDER BY cohort;
