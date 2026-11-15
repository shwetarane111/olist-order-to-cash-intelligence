
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 6.3 - TASK 2
-- MODEL: analytics.fact_order_items
-- =====================================================

-- CHECK A: Source readiness

SELECT
    COUNT(*) AS source_item_records,

    COUNT(DISTINCT (order_id, order_item_id))
        AS unique_item_keys,

    COUNT(DISTINCT order_id)
        AS distinct_orders_with_items,

    COUNT(*) FILTER (
        WHERE order_id IS NULL
           OR order_item_id IS NULL
           OR product_id IS NULL
           OR seller_id IS NULL
    ) AS missing_required_identifiers,

    COUNT(*) FILTER (
        WHERE item_price IS NULL
           OR freight_amount IS NULL
           OR item_total_amount IS NULL
    ) AS missing_monetary_values,

    COUNT(*) FILTER (
        WHERE item_price < 0
           OR freight_amount < 0
    ) AS negative_monetary_values,

    COUNT(*) FILTER (
        WHERE item_total_amount IS DISTINCT FROM
              (item_price + freight_amount)
    ) AS inconsistent_item_totals,

    COUNT(*) FILTER (
        WHERE shipping_limit_timestamp IS NULL
    ) AS missing_shipping_limit_timestamps

FROM staging.stg_order_items;


-- =====================================================
-- CHECK B: Create analytics.fact_order_items
-- =====================================================

BEGIN;

CREATE TABLE analytics.fact_order_items AS

SELECT
    -- Original item identifiers
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,

    -- Order-associated customer identifiers
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

    -- Preserve source shipping deadline
    oi.shipping_limit_timestamp,

    -- Item-level monetary amounts
    oi.item_price,
    oi.freight_amount,
    oi.item_total_amount

FROM staging.stg_order_items AS oi

LEFT JOIN staging.stg_orders AS o
    ON oi.order_id = o.order_id

LEFT JOIN staging.stg_customers AS c
    ON o.customer_id = c.customer_id

WITH DATA;


-- =====================================================
-- Enforce grain and required attributes
-- =====================================================

ALTER TABLE analytics.fact_order_items

    ADD CONSTRAINT fact_order_items_pkey
        PRIMARY KEY (order_id, order_item_id),

    ALTER COLUMN product_id SET NOT NULL,
    ALTER COLUMN seller_id SET NOT NULL,

    ALTER COLUMN customer_id SET NOT NULL,
    ALTER COLUMN customer_unique_id SET NOT NULL,
    ALTER COLUMN customer_location_key SET NOT NULL,

    ALTER COLUMN order_status SET NOT NULL,
    ALTER COLUMN purchase_date SET NOT NULL,

    ALTER COLUMN item_price SET NOT NULL,
    ALTER COLUMN freight_amount SET NOT NULL,
    ALTER COLUMN item_total_amount SET NOT NULL,

    ADD CONSTRAINT chk_fact_items_money
        CHECK (
            item_price >= 0
            AND freight_amount >= 0
            AND item_total_amount =
                item_price + freight_amount
        );


-- =====================================================
-- Dimension foreign keys
-- =====================================================

ALTER TABLE analytics.fact_order_items

    ADD CONSTRAINT fk_fact_items_product
        FOREIGN KEY (product_id)
        REFERENCES analytics.dim_product (product_id),

    ADD CONSTRAINT fk_fact_items_seller
        FOREIGN KEY (seller_id)
        REFERENCES analytics.dim_seller (seller_id),

    ADD CONSTRAINT fk_fact_items_customer
        FOREIGN KEY (customer_unique_id)
        REFERENCES analytics.dim_customer (
            customer_unique_id
        ),

    ADD CONSTRAINT fk_fact_items_geography
        FOREIGN KEY (customer_location_key)
        REFERENCES analytics.dim_customer_geography (
            customer_location_key
        ),

    ADD CONSTRAINT fk_fact_items_status
        FOREIGN KEY (order_status)
        REFERENCES analytics.dim_order_status (
            order_status
        ),

    ADD CONSTRAINT fk_fact_items_purchase_date
        FOREIGN KEY (purchase_date)
        REFERENCES analytics.dim_purchase_date (
            date
        );


-- Database-level order integrity.
-- This does NOT imply a Power BI fact-to-fact
-- relationship.

ALTER TABLE analytics.fact_order_items

    ADD CONSTRAINT fk_fact_items_parent_order
        FOREIGN KEY (order_id)
        REFERENCES analytics.fact_orders (order_id);

COMMIT;


-- =====================================================
-- CHECK C1: Fact structure and quality
-- =====================================================

SELECT
    COUNT(*) AS fact_item_records,

    COUNT(DISTINCT (order_id, order_item_id))
        AS unique_item_keys,

    COUNT(DISTINCT order_id)
        AS distinct_orders_with_items,

    COUNT(*) FILTER (
        WHERE item_price IS NULL
           OR freight_amount IS NULL
           OR item_total_amount IS NULL
    ) AS missing_money,

    COUNT(*) FILTER (
        WHERE item_price < 0
           OR freight_amount < 0
    ) AS negative_money,

    COUNT(*) FILTER (
        WHERE item_total_amount IS DISTINCT FROM
              (item_price + freight_amount)
    ) AS inconsistent_item_totals,

    SUM(item_price) AS all_record_item_price_total,

    SUM(freight_amount) AS all_record_freight_total,

    SUM(item_total_amount) AS all_record_item_plus_freight

FROM analytics.fact_order_items;


-- =====================================================
-- CHECK C2: Source-to-fact fidelity
-- =====================================================

SELECT
    COUNT(*) AS checked_source_items,

    COUNT(*) FILTER (
        WHERE f.order_id IS NULL
    ) AS missing_fact_items,

    COUNT(*) FILTER (
        WHERE f.order_id IS NOT NULL
          AND ROW(
              f.product_id,
              f.seller_id,
              f.customer_id,
              f.customer_unique_id,
              f.customer_location_key,
              f.order_status,
              f.purchase_date,
              f.shipping_limit_timestamp,
              f.item_price,
              f.freight_amount,
              f.item_total_amount
          ) IS DISTINCT FROM ROW(
              oi.product_id,
              oi.seller_id,
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
              END,

              o.order_status,
              o.order_purchase_timestamp::DATE,
              oi.shipping_limit_timestamp,
              oi.item_price,
              oi.freight_amount,
              oi.item_total_amount
          )
    ) AS inconsistent_attribute_rows,

    (
        SELECT COUNT(*)
        FROM analytics.fact_order_items AS f2

        WHERE NOT EXISTS (
            SELECT 1
            FROM staging.stg_order_items AS s
            WHERE s.order_id = f2.order_id
              AND s.order_item_id = f2.order_item_id
        )
    ) AS unexpected_fact_items

FROM staging.stg_order_items AS oi

LEFT JOIN staging.stg_orders AS o
    ON oi.order_id = o.order_id

LEFT JOIN staging.stg_customers AS c
    ON o.customer_id = c.customer_id

LEFT JOIN analytics.fact_order_items AS f
    ON oi.order_id = f.order_id
   AND oi.order_item_id = f.order_item_id;


-- =====================================================
-- CHECK C3: Cross-grain financial consistency
-- =====================================================

WITH item_rollups AS (

    SELECT
        order_id,

        COUNT(*) AS item_count,

        SUM(item_price) AS price_total,
        SUM(freight_amount) AS freight_total,
        SUM(item_total_amount) AS item_total

    FROM analytics.fact_order_items

    GROUP BY order_id

)

SELECT
    COUNT(*) AS orders_with_items,

    COUNT(*) FILTER (
        WHERE o.order_id IS NULL
    ) AS missing_parent_orders,

    COUNT(*) FILTER (
        WHERE o.order_id IS NOT NULL
          AND ROW(
              i.item_count,
              i.price_total,
              i.freight_total,
              i.item_total
          ) IS DISTINCT FROM ROW(
              o.item_record_count,
              o.item_price_total,
              o.freight_total,
              o.item_plus_freight_total
          )
    ) AS inconsistent_order_rollups

FROM item_rollups AS i

LEFT JOIN analytics.fact_orders AS o
    ON i.order_id = o.order_id;


-- =====================================================
-- CHECK C4: Fact-to-dimension joins
-- =====================================================

SELECT
    (
        SELECT COUNT(*)
        FROM analytics.fact_order_items
    ) AS source_fact_rows,

    COUNT(*) AS rows_after_join,

    COUNT(*) FILTER (
        WHERE p.product_id IS NULL
    ) AS missing_products,

    COUNT(*) FILTER (
        WHERE s.seller_id IS NULL
    ) AS missing_sellers,

    COUNT(*) FILTER (
        WHERE c.customer_unique_id IS NULL
    ) AS missing_customers,

    COUNT(*) FILTER (
        WHERE g.customer_location_key IS NULL
    ) AS missing_customer_geography,

    COUNT(*) FILTER (
        WHERE st.order_status IS NULL
    ) AS missing_statuses,

    COUNT(*) FILTER (
        WHERE dt.date IS NULL
    ) AS missing_purchase_dates

FROM analytics.fact_order_items AS f

LEFT JOIN analytics.dim_product AS p
    ON f.product_id = p.product_id

LEFT JOIN analytics.dim_seller AS s
    ON f.seller_id = s.seller_id

LEFT JOIN analytics.dim_customer AS c
    ON f.customer_unique_id = c.customer_unique_id

LEFT JOIN analytics.dim_customer_geography AS g
    ON f.customer_location_key = g.customer_location_key

LEFT JOIN analytics.dim_order_status AS st
    ON f.order_status = st.order_status

LEFT JOIN analytics.dim_purchase_date AS dt
    ON f.purchase_date = dt.date;
