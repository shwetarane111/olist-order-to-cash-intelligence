
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 7.3 - TASK 7
-- FILE: 37_powerbi_product_seller_kpi_reconciliation.sql
-- PURPOSE: Item/product/seller KPI reconciliation
-- =====================================================

WITH scoped_items AS (

    SELECT
        'ALL' AS cohort,
        i.order_id,
        i.product_id,
        i.seller_id,
        i.item_price,
        i.freight_amount,
        i.item_total_amount
    FROM staging.stg_order_items AS i

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED' AS cohort,
        i.order_id,
        i.product_id,
        i.seller_id,
        i.item_price,
        i.freight_amount,
        i.item_total_amount
    FROM staging.stg_order_items AS i

    JOIN staging.stg_orders AS o
        ON i.order_id = o.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp::DATE
          >= DATE '2018-01-01'
      AND o.order_purchase_timestamp::DATE
          < DATE '2018-04-01'

),

item_summary AS (

    SELECT
        cohort,

        COUNT(*) AS item_entries,

        COUNT(DISTINCT order_id)
            AS orders_with_items,

        COUNT(DISTINCT product_id)
            AS products_with_items,

        COUNT(DISTINCT seller_id)
            AS sellers_with_items,

        SUM(item_price) AS recorded_item_price,

        SUM(freight_amount) AS recorded_freight,

        SUM(item_total_amount)
            AS item_plus_freight,

        ROUND(
            AVG(item_price)::NUMERIC, 2
        ) AS average_item_price,

        ROUND(
            AVG(freight_amount)::NUMERIC, 2
        ) AS average_freight_per_item,

        ROUND(
            100.0 * SUM(freight_amount)
            / NULLIF(SUM(item_total_amount), 0),
            2
        ) AS freight_share_pct

    FROM scoped_items

    GROUP BY cohort

),

items_per_order AS (

    SELECT
        cohort,
        order_id,
        COUNT(*) AS entries_per_order

    FROM scoped_items

    GROUP BY cohort, order_id

),

order_summary AS (

    SELECT
        cohort,

        COUNT(*) FILTER (
            WHERE entries_per_order > 1
        ) AS orders_with_multiple_items,

        MAX(entries_per_order)
            AS maximum_items_per_order

    FROM items_per_order

    GROUP BY cohort

)

SELECT
    i.cohort,
    i.item_entries,
    i.orders_with_items,
    i.products_with_items,
    i.sellers_with_items,
    i.recorded_item_price,
    i.recorded_freight,
    i.item_plus_freight,
    i.average_item_price,
    i.average_freight_per_item,
    i.freight_share_pct,
    o.orders_with_multiple_items,
    o.maximum_items_per_order

FROM item_summary AS i

JOIN order_summary AS o
    ON i.cohort = o.cohort

ORDER BY i.cohort;


-- CHECK I: Catalog quality baseline

SELECT
    COUNT(*) AS catalog_products,

    COUNT(*) FILTER (
        WHERE category_status = 'TRANSLATED'
    ) AS translated_products,

    COUNT(*) FILTER (
        WHERE category_status = 'UNTRANSLATED'
    ) AS untranslated_products,

    COUNT(*) FILTER (
        WHERE category_status = 'MISSING_SOURCE_CATEGORY'
    ) AS missing_source_category_products,

    COUNT(*) FILTER (
        WHERE has_missing_physical_attributes
    ) AS products_missing_physical_attributes,

    COUNT(*) FILTER (
        WHERE is_zero_weight
    ) AS zero_weight_products

FROM analytics.dim_product;
