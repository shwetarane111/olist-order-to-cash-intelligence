
-- =====================================================
-- ORDER-TO-CASH INTELLIGENCE PLATFORM
-- STEP 7.3 - TASK 10
-- MISSING KPI RECONCILIATION: PART 1
-- =====================================================

WITH scoped_orders AS (

    SELECT
        'ALL' AS cohort,
        order_status,
        has_item_records,
        item_plus_freight_total,
        reconciliation_status,
        is_delivery_evaluable,
        is_delivered_late,
        order_delivered_customer_date
    FROM analytics.fact_orders

    UNION ALL

    SELECT
        'Q1_2018_ALL_STATUSES',
        order_status,
        has_item_records,
        item_plus_freight_total,
        reconciliation_status,
        is_delivery_evaluable,
        is_delivered_late,
        order_delivered_customer_date
    FROM analytics.fact_orders
    WHERE purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED',
        order_status,
        has_item_records,
        item_plus_freight_total,
        reconciliation_status,
        is_delivery_evaluable,
        is_delivered_late,
        order_delivered_customer_date
    FROM analytics.fact_orders
    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
),

order_summary AS (

    SELECT
        cohort,

        COUNT(*) AS total_orders,

        COUNT(*) FILTER (
            WHERE has_item_records IS TRUE
        ) AS orders_with_items,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
        ) AS delivered_orders,

        COUNT(*) FILTER (
            WHERE order_status = 'canceled'
        ) AS canceled_orders,

        COUNT(*) FILTER (
            WHERE reconciliation_status = 'MISMATCH'
        ) AS mismatched_orders,

        COUNT(*) FILTER (
            WHERE reconciliation_status
                  IN ('MATCH', 'MISMATCH')
        ) AS comparable_orders,

        COUNT(*) FILTER (
            WHERE is_delivery_evaluable IS TRUE
        ) AS evaluable_deliveries,

        COUNT(*) FILTER (
            WHERE is_delivered_late IS TRUE
        ) AS late_deliveries,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NULL
        ) AS delivered_missing_actual_date,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND has_item_records IS TRUE
        ) AS delivered_item_backed_orders,

        SUM(item_plus_freight_total) FILTER (
            WHERE order_status = 'delivered'
              AND has_item_records IS TRUE
        ) AS delivered_item_freight_total

    FROM scoped_orders
    GROUP BY cohort
),

scoped_reviews AS (

    SELECT
        'ALL' AS cohort,
        has_no_written_feedback
    FROM analytics.fact_order_reviews

    UNION ALL

    SELECT
        'Q1_2018_ALL_STATUSES',
        has_no_written_feedback
    FROM analytics.fact_order_reviews
    WHERE purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED',
        has_no_written_feedback
    FROM analytics.fact_order_reviews
    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
),

review_summary AS (

    SELECT
        cohort,
        COUNT(*) AS review_records,

        COUNT(*) FILTER (
            WHERE has_no_written_feedback IS FALSE
        ) AS reviews_with_written_feedback

    FROM scoped_reviews
    GROUP BY cohort
)

SELECT
    o.cohort,
    o.total_orders,
    o.orders_with_items,
    o.delivered_orders,
    o.canceled_orders,

    ROUND(
        100.0 * o.delivered_orders
        / NULLIF(o.total_orders, 0), 2
    ) AS delivered_order_share_pct,

    ROUND(
        100.0 * o.canceled_orders
        / NULLIF(o.total_orders, 0), 2
    ) AS canceled_order_share_pct,

    ROUND(
        o.delivered_item_freight_total
        / NULLIF(o.delivered_item_backed_orders, 0),
        2
    ) AS delivered_order_aov,

    ROUND(
        100.0 * o.mismatched_orders
        / NULLIF(o.comparable_orders, 0), 2
    ) AS financial_mismatch_rate_pct,

    ROUND(
        100.0 * o.evaluable_deliveries
        / NULLIF(o.delivered_orders, 0), 2
    ) AS delivery_evaluation_coverage_pct,

    ROUND(
        100.0 * o.late_deliveries
        / NULLIF(o.evaluable_deliveries, 0), 2
    ) AS late_delivery_rate_pct,

    o.delivered_missing_actual_date,

    ROUND(
        100.0 * r.reviews_with_written_feedback
        / NULLIF(r.review_records, 0), 2
    ) AS written_feedback_availability_pct

FROM order_summary AS o
JOIN review_summary AS r
    ON o.cohort = r.cohort
ORDER BY o.cohort;
