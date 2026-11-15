
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 6.3 - TASK 3
-- MODEL: analytics.fact_payments
-- =====================================================

-- CHECK A: Source readiness

SELECT
    COUNT(*) AS source_payment_records,

    COUNT(DISTINCT (order_id, payment_sequential))
        AS unique_payment_keys,

    COUNT(DISTINCT order_id)
        AS distinct_orders_with_payments,

    COUNT(*) FILTER (
        WHERE order_id IS NULL
           OR BTRIM(order_id) = ''
           OR payment_sequential IS NULL
    ) AS missing_payment_keys,

    COUNT(*) FILTER (
        WHERE payment_method IS NULL
           OR BTRIM(payment_method) = ''
           OR payment_installments IS NULL
           OR payment_amount IS NULL
    ) AS missing_payment_attributes,

    COUNT(*) FILTER (
        WHERE payment_amount < 0
    ) AS negative_payment_amounts,

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
    ) AS flagged_payment_records,

    COUNT(DISTINCT order_id) FILTER (
        WHERE has_payment_quality_flag
    ) AS orders_with_flagged_payments,

    COUNT(*) FILTER (
        WHERE is_zero_value_payment
              IS DISTINCT FROM
              COALESCE(payment_amount = 0, FALSE)

           OR is_zero_installment
              IS DISTINCT FROM
              COALESCE(payment_installments = 0, FALSE)

           OR is_undefined_payment_method
              IS DISTINCT FROM
              COALESCE(
                  payment_method = 'not_defined',
                  FALSE
              )

           OR has_payment_quality_flag
              IS DISTINCT FROM (
                  is_zero_value_payment
                  OR is_zero_installment
                  OR is_undefined_payment_method
              )
    ) AS inconsistent_quality_flags

FROM staging.stg_order_payments;


-- =====================================================
-- CHECK B: Create analytics.fact_payments
-- =====================================================

BEGIN;

CREATE TABLE analytics.fact_payments AS

SELECT
    -- Source payment identifiers
    p.order_id,
    p.payment_sequential,

    -- Order-associated customer information
    o.customer_id,
    c.customer_unique_id,

    CASE
        WHEN c.customer_id IS NOT NULL
        THEN MD5(
            JSONB_BUILD_ARRAY(
                c.customer_zip_code_prefix,
                c.customer_city,
                c.customer_state
            )::TEXT
        )
        ELSE NULL
    END AS customer_location_key,

    -- Shared dimension keys
    o.order_status,

    o.order_purchase_timestamp::DATE
        AS purchase_date,

    -- Original staged payment attributes
    p.payment_method,
    p.payment_installments,
    p.payment_amount,

    -- Preserve all payment-quality indicators
    p.is_zero_value_payment,
    p.is_zero_installment,
    p.is_undefined_payment_method,
    p.has_payment_quality_flag

FROM staging.stg_order_payments AS p

LEFT JOIN staging.stg_orders AS o
    ON p.order_id = o.order_id

LEFT JOIN staging.stg_customers AS c
    ON o.customer_id = c.customer_id

WITH DATA;


-- =====================================================
-- Enforce payment-entry grain and required keys
-- =====================================================

ALTER TABLE analytics.fact_payments

    ADD CONSTRAINT fact_payments_pkey
        PRIMARY KEY (order_id, payment_sequential),

    ALTER COLUMN customer_id SET NOT NULL,
    ALTER COLUMN customer_unique_id SET NOT NULL,
    ALTER COLUMN customer_location_key SET NOT NULL,

    ALTER COLUMN order_status SET NOT NULL,
    ALTER COLUMN purchase_date SET NOT NULL,

    ALTER COLUMN payment_method SET NOT NULL,
    ALTER COLUMN payment_installments SET NOT NULL,
    ALTER COLUMN payment_amount SET NOT NULL,

    ALTER COLUMN is_zero_value_payment SET NOT NULL,
    ALTER COLUMN is_zero_installment SET NOT NULL,
    ALTER COLUMN is_undefined_payment_method SET NOT NULL,
    ALTER COLUMN has_payment_quality_flag SET NOT NULL,

    ADD CONSTRAINT chk_fact_payments_quality_flags
        CHECK (
            is_zero_value_payment =
                (payment_amount = 0)

            AND is_zero_installment =
                (payment_installments = 0)

            AND is_undefined_payment_method =
                (payment_method = 'not_defined')

            AND has_payment_quality_flag =
                (
                    is_zero_value_payment
                    OR is_zero_installment
                    OR is_undefined_payment_method
                )
        );


-- =====================================================
-- Enforce dimension relationships
-- =====================================================

ALTER TABLE analytics.fact_payments

    ADD CONSTRAINT fk_fact_payments_customer
        FOREIGN KEY (customer_unique_id)
        REFERENCES analytics.dim_customer (
            customer_unique_id
        ),

    ADD CONSTRAINT fk_fact_payments_geography
        FOREIGN KEY (customer_location_key)
        REFERENCES analytics.dim_customer_geography (
            customer_location_key
        ),

    ADD CONSTRAINT fk_fact_payments_status
        FOREIGN KEY (order_status)
        REFERENCES analytics.dim_order_status (
            order_status
        ),

    ADD CONSTRAINT fk_fact_payments_purchase_date
        FOREIGN KEY (purchase_date)
        REFERENCES analytics.dim_purchase_date (
            date
        ),

    ADD CONSTRAINT fk_fact_payments_parent_order
        FOREIGN KEY (order_id)
        REFERENCES analytics.fact_orders (order_id);

COMMIT;


-- =====================================================
-- CHECK C1: Payment fact quality and monetary baseline
-- =====================================================

SELECT
    COUNT(*) AS fact_payment_records,

    COUNT(DISTINCT (order_id, payment_sequential))
        AS unique_payment_keys,

    COUNT(DISTINCT order_id)
        AS distinct_orders_with_payments,

    SUM(payment_amount)
        AS all_record_payment_total,

    (
        SUM(payment_amount)
        -
        (
            SELECT SUM(payment_amount)
            FROM staging.stg_order_payments
        )
    ) AS difference_from_staging,

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
    ) AS flagged_payment_records,

    COUNT(DISTINCT order_id) FILTER (
        WHERE has_payment_quality_flag
    ) AS orders_with_flagged_payments

FROM analytics.fact_payments;


-- =====================================================
-- CHECK C2: Source-to-fact fidelity
-- =====================================================

WITH expected AS (

    SELECT
        p.order_id,
        p.payment_sequential,

        o.customer_id,
        c.customer_unique_id,

        MD5(
            JSONB_BUILD_ARRAY(
                c.customer_zip_code_prefix,
                c.customer_city,
                c.customer_state
            )::TEXT
        ) AS customer_location_key,

        o.order_status,
        o.order_purchase_timestamp::DATE
            AS purchase_date,

        p.payment_method,
        p.payment_installments,
        p.payment_amount,

        p.is_zero_value_payment,
        p.is_zero_installment,
        p.is_undefined_payment_method,
        p.has_payment_quality_flag

    FROM staging.stg_order_payments AS p

    LEFT JOIN staging.stg_orders AS o
        ON p.order_id = o.order_id

    LEFT JOIN staging.stg_customers AS c
        ON o.customer_id = c.customer_id

)

SELECT
    COUNT(*) AS checked_key_combinations,

    COUNT(*) FILTER (
        WHERE f.order_id IS NULL
    ) AS missing_fact_payments,

    COUNT(*) FILTER (
        WHERE e.order_id IS NULL
    ) AS unexpected_fact_payments,

    COUNT(*) FILTER (
        WHERE e.order_id IS NOT NULL
          AND f.order_id IS NOT NULL

          AND ROW(
              f.customer_id,
              f.customer_unique_id,
              f.customer_location_key,
              f.order_status,
              f.purchase_date,
              f.payment_method,
              f.payment_installments,
              f.payment_amount,
              f.is_zero_value_payment,
              f.is_zero_installment,
              f.is_undefined_payment_method,
              f.has_payment_quality_flag
          ) IS DISTINCT FROM ROW(
              e.customer_id,
              e.customer_unique_id,
              e.customer_location_key,
              e.order_status,
              e.purchase_date,
              e.payment_method,
              e.payment_installments,
              e.payment_amount,
              e.is_zero_value_payment,
              e.is_zero_installment,
              e.is_undefined_payment_method,
              e.has_payment_quality_flag
          )
    ) AS inconsistent_payment_attributes

FROM expected AS e

FULL OUTER JOIN analytics.fact_payments AS f
    ON e.order_id = f.order_id
   AND e.payment_sequential = f.payment_sequential;


-- =====================================================
-- CHECK C3: Cross-grain payment reconciliation
-- =====================================================

WITH payment_rollups AS (

    SELECT
        order_id,

        COUNT(*)::INTEGER
            AS payment_entry_count,

        SUM(payment_amount)
            AS payment_total

    FROM analytics.fact_payments

    GROUP BY order_id

)

SELECT
    COUNT(*) AS checked_orders,

    COUNT(*) FILTER (
        WHERE p.order_id IS NOT NULL
    ) AS orders_with_payments,

    COUNT(*) FILTER (
        WHERE p.order_id IS NULL
    ) AS orders_without_payment_records,

    SUM(COALESCE(p.payment_entry_count, 0))
        AS represented_payment_entries,

    COUNT(*) FILTER (
        WHERE ROW(
            o.payment_entry_count,
            o.recorded_payment_total,
            o.has_payment_records
        ) IS DISTINCT FROM ROW(
            COALESCE(p.payment_entry_count, 0),
            p.payment_total,
            (p.order_id IS NOT NULL)
        )
    ) AS inconsistent_order_payment_rollups

FROM analytics.fact_orders AS o

LEFT JOIN payment_rollups AS p
    ON o.order_id = p.order_id;


-- =====================================================
-- CHECK C4: Payment fact dimension relationships
-- =====================================================

SELECT
    (
        SELECT COUNT(*)
        FROM analytics.fact_payments
    ) AS source_fact_rows,

    COUNT(*) AS rows_after_join,

    COUNT(DISTINCT (
        f.order_id,
        f.payment_sequential
    )) AS distinct_payment_keys,

    COUNT(*) FILTER (
        WHERE c.customer_unique_id IS NULL
    ) AS missing_customers,

    COUNT(*) FILTER (
        WHERE g.customer_location_key IS NULL
    ) AS missing_customer_geography,

    COUNT(*) FILTER (
        WHERE s.order_status IS NULL
    ) AS missing_order_statuses,

    COUNT(*) FILTER (
        WHERE d.date IS NULL
    ) AS missing_purchase_dates

FROM analytics.fact_payments AS f

LEFT JOIN analytics.dim_customer AS c
    ON f.customer_unique_id =
       c.customer_unique_id

LEFT JOIN analytics.dim_customer_geography AS g
    ON f.customer_location_key =
       g.customer_location_key

LEFT JOIN analytics.dim_order_status AS s
    ON f.order_status =
       s.order_status

LEFT JOIN analytics.dim_purchase_date AS d
    ON f.purchase_date =
       d.date;


-- CHECK C5a: Recorded payments by method

SELECT
    payment_method,

    COUNT(*) AS payment_entries,

    COUNT(DISTINCT order_id)
        AS distinct_associated_orders,

    SUM(payment_amount)
        AS recorded_payment_total,

    COUNT(*) FILTER (
        WHERE has_payment_quality_flag
    ) AS flagged_entries

FROM analytics.fact_payments

GROUP BY payment_method

ORDER BY recorded_payment_total DESC,
         payment_method;


-- CHECK C5b: Multiple payment entries per order

WITH payment_counts AS (

    SELECT
        order_id,
        COUNT(*) AS payment_entries

    FROM analytics.fact_payments

    GROUP BY order_id

)

SELECT
    COUNT(*) AS orders_with_payment_records,

    COUNT(*) FILTER (
        WHERE payment_entries > 1
    ) AS orders_with_multiple_payment_entries,

    MAX(payment_entries)
        AS maximum_entries_per_order,

    SUM(payment_entries)
        AS total_payment_entries

FROM payment_counts;
