
-- ===========================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP: 7.4 Task 4
-- PAGE: 04 Customer and Satisfaction
-- FILE: 45_powerbi_customer_satisfaction_dashboard_validation.sql
-- DATABASE: olist_analytics
-- TYPE: READ-ONLY AUDIT
-- ===========================================================


-- ===========================================================
-- SQL-1: FULL-DATASET AND Q1 CUSTOMER / REVIEW BASELINES
-- ===========================================================

WITH scoped_orders AS (

    SELECT
        'ALL' AS cohort,
        order_id,
        customer_unique_id,
        has_review_record
    FROM analytics.fact_orders

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED',
        order_id,
        customer_unique_id,
        has_review_record
    FROM analytics.fact_orders
    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'

),

orders_by_identity AS (

    SELECT
        cohort,
        customer_unique_id,
        COUNT(*) AS orders_per_identity

    FROM scoped_orders

    GROUP BY
        cohort,
        customer_unique_id

),

identity_summary AS (

    SELECT
        cohort,

        COUNT(*) AS customer_identities,

        COUNT(*) FILTER (
            WHERE orders_per_identity > 1
        ) AS repeat_order_identities,

        COUNT(*) FILTER (
            WHERE orders_per_identity = 1
        ) AS single_order_identities

    FROM orders_by_identity

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
        'ALL' AS cohort,
        order_id,
        review_score,
        has_invalid_review_score,
        has_no_written_feedback
    FROM analytics.fact_order_reviews

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED',
        order_id,
        review_score,
        has_invalid_review_score,
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
            WHERE has_invalid_review_score IS FALSE
        ) AS valid_rating_reviews,

        COUNT(*) FILTER (
            WHERE has_no_written_feedback IS FALSE
        ) AS with_written_feedback,

        COUNT(*) FILTER (
            WHERE has_no_written_feedback IS TRUE
        ) AS without_written_feedback,

        COUNT(*) FILTER (
            WHERE has_invalid_review_score IS TRUE
        ) AS invalid_review_scores

    FROM scoped_reviews

    GROUP BY cohort

)

SELECT
    o.cohort,

    o.total_orders,

    i.customer_identities,
    i.single_order_identities,
    i.repeat_order_identities,

    ROUND(
        100.0 * i.repeat_order_identities
        / NULLIF(i.customer_identities, 0),
        2
    ) AS repeat_customer_share_pct,

    o.orders_with_reviews,

    ROUND(
        100.0 * o.orders_with_reviews
        / NULLIF(o.total_orders, 0),
        2
    ) AS review_coverage_pct,

    r.review_records,
    r.distinct_reviewed_orders,
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

    r.invalid_review_scores,

    i.customer_identities
        - i.single_order_identities
        - i.repeat_order_identities
        AS identity_partition_difference,

    o.orders_with_reviews
        - r.distinct_reviewed_orders
        AS reviewed_order_difference,

    r.review_records
        - r.with_written_feedback
        - r.without_written_feedback
        AS feedback_partition_difference

FROM order_summary AS o

JOIN identity_summary AS i
    ON o.cohort = i.cohort

JOIN review_summary AS r
    ON o.cohort = r.cohort

ORDER BY o.cohort;



-- ===========================================================
-- SQL-2: REVIEW SCORE DISTRIBUTION
-- ===========================================================

WITH scoped_scores AS (

    SELECT
        'ALL' AS cohort,
        review_score
    FROM analytics.fact_order_reviews

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED',
        review_score
    FROM analytics.fact_order_reviews
    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'

)

SELECT
    cohort,
    review_score,
    COUNT(*) AS review_records

FROM scoped_scores

GROUP BY
    cohort,
    review_score

ORDER BY
    cohort,
    review_score;



-- ===========================================================
-- SQL-3: MONTHLY CUSTOMER AND REVIEW PERFORMANCE
-- ===========================================================

-- Purchase-month cohort analysis:
-- This is NOT review creation month.

WITH monthly_identity_counts AS (

    SELECT
        date_trunc(
            'month',
            purchase_date
        )::date AS purchase_month,

        customer_unique_id,

        COUNT(*) AS orders_per_identity

    FROM analytics.fact_orders

    WHERE purchase_date IS NOT NULL

    GROUP BY
        1,
        customer_unique_id

),

monthly_customer_summary AS (

    SELECT
        purchase_month,

        COUNT(*) AS customer_identities,

        COUNT(*) FILTER (
            WHERE orders_per_identity > 1
        ) AS repeat_order_identities

    FROM monthly_identity_counts

    GROUP BY purchase_month

),

monthly_order_summary AS (

    SELECT
        date_trunc(
            'month',
            purchase_date
        )::date AS purchase_month,

        COUNT(*) AS total_orders,

        COUNT(*) FILTER (
            WHERE has_review_record IS TRUE
        ) AS orders_with_reviews

    FROM analytics.fact_orders

    WHERE purchase_date IS NOT NULL

    GROUP BY 1

),

monthly_review_summary AS (

    SELECT
        date_trunc(
            'month',
            purchase_date
        )::date AS purchase_month,

        COUNT(*) AS review_records,

        ROUND(
            AVG(review_score)::numeric,
            2
        ) AS average_review_score,

        COUNT(*) FILTER (
            WHERE review_score IN (4, 5)
        ) AS high_rating_reviews,

        COUNT(*) FILTER (
            WHERE has_no_written_feedback IS FALSE
        ) AS with_written_feedback,

        COUNT(*) FILTER (
            WHERE has_no_written_feedback IS TRUE
        ) AS without_written_feedback

    FROM analytics.fact_order_reviews

    WHERE purchase_date IS NOT NULL

    GROUP BY 1

)

SELECT
    o.purchase_month,

    o.total_orders,

    c.customer_identities,
    c.repeat_order_identities,

    ROUND(
        100.0 * c.repeat_order_identities
        / NULLIF(c.customer_identities, 0),
        2
    ) AS repeat_customer_share_pct,

    o.orders_with_reviews,

    ROUND(
        100.0 * o.orders_with_reviews
        / NULLIF(o.total_orders, 0),
        2
    ) AS review_coverage_pct,

    COALESCE(r.review_records, 0) AS review_records,

    r.average_review_score,

    COALESCE(
        r.high_rating_reviews,
        0
    ) AS high_rating_reviews,

    COALESCE(
        r.with_written_feedback,
        0
    ) AS with_written_feedback,

    COALESCE(
        r.without_written_feedback,
        0
    ) AS without_written_feedback

FROM monthly_order_summary AS o

LEFT JOIN monthly_customer_summary AS c
    ON o.purchase_month = c.purchase_month

LEFT JOIN monthly_review_summary AS r
    ON o.purchase_month = r.purchase_month

ORDER BY o.purchase_month;



-- ===========================================================
-- SQL-4: REVIEW-CREATION-DATE ROLE CHECK
-- ===========================================================

-- This independent query describes review creation,
-- not order purchase cohorts.
-- Used to document the distinction between date roles.

SELECT
    review_creation_date,
    COUNT(*) AS review_records_created,
    COUNT(DISTINCT order_id) AS distinct_reviewed_orders

FROM analytics.fact_order_reviews

WHERE review_creation_date IS NOT NULL

GROUP BY review_creation_date

ORDER BY
    review_records_created DESC,
    review_creation_date ASC

LIMIT 1;



-- ===========================================================
-- EXPECTED SQL-1 BASELINES
-- ===========================================================

-- ALL
-- Total Orders: 99,441
-- Customer Identities: 96,096
-- Repeat-Order Identities: 2,997
-- Repeat Customer Share: 3.12%
-- Orders With Reviews: 98,673
-- Review Coverage: 99.23%
-- Review Records: 99,224
-- Average Review Score: 4.09
-- High-Rating Reviews: 76,470
-- High-Rating Share: 77.07%
-- With Written Feedback: 42,697
-- Without Written Feedback: 56,527
-- Written Feedback Share: 43.03%

-- Q1_2018_DELIVERED
-- Total Orders: 20,627
-- Customer Identities: 20,211
-- Repeat-Order Identities: 400
-- Repeat Customer Share: 1.98%
-- Orders With Reviews: 20,468
-- Review Coverage: 99.23%
-- Review Records: 20,630
-- Average Review Score: 3.94
-- High-Rating Reviews: 14,994
-- High-Rating Share: 72.68%
-- With Written Feedback: 8,640
-- Without Written Feedback: 11,990
-- Written Feedback Share: 41.88%

-- SQL-1 DIFFERENCES:
-- Identity Partition: 0
-- Reviewed Order Difference: 0
-- Written Feedback Partition: 0
-- Invalid Review Scores: 0


-- ===========================================================
-- EXPECTED SQL-2 BASELINES
-- ===========================================================

-- FULL REVIEW SCORE DISTRIBUTION
-- Score 1: 11,424
-- Score 2: 3,151
-- Score 3: 8,179
-- Score 4: 19,142
-- Score 5: 57,328
-- Total: 99,224

-- Q1 Score 1-5 counts:
-- Score 1: 2,981
-- Score 2: 740
-- Score 3: 1,915
-- Score 4: 3,974
-- Score 5: 11,020
-- Total: 20,630

-- ===========================================================
-- SQL-3 AND SQL-4 ACCEPTANCE
-- ===========================================================

-- SQL-3:
-- Compare monthly review counts, score averages,
-- feedback counts and monthly repeat identity shares
-- against the four Power BI visuals.

-- Review records sum across months: 99,224
-- Written-feedback records sum: 42,697
-- No-written-feedback records sum: 56,527
-- Orders sum across months: 99,441

-- Do NOT sum monthly distinct customer identities
-- to reproduce full-period distinct identities.
-- A customer may purchase in multiple months.

-- SQL-4:
-- Review-creation-day activity must not be confused
-- with purchase-cohort review coverage.
-- Earlier review-date audit identified 463 records
-- on its peak review creation date.

-- All queries are read-only.
-- No PostgreSQL records are changed.

-- ===========================================================
-- END OF FILE
-- ===========================================================
