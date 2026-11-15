
-- ===============================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP: 7.4 Task 2
-- PAGE: 02 Order Fulfillment
-- FILE: 43_powerbi_order_fulfillment_dashboard_validation.sql
-- DATABASE: olist_analytics
-- PURPOSE: Independent PostgreSQL fulfillment validation
-- TYPE: Read-only
-- ===============================================================


-- ===============================================================
-- SQL-1: FULL-DATASET AND Q1 2018 FULFILLMENT VALIDATION
-- ===============================================================

-- EXPECTED FULL-DATASET BASELINES
--
-- Delivered Orders: 96,478
-- Evaluable Delivered Orders: 96,470
-- On-Time Deliveries: 89,936
-- Late Deliveries: 6,534
-- Missing Actual Delivery Date: 8
-- Negative Purchase-to-Delivery Durations: 0
--
-- Evaluation Coverage: 99.99%
-- On-Time Delivery Rate: 93.23%
-- Late Delivery Rate: 6.77%
--
-- Average Purchase-to-Delivery Days: 12.56
-- Average Signed Delivery Variance Days: -11.88


-- EXPECTED Q1 2018 DELIVERED-COHORT BASELINES
--
-- Delivered Orders: 20,627
-- Evaluable Delivered Orders: 20,627
-- On-Time Deliveries: 17,970
-- Late Deliveries: 2,657
-- Missing Actual Delivery Date: 0
--
-- Evaluation Coverage: 100.00%
-- On-Time Delivery Rate: 87.12%
-- Late Delivery Rate: 12.88%
--
-- Average Purchase-to-Delivery Days: 15.74
-- Average Signed Delivery Variance Days: -9.25


WITH cohort_orders AS (

    SELECT
        'ALL' AS cohort,
        o.*
    FROM analytics.fact_orders AS o

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED' AS cohort,
        o.*
    FROM analytics.fact_orders AS o
    WHERE o.order_status = 'delivered'
      AND o.purchase_date >= DATE '2018-01-01'
      AND o.purchase_date < DATE '2018-04-01'

),

aggregates AS (

    SELECT
        cohort,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
        ) AS delivered_orders,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND is_delivery_evaluable IS TRUE
        ) AS evaluable_delivered_orders,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND is_delivered_on_time IS TRUE
        ) AS on_time_deliveries,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND is_delivered_late IS TRUE
        ) AS late_deliveries,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NULL
        ) AS delivered_missing_actual_date,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND has_negative_purchase_to_delivery_duration
                  IS TRUE
        ) AS negative_elapsed_duration_orders,

        ROUND(
            (
                AVG(purchase_to_delivery_days) FILTER (
                    WHERE order_status = 'delivered'
                      AND is_delivery_evaluable IS TRUE
                      AND has_negative_purchase_to_delivery_duration
                          IS NOT TRUE
                      AND purchase_to_delivery_days IS NOT NULL
                )
            )::numeric,
            2
        ) AS avg_purchase_to_delivery_days,

        ROUND(
            (
                AVG(delivery_variance_days) FILTER (
                    WHERE order_status = 'delivered'
                      AND is_delivery_evaluable IS TRUE
                      AND delivery_variance_days IS NOT NULL
                )
            )::numeric,
            2
        ) AS avg_signed_delivery_variance_days

    FROM cohort_orders
    GROUP BY cohort

)

SELECT
    cohort,
    delivered_orders,
    evaluable_delivered_orders,
    on_time_deliveries,
    late_deliveries,
    delivered_missing_actual_date,
    negative_elapsed_duration_orders,

    ROUND(
        100.0 * evaluable_delivered_orders
        / NULLIF(delivered_orders, 0),
        2
    ) AS evaluation_coverage_pct,

    ROUND(
        100.0 * on_time_deliveries
        / NULLIF(evaluable_delivered_orders, 0),
        2
    ) AS on_time_rate_pct,

    ROUND(
        100.0 * late_deliveries
        / NULLIF(evaluable_delivered_orders, 0),
        2
    ) AS late_rate_pct,

    avg_purchase_to_delivery_days,

    avg_signed_delivery_variance_days,

    delivered_orders
        - evaluable_delivered_orders
        - delivered_missing_actual_date
        AS delivery_coverage_difference,

    evaluable_delivered_orders
        - on_time_deliveries
        - late_deliveries
        AS delivery_classification_difference

FROM aggregates
ORDER BY cohort;



-- ===============================================================
-- SQL-2: LATE-DELIVERY SEVERITY BUCKETS
-- ===============================================================

-- Calendar-day delivery variance:
-- Actual delivery date minus estimated delivery date.
--
-- Use only delivered, evaluable, late records.
--
-- EXPECTED ALL:
-- 1-3 days late:  1,870
-- 4-7 days late:  1,802
-- 8-14 days late: 1,478
-- 15+ days late:  1,384
-- Total:          6,534
--
-- EXPECTED Q1 DELIVERED:
-- 1-3 days late:  628
-- 4-7 days late:  708
-- 8-14 days late: 641
-- 15+ days late:  680
-- Total across bands: 2,657


WITH late_orders AS (

    SELECT
        'ALL' AS cohort,
        delivery_variance_days
    FROM analytics.fact_orders
    WHERE order_status = 'delivered'
      AND is_delivery_evaluable IS TRUE
      AND is_delivered_late IS TRUE

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED' AS cohort,
        delivery_variance_days
    FROM analytics.fact_orders
    WHERE order_status = 'delivered'
      AND is_delivery_evaluable IS TRUE
      AND is_delivered_late IS TRUE
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'

),

labeled AS (

    SELECT
        cohort,

        CASE
            WHEN delivery_variance_days BETWEEN 1 AND 3
                THEN '1-3 days late'

            WHEN delivery_variance_days BETWEEN 4 AND 7
                THEN '4-7 days late'

            WHEN delivery_variance_days BETWEEN 8 AND 14
                THEN '8-14 days late'

            WHEN delivery_variance_days >= 15
                THEN '15+ days late'

            ELSE 'INVALID_LATE_VARIANCE'

        END AS late_delivery_band

    FROM late_orders

)

SELECT
    cohort,
    late_delivery_band,
    COUNT(*) AS late_orders

FROM labeled

GROUP BY
    cohort,
    late_delivery_band

ORDER BY
    cohort,

    CASE late_delivery_band
        WHEN '1-3 days late' THEN 1
        WHEN '4-7 days late' THEN 2
        WHEN '8-14 days late' THEN 3
        WHEN '15+ days late' THEN 4
        ELSE 5
    END;



-- ===============================================================
-- SQL-3: PURCHASE-MONTH FULFILLMENT VALIDATION
-- ===============================================================

-- Monthly grouping uses the associated order purchase date.
-- It does NOT represent the month of delivery.
--
-- Compare monthly SQL results against:
-- 1. On-Time Delivery Rate by Purchase Month
-- 2. On-Time vs Late Deliveries by Purchase Month
-- 3. Average Purchase-to-Delivery Days by Month
--
-- A month with no eligible deliveries may have NULL
-- rate/average values. Do not replace these with zero.


WITH month_level AS (

    SELECT
        date_trunc(
            'month',
            purchase_date
        )::date AS purchase_month,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
        ) AS delivered_orders,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND is_delivery_evaluable IS TRUE
        ) AS evaluable_orders,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND is_delivered_on_time IS TRUE
        ) AS on_time_deliveries,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND is_delivered_late IS TRUE
        ) AS late_deliveries,

        ROUND(
            (
                AVG(purchase_to_delivery_days) FILTER (
                    WHERE order_status = 'delivered'
                      AND is_delivery_evaluable IS TRUE
                      AND has_negative_purchase_to_delivery_duration
                          IS NOT TRUE
                      AND purchase_to_delivery_days IS NOT NULL
                )
            )::numeric,
            2
        ) AS avg_purchase_to_delivery_days

    FROM analytics.fact_orders

    WHERE purchase_date IS NOT NULL

    GROUP BY 1

)

SELECT
    purchase_month,
    delivered_orders,
    evaluable_orders,
    on_time_deliveries,
    late_deliveries,

    ROUND(
        100.0 * on_time_deliveries
        / NULLIF(evaluable_orders, 0),
        2
    ) AS on_time_rate_pct,

    avg_purchase_to_delivery_days

FROM month_level

ORDER BY purchase_month;


-- ===============================================================
-- VALIDATION REQUIREMENTS
-- ===============================================================

-- SQL-1:
-- 2 cohorts: ALL and Q1_2018_DELIVERED
-- Delivery coverage differences: 0
-- Delivery classification differences: 0
-- All counts and averages match Power BI.

-- SQL-2:
-- Full-dataset band total: 6,534
-- Q1 delivered band total: 2,657
-- No INVALID_LATE_VARIANCE records.

-- SQL-3:
-- Monthly values agree with Power BI chart tooltips.
-- Monthly counts reconcile with the full fact population.

-- All queries are read-only.
-- No source records are changed.

-- ===============================================================
-- END OF FILE
-- ===============================================================
