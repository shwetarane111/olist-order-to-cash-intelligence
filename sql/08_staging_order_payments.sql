
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 5.1 - TASK 3
-- MODEL: staging.stg_order_payments
-- =====================================================

-- CHECK A: Validate source payment records

SELECT
    COUNT(*) AS total_payment_rows,

    COUNT(
        DISTINCT (order_id, payment_sequential)
    ) AS unique_payment_keys,

    COUNT(*) FILTER (
        WHERE order_id IS NULL
           OR BTRIM(order_id) = ''
           OR payment_sequential IS NULL
    ) AS missing_key_rows,

    COUNT(*) FILTER (
        WHERE payment_value IS NULL
    ) AS missing_payment_amounts,

    COUNT(*) FILTER (
        WHERE payment_value < 0
    ) AS negative_payment_amounts,

    COUNT(*) FILTER (
        WHERE payment_value = 0
    ) AS zero_value_payments,

    COUNT(*) FILTER (
        WHERE payment_installments = 0
    ) AS zero_installment_payments,

    COUNT(*) FILTER (
        WHERE LOWER(BTRIM(payment_type)) = 'not_defined'
    ) AS undefined_payment_methods

FROM raw.order_payments;


-- =====================================================
-- CREATE THE ORDER PAYMENTS STAGING VIEW
-- =====================================================

CREATE OR REPLACE VIEW staging.stg_order_payments AS

WITH standardized AS (

    SELECT
        -- Preserve logical payment key
        p.order_id,
        p.payment_sequential,

        -- Standardize the payment method
        NULLIF(
            LOWER(BTRIM(p.payment_type)),
            ''
        ) AS payment_method,

        -- Preserve installment and monetary values
        p.payment_installments,

        p.payment_value AS payment_amount

    FROM raw.order_payments AS p

),

quality_flags AS (

    SELECT
        s.*,

        -- Flag zero-value payment records
        COALESCE(
            s.payment_amount = 0,
            FALSE
        ) AS is_zero_value_payment,

        -- Flag zero-installment records
        COALESCE(
            s.payment_installments = 0,
            FALSE
        ) AS is_zero_installment,

        -- Flag undefined payment methods
        COALESCE(
            s.payment_method = 'not_defined',
            FALSE
        ) AS is_undefined_payment_method

    FROM standardized AS s

)

SELECT
    order_id,
    payment_sequential,
    payment_method,
    payment_installments,
    payment_amount,

    is_zero_value_payment,
    is_zero_installment,
    is_undefined_payment_method,

    (
        is_zero_value_payment
        OR is_zero_installment
        OR is_undefined_payment_method
    ) AS has_payment_quality_flag

FROM quality_flags;


-- =====================================================
-- CHECK C: Validate payment STAGING model
-- =====================================================

SELECT
    COUNT(*) AS total_payment_rows,

    COUNT(DISTINCT order_id)
        AS distinct_orders,

    COUNT(
        DISTINCT (order_id, payment_sequential)
    ) AS unique_payment_keys,

    COUNT(*) FILTER (
        WHERE is_zero_value_payment
    ) AS zero_value_payments,

    COUNT(*) FILTER (
        WHERE is_zero_installment
    ) AS zero_installment_payments,

    COUNT(*) FILTER (
        WHERE is_undefined_payment_method
    ) AS undefined_payment_methods,

    COUNT(*) FILTER (
        WHERE has_payment_quality_flag
    ) AS flagged_payment_rows,

    COUNT(DISTINCT order_id) FILTER (
        WHERE has_payment_quality_flag
    ) AS orders_with_flagged_payments,

    COUNT(*) FILTER (
        WHERE is_zero_value_payment
          AND is_undefined_payment_method
    ) AS overlapping_zero_undefined_flags,

    COUNT(*) FILTER (
        WHERE payment_amount IS NULL
    ) AS missing_payment_amounts

FROM staging.stg_order_payments;
