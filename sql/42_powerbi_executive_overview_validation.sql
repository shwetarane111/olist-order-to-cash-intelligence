
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP: 7.4 Task 1
-- PAGE: 01 Executive Overview
-- FILE: 42_powerbi_executive_overview_validation.sql
-- DATABASE: olist_analytics
-- PURPOSE: Executive Overview SQL validation
-- TYPE: Read-only
-- =====================================================

-- EXPECTED FULL-DATASET BASELINES
--
-- Total Orders: 99,441
-- Delivered Orders: 96,478
-- On-Time Delivery Rate: 93.23%
-- Recorded Item + Freight: R$15,843,553.24
-- Recorded Payments: R$16,008,872.12
-- Financial Mismatch Rate: 0.58%

-- EXPECTED Q1 2018 DELIVERED COHORT
--
-- Delivered Orders: 20,627
-- On-Time Delivery Rate: 87.12%
-- Recorded Item + Freight: R$3,164,654.11
-- Recorded Payments: R$3,165,795.74
-- Financial Mismatch Rate: 0.62%


WITH scoped_orders AS (

    SELECT
        'ALL' AS cohort,
        order_status,
        is_delivery_evaluable,
        is_delivered_on_time,
        reconciliation_status
    FROM analytics.fact_orders

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED' AS cohort,
        order_status,
        is_delivery_evaluable,
        is_delivered_on_time,
        reconciliation_status
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
            WHERE order_status = 'delivered'
        ) AS delivered_orders,

        COUNT(*) FILTER (
            WHERE is_delivery_evaluable
        ) AS evaluable_deliveries,

        COUNT(*) FILTER (
            WHERE is_delivered_on_time
        ) AS on_time_deliveries,

        COUNT(*) FILTER (
            WHERE reconciliation_status = 'MISMATCH'
        ) AS mismatched_orders,

        COUNT(*) FILTER (
            WHERE reconciliation_status
                IN ('MATCH', 'MISMATCH')
        ) AS comparable_orders

    FROM scoped_orders

    GROUP BY cohort

),

scoped_items AS (

    SELECT
        'ALL' AS cohort,
        item_total_amount
    FROM analytics.fact_order_items

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED' AS cohort,
        item_total_amount
    FROM analytics.fact_order_items
    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'

),

item_summary AS (

    SELECT
        cohort,

        ROUND(
            SUM(item_total_amount),
            2
        ) AS recorded_item_freight

    FROM scoped_items

    GROUP BY cohort

),

scoped_payments AS (

    SELECT
        'ALL' AS cohort,
        payment_amount
    FROM analytics.fact_payments

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED' AS cohort,
        payment_amount
    FROM analytics.fact_payments
    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'

),

payment_summary AS (

    SELECT
        cohort,

        ROUND(
            SUM(payment_amount),
            2
        ) AS recorded_payments

    FROM scoped_payments

    GROUP BY cohort

)

SELECT
    o.cohort,

    o.total_orders,

    o.delivered_orders,

    ROUND(
        100.0 * o.on_time_deliveries
        / NULLIF(o.evaluable_deliveries, 0),
        2
    ) AS on_time_delivery_pct,

    i.recorded_item_freight,

    p.recorded_payments,

    ROUND(
        100.0 * o.mismatched_orders
        / NULLIF(o.comparable_orders, 0),
        2
    ) AS financial_mismatch_pct

FROM order_summary AS o

JOIN item_summary AS i
    USING (cohort)

JOIN payment_summary AS p
    USING (cohort)

ORDER BY o.cohort;


-- =====================================================
-- ACCEPTANCE CRITERIA
-- =====================================================

-- Expected exactly 2 rows:
-- ALL
-- Q1_2018_DELIVERED
--
-- FULL DATASET
-- Total Orders: 99,441
-- Delivered Orders: 96,478
-- On-Time Delivery: 93.23%
-- Item + Freight: 15,843,553.24
-- Recorded Payments: 16,008,872.12
-- Financial Mismatch Rate: 0.58%
--
-- Q1 DELIVERED
-- Total Orders: 20,627
-- Delivered Orders: 20,627
-- On-Time Delivery: 87.12%
-- Item + Freight: 3,164,654.11
-- Recorded Payments: 3,165,795.74
-- Financial Mismatch Rate: 0.62%
--
-- All Power BI values must match PostgreSQL.
-- Counts: exact
-- Currency: two decimal places
-- Percentages: two decimal places

-- =====================================================
-- END OF FILE
-- =====================================================
