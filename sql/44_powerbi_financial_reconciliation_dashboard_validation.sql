
-- ===========================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- FILE: 44_powerbi_financial_reconciliation_dashboard_validation.sql
-- STEP: 7.4 Task 3
-- PAGE: 03 Financial Reconciliation
-- DATABASE: olist_analytics
-- TYPE: READ-ONLY AUDIT
-- ===========================================================


-- ===========================================================
-- SQL-1: FULL-DATA AND Q1 FINANCIAL RECONCILIATION
-- ===========================================================

WITH scoped_orders AS (

    SELECT
        'ALL' AS cohort,
        reconciliation_status,
        item_plus_freight_total,
        recorded_payment_total,
        payment_difference,
        absolute_payment_difference
    FROM analytics.fact_orders

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED' AS cohort,
        reconciliation_status,
        item_plus_freight_total,
        recorded_payment_total,
        payment_difference,
        absolute_payment_difference
    FROM analytics.fact_orders
    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'

),

financial_summary AS (

    SELECT
        cohort,

        COUNT(*) AS total_orders,

        COUNT(*) FILTER (
            WHERE reconciliation_status IN ('MATCH', 'MISMATCH')
        ) AS comparable_orders,

        COUNT(*) FILTER (
            WHERE reconciliation_status = 'MATCH'
        ) AS matched_orders,

        COUNT(*) FILTER (
            WHERE reconciliation_status = 'MISMATCH'
        ) AS mismatched_orders,

        COUNT(*) FILTER (
            WHERE reconciliation_status NOT IN ('MATCH', 'MISMATCH')
        ) AS financial_coverage_gaps,

        COUNT(*) FILTER (
            WHERE reconciliation_status = 'MISSING_ITEMS'
        ) AS missing_items,

        COUNT(*) FILTER (
            WHERE reconciliation_status = 'MISSING_PAYMENTS'
        ) AS missing_payments,

        COUNT(*) FILTER (
            WHERE reconciliation_status = 'MISSING_BOTH'
        ) AS missing_both,

        ROUND(
            (
                SUM(item_plus_freight_total) FILTER (
                    WHERE reconciliation_status IN ('MATCH', 'MISMATCH')
                )
            )::numeric,
            2
        ) AS comparable_item_freight,

        ROUND(
            (
                SUM(recorded_payment_total) FILTER (
                    WHERE reconciliation_status IN ('MATCH', 'MISMATCH')
                )
            )::numeric,
            2
        ) AS comparable_recorded_payments,

        ROUND(
            (
                SUM(payment_difference) FILTER (
                    WHERE reconciliation_status IN ('MATCH', 'MISMATCH')
                )
            )::numeric,
            2
        ) AS net_payment_difference,

        ROUND(
            (
                SUM(absolute_payment_difference) FILTER (
                    WHERE reconciliation_status IN ('MATCH', 'MISMATCH')
                )
            )::numeric,
            2
        ) AS absolute_financial_discrepancy

    FROM scoped_orders
    GROUP BY cohort

)

SELECT
    cohort,
    total_orders,
    comparable_orders,
    matched_orders,
    mismatched_orders,
    financial_coverage_gaps,
    missing_items,
    missing_payments,
    missing_both,

    ROUND(
        100.0 * matched_orders
        / NULLIF(comparable_orders, 0),
        2
    ) AS match_rate_pct,

    ROUND(
        100.0 * mismatched_orders
        / NULLIF(comparable_orders, 0),
        2
    ) AS mismatch_rate_pct,

    comparable_item_freight,
    comparable_recorded_payments,
    net_payment_difference,
    absolute_financial_discrepancy,

    total_orders
        - comparable_orders
        - financial_coverage_gaps
        AS order_partition_difference,

    comparable_orders
        - matched_orders
        - mismatched_orders
        AS comparable_partition_difference,

    ROUND(
        comparable_recorded_payments
        - comparable_item_freight
        - net_payment_difference,
        2
    ) AS signed_amount_difference,

    CASE
        WHEN absolute_financial_discrepancy
            >= ABS(net_payment_difference)
        THEN 'PASS'
        ELSE 'FAIL'
    END AS absolute_vs_net_check

FROM financial_summary
ORDER BY cohort;



-- ===========================================================
-- SQL-2: PURCHASE-MONTH FINANCIAL PERFORMANCE
-- ===========================================================

-- Monthly grouping uses order Purchase Date.
-- This is not a payment settlement date.

WITH monthly_orders AS (

    SELECT
        date_trunc('month', purchase_date)::date
            AS purchase_month,

        reconciliation_status,
        item_plus_freight_total,
        recorded_payment_total,
        payment_difference,
        absolute_payment_difference

    FROM analytics.fact_orders

    WHERE purchase_date IS NOT NULL

),

monthly_summary AS (

    SELECT
        purchase_month,

        COUNT(*) AS total_orders,

        COUNT(*) FILTER (
            WHERE reconciliation_status IN ('MATCH', 'MISMATCH')
        ) AS comparable_orders,

        COUNT(*) FILTER (
            WHERE reconciliation_status = 'MATCH'
        ) AS matched_orders,

        COUNT(*) FILTER (
            WHERE reconciliation_status = 'MISMATCH'
        ) AS mismatched_orders,

        COUNT(*) FILTER (
            WHERE reconciliation_status NOT IN ('MATCH', 'MISMATCH')
        ) AS coverage_gaps,

        ROUND(
            (
                SUM(item_plus_freight_total) FILTER (
                    WHERE reconciliation_status IN ('MATCH', 'MISMATCH')
                )
            )::numeric,
            2
        ) AS comparable_item_freight,

        ROUND(
            (
                SUM(recorded_payment_total) FILTER (
                    WHERE reconciliation_status IN ('MATCH', 'MISMATCH')
                )
            )::numeric,
            2
        ) AS comparable_payments,

        ROUND(
            (
                SUM(payment_difference) FILTER (
                    WHERE reconciliation_status IN ('MATCH', 'MISMATCH')
                )
            )::numeric,
            2
        ) AS net_payment_difference,

        ROUND(
            (
                SUM(absolute_payment_difference) FILTER (
                    WHERE reconciliation_status IN ('MATCH', 'MISMATCH')
                )
            )::numeric,
            2
        ) AS absolute_financial_discrepancy

    FROM monthly_orders
    GROUP BY purchase_month

)

SELECT
    purchase_month,
    total_orders,
    comparable_orders,
    matched_orders,
    mismatched_orders,
    coverage_gaps,

    ROUND(
        100.0 * matched_orders
        / NULLIF(comparable_orders, 0),
        2
    ) AS match_rate_pct,

    comparable_item_freight,
    comparable_payments,
    net_payment_difference,
    absolute_financial_discrepancy

FROM monthly_summary
ORDER BY purchase_month;



-- ===========================================================
-- SQL-3: RECONCILIATION STATUS POPULATIONS
-- ===========================================================

WITH status_rows AS (

    SELECT
        'ALL' AS cohort,
        reconciliation_status
    FROM analytics.fact_orders

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED',
        reconciliation_status
    FROM analytics.fact_orders
    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'

)

SELECT
    cohort,
    reconciliation_status,
    COUNT(*) AS orders

FROM status_rows

GROUP BY cohort, reconciliation_status

ORDER BY
    cohort,
    orders DESC,
    reconciliation_status;


-- ===========================================================
-- EXPECTED SQL-1 BASELINES
-- ===========================================================

-- ALL:
-- Total Orders: 99,441
-- Comparable: 98,665
-- MATCH: 98,089
-- MISMATCH: 576
-- Coverage Gaps: 776
-- MISSING_ITEMS: 775
-- MISSING_PAYMENTS: 1
-- MISSING_BOTH: 0
-- Match Rate: 99.42%
-- Mismatch Rate: 0.58%
-- Comparable Item + Freight: 15,843,409.78
-- Comparable Payments: 15,846,280.17
-- Net Difference: +2,870.39
-- Absolute Discrepancy: 3,271.95

-- Q1_2018_DELIVERED:
-- Total Orders: 20,627
-- Comparable: 20,627
-- MATCH: 20,499
-- MISMATCH: 128
-- Coverage Gaps: 0
-- Match Rate: 99.38%
-- Mismatch Rate: 0.62%
-- Comparable Item + Freight: 3,164,654.11
-- Comparable Payments: 3,165,795.74
-- Net Difference: +1,141.63
-- Absolute Discrepancy: 1,142.37

-- EXPECTED SQL-1 QUALITY CHECKS:
-- Order partition difference: 0
-- Comparable partition difference: 0
-- Signed amount difference: 0.00
-- Absolute vs net check: PASS


-- ===========================================================
-- EXPECTED SQL-2 AND SQL-3 VALIDATION
-- ===========================================================

-- SQL-2:
-- Compare purchase-month counts, match rates,
-- signed net differences and absolute discrepancies
-- with Power BI chart values.

-- Across all purchase months:
-- Comparable Orders = 98,665
-- Matched Orders = 98,089
-- Mismatched Orders = 576
-- Net Difference = +2,870.39
-- Absolute Discrepancy = 3,271.95

-- SQL-3 ALL exception categories:
-- MISMATCH = 576
-- MISSING_ITEMS = 775
-- MISSING_PAYMENTS = 1

-- SQL-3 Q1 DELIVERED:
-- MATCH = 20,499
-- MISMATCH = 128
-- No missing financial records.

-- ===========================================================
-- END OF FILE
-- ===========================================================
