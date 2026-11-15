
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 7.3 - TASK 5
-- FILE: 35_powerbi_payment_kpi_reconciliation.sql
-- =====================================================

WITH scoped_payments AS (

    SELECT
        'ALL' AS cohort,
        order_id,
        payment_amount,
        is_zero_value_payment,
        is_zero_installment,
        is_undefined_payment_method,
        has_payment_quality_flag
    FROM analytics.fact_payments

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED' AS cohort,
        order_id,
        payment_amount,
        is_zero_value_payment,
        is_zero_installment,
        is_undefined_payment_method,
        has_payment_quality_flag
    FROM analytics.fact_payments
    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'

),

payments_per_order AS (

    SELECT
        cohort,
        order_id,
        COUNT(*) AS entries_per_order

    FROM scoped_payments

    GROUP BY cohort, order_id

),

order_summary AS (

    SELECT
        cohort,

        COUNT(*) AS orders_with_payments,

        COUNT(*) FILTER (
            WHERE entries_per_order > 1
        ) AS multiple_entry_orders,

        MAX(entries_per_order)
            AS maximum_entries_per_order

    FROM payments_per_order

    GROUP BY cohort

),

payment_summary AS (

    SELECT
        cohort,

        COUNT(*) AS payment_entries,

        SUM(payment_amount)
            AS recorded_payment_total,

        COUNT(*) FILTER (
            WHERE has_payment_quality_flag
        ) AS flagged_entries,

        COUNT(DISTINCT order_id) FILTER (
            WHERE has_payment_quality_flag
        ) AS orders_with_flagged_payments,

        COUNT(*) FILTER (
            WHERE is_zero_value_payment
        ) AS zero_value_entries,

        COUNT(*) FILTER (
            WHERE is_zero_installment
        ) AS zero_installment_entries,

        COUNT(*) FILTER (
            WHERE is_undefined_payment_method
        ) AS undefined_method_entries,

        COUNT(*) FILTER (
            WHERE has_payment_quality_flag
                IS DISTINCT FROM (
                    is_zero_value_payment
                    OR is_zero_installment
                    OR is_undefined_payment_method
                )
        ) AS inconsistent_quality_flags

    FROM scoped_payments

    GROUP BY cohort

)

SELECT
    p.cohort,

    p.payment_entries,
    o.orders_with_payments,
    o.multiple_entry_orders,

    ROUND(
        100.0 * o.multiple_entry_orders
        / NULLIF(o.orders_with_payments, 0),
        2
    ) AS multiple_entry_order_share_pct,

    p.payment_entries - o.orders_with_payments
        AS extra_entries_beyond_first,

    o.maximum_entries_per_order,

    p.flagged_entries,
    p.orders_with_flagged_payments,

    ROUND(
        100.0 * p.flagged_entries
        / NULLIF(p.payment_entries, 0),
        4
    ) AS flagged_entry_rate_pct,

    p.zero_value_entries,
    p.zero_installment_entries,
    p.undefined_method_entries,

    p.recorded_payment_total,
    p.inconsistent_quality_flags

FROM payment_summary AS p

JOIN order_summary AS o
    ON p.cohort = o.cohort

ORDER BY p.cohort;
