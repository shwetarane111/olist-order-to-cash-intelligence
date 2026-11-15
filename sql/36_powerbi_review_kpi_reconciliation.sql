
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 7.3 - TASK 6
-- FILE: 36_powerbi_review_kpi_reconciliation.sql
-- PURPOSE: Review KPI SQL-to-DAX reconciliation
-- =====================================================

WITH scoped_orders AS (

    SELECT
        'ALL' AS cohort,
        order_id,
        has_review_record
    FROM analytics.fact_orders

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED' AS cohort,
        order_id,
        has_review_record
    FROM analytics.fact_orders
    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'

),

scoped_reviews AS (

    SELECT
        'ALL' AS cohort,
        order_id,
        review_score,
        has_invalid_review_score,
        has_no_written_feedback,
        is_missing_review_title,
        is_missing_review_message
    FROM analytics.fact_order_reviews

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED' AS cohort,
        order_id,
        review_score,
        has_invalid_review_score,
        has_no_written_feedback,
        is_missing_review_title,
        is_missing_review_message
    FROM analytics.fact_order_reviews
    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'

),

order_summary AS (

    SELECT
        cohort,
        COUNT(*) AS total_orders,

        COUNT(*) FILTER (
            WHERE has_review_record
        ) AS orders_with_reviews

    FROM scoped_orders

    GROUP BY cohort

),

review_summary AS (

    SELECT
        cohort,

        COUNT(*) AS review_records,

        COUNT(DISTINCT order_id)
            AS distinct_reviewed_orders,

        ROUND(
            AVG(review_score)::NUMERIC,
            2
        ) AS average_review_score,

        COUNT(*) FILTER (
            WHERE review_score IN (4, 5)
        ) AS high_rating_reviews,

        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE review_score IN (4, 5)
            )
            / NULLIF(
                COUNT(*) FILTER (
                    WHERE NOT has_invalid_review_score
                ), 0
            ),
            2
        ) AS high_rating_share_pct,

        COUNT(*) FILTER (
            WHERE has_no_written_feedback
        ) AS without_written_feedback,

        COUNT(*) FILTER (
            WHERE NOT has_no_written_feedback
        ) AS with_written_feedback,

        COUNT(*) FILTER (
            WHERE is_missing_review_title
        ) AS missing_titles,

        COUNT(*) FILTER (
            WHERE is_missing_review_message
        ) AS missing_messages,

        COUNT(*) FILTER (
            WHERE has_invalid_review_score
        ) AS invalid_scores

    FROM scoped_reviews

    GROUP BY cohort

),

reviews_per_order AS (

    SELECT
        cohort,
        order_id,
        COUNT(*) AS reviews_per_order

    FROM scoped_reviews

    GROUP BY cohort, order_id

),

multiple_review_summary AS (

    SELECT
        cohort,

        COUNT(*) FILTER (
            WHERE reviews_per_order > 1
        ) AS orders_with_multiple_reviews,

        SUM(reviews_per_order - 1)
            AS additional_review_records,

        MAX(reviews_per_order)
            AS maximum_reviews_per_order

    FROM reviews_per_order

    GROUP BY cohort

)

SELECT
    o.cohort,

    o.total_orders,

    r.review_records,
    r.distinct_reviewed_orders,

    o.orders_with_reviews,

    ROUND(
        100.0 * o.orders_with_reviews
        / NULLIF(o.total_orders, 0),
        2
    ) AS review_coverage_pct,

    r.average_review_score,

    r.high_rating_reviews,
    r.high_rating_share_pct,

    r.without_written_feedback,
    r.with_written_feedback,

    r.missing_titles,
    r.missing_messages,

    m.orders_with_multiple_reviews,
    m.additional_review_records,
    m.maximum_reviews_per_order,

    r.invalid_scores,

    o.orders_with_reviews
        - r.distinct_reviewed_orders
        AS reviewed_order_difference

FROM order_summary AS o

JOIN review_summary AS r
    ON o.cohort = r.cohort

JOIN multiple_review_summary AS m
    ON o.cohort = m.cohort

ORDER BY o.cohort;
