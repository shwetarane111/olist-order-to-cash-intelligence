
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 5.1 - TASK 2
-- MODEL: staging.stg_order_items
-- =====================================================

-- CHECK A: Validate RAW source fields before casting

SELECT
    COUNT(*) AS total_item_rows,

    COUNT(*) FILTER (
        WHERE shipping_limit_date IS NULL
           OR BTRIM(shipping_limit_date) = ''
    ) AS missing_shipping_limits,

    COUNT(*) FILTER (
        WHERE shipping_limit_date IS NOT NULL
          AND BTRIM(shipping_limit_date) <> ''
          AND (
              BTRIM(shipping_limit_date) !~
              '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'

              OR NOT pg_input_is_valid(
                  BTRIM(shipping_limit_date),
                  'timestamp without time zone'
              )
          )
    ) AS invalid_shipping_limits,

    COUNT(*) FILTER (
        WHERE price IS NULL
           OR freight_value IS NULL
    ) AS missing_monetary_values,

    COUNT(*) FILTER (
        WHERE price < 0
           OR freight_value < 0
    ) AS negative_monetary_values

FROM raw.order_items;


-- =====================================================
-- CREATE THE ORDER ITEMS STAGING VIEW
-- =====================================================

CREATE OR REPLACE VIEW staging.stg_order_items AS

SELECT
    -- Logical composite key
    oi.order_id,
    oi.order_item_id,

    -- Relationships to products and sellers
    oi.product_id,
    oi.seller_id,

    -- Convert source TEXT to TIMESTAMP
    NULLIF(
        BTRIM(oi.shipping_limit_date),
        ''
    )::TIMESTAMP AS shipping_limit_timestamp,

    -- Standardized monetary column names
    oi.price AS item_price,
    oi.freight_value AS freight_amount,

    -- Item-level price plus freight
    (
        oi.price + oi.freight_value
    )::NUMERIC(15,2) AS item_total_amount

FROM raw.order_items AS oi;


-- =====================================================
-- CHECK C: Validate staging.stg_order_items
-- =====================================================

SELECT
    COUNT(*) AS total_item_rows,

    COUNT(
        DISTINCT (order_id, order_item_id)
    ) AS unique_composite_keys,

    COUNT(*) FILTER (
        WHERE order_id IS NULL
           OR BTRIM(order_id) = ''
           OR order_item_id IS NULL
    ) AS missing_key_rows,

    COUNT(*) FILTER (
        WHERE shipping_limit_timestamp IS NULL
    ) AS missing_shipping_timestamps,

    COUNT(*) FILTER (
        WHERE item_price IS NULL
           OR freight_amount IS NULL
           OR item_total_amount IS NULL
    ) AS missing_monetary_values,

    COUNT(*) FILTER (
        WHERE item_total_amount <>
              item_price + freight_amount
    ) AS incorrect_item_totals

FROM staging.stg_order_items;
