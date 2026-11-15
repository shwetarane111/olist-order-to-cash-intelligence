
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 5.1 - TASK 1
-- MODEL: staging.stg_orders
-- =====================================================

-- CHECK 1: Validate source timestamp strings

WITH timestamp_fields AS (

    SELECT
        field_name,
        raw_value

    FROM raw.orders AS o

    CROSS JOIN LATERAL (
        VALUES
            ('order_purchase_timestamp',
                o.order_purchase_timestamp),

            ('order_approved_at',
                o.order_approved_at),

            ('order_delivered_carrier_date',
                o.order_delivered_carrier_date),

            ('order_delivered_customer_date',
                o.order_delivered_customer_date),

            ('order_estimated_delivery_date',
                o.order_estimated_delivery_date)

    ) AS t(field_name, raw_value)

)

SELECT
    field_name,

    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(raw_value), '') IS NULL
    ) AS missing_or_blank,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(raw_value), '') IS NOT NULL
          AND (
              BTRIM(raw_value) !~
                  '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'

              OR NOT pg_input_is_valid(
                  BTRIM(raw_value),
                  'timestamp without time zone'
              )
          )
    ) AS invalid_nonblank

FROM timestamp_fields

GROUP BY field_name

ORDER BY field_name;


-- =====================================================
-- CREATE THE ORDERS STAGING VIEW
-- =====================================================

CREATE OR REPLACE VIEW staging.stg_orders AS

SELECT
    -- Preserve the original identifiers
    o.order_id,
    o.customer_id,

    -- Standardize status text
    NULLIF(
        LOWER(BTRIM(o.order_status)),
        ''
    ) AS order_status,

    -- Convert source strings into timestamps
    NULLIF(
        BTRIM(o.order_purchase_timestamp),
        ''
    )::TIMESTAMP AS order_purchase_timestamp,

    NULLIF(
        BTRIM(o.order_approved_at),
        ''
    )::TIMESTAMP AS order_approved_at,

    NULLIF(
        BTRIM(o.order_delivered_carrier_date),
        ''
    )::TIMESTAMP AS order_delivered_carrier_date,

    NULLIF(
        BTRIM(o.order_delivered_customer_date),
        ''
    )::TIMESTAMP AS order_delivered_customer_date,

    NULLIF(
        BTRIM(o.order_estimated_delivery_date),
        ''
    )::TIMESTAMP AS order_estimated_delivery_date

FROM raw.orders AS o;


-- =====================================================
-- CHECK 2: Validate transformed Orders data
-- =====================================================

SELECT
    COUNT(*) AS total_orders,

    COUNT(DISTINCT order_id)
        AS distinct_order_ids,

    COUNT(*) FILTER (
        WHERE order_purchase_timestamp IS NULL
    ) AS missing_purchase_timestamps,

    COUNT(*) FILTER (
        WHERE order_approved_at IS NULL
    ) AS missing_approval_timestamps,

    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date IS NULL
    ) AS missing_carrier_timestamps,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
    ) AS missing_delivery_timestamps,

    COUNT(*) FILTER (
        WHERE order_estimated_delivery_date IS NULL
    ) AS missing_estimated_timestamps

FROM staging.stg_orders;
