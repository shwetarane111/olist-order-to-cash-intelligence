
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 5.2 - TASK 2
-- FILE: 16_staging_integrity_audit.sql
-- =====================================================

-- CHECK A: Logical key integrity

WITH key_checks AS (

    SELECT
        'stg_orders' AS model_name,
        COUNT(*) AS total_rows,
        COUNT(DISTINCT order_id) AS distinct_keys,
        COUNT(*) FILTER (
            WHERE order_id IS NULL
               OR BTRIM(order_id) = ''
        ) AS missing_key_rows
    FROM staging.stg_orders

    UNION ALL

    SELECT
        'stg_order_items',
        COUNT(*),
        COUNT(DISTINCT (order_id, order_item_id)),
        COUNT(*) FILTER (
            WHERE order_id IS NULL
               OR BTRIM(order_id) = ''
               OR order_item_id IS NULL
        )
    FROM staging.stg_order_items

    UNION ALL

    SELECT
        'stg_order_payments',
        COUNT(*),
        COUNT(DISTINCT (order_id, payment_sequential)),
        COUNT(*) FILTER (
            WHERE order_id IS NULL
               OR BTRIM(order_id) = ''
               OR payment_sequential IS NULL
        )
    FROM staging.stg_order_payments

    UNION ALL

    SELECT
        'stg_customers',
        COUNT(*),
        COUNT(DISTINCT customer_id),
        COUNT(*) FILTER (
            WHERE customer_id IS NULL
               OR BTRIM(customer_id) = ''
        )
    FROM staging.stg_customers

    UNION ALL

    SELECT
        'stg_products',
        COUNT(*),
        COUNT(DISTINCT product_id),
        COUNT(*) FILTER (
            WHERE product_id IS NULL
               OR BTRIM(product_id) = ''
        )
    FROM staging.stg_products

    UNION ALL

    SELECT
        'stg_sellers',
        COUNT(*),
        COUNT(DISTINCT seller_id),
        COUNT(*) FILTER (
            WHERE seller_id IS NULL
               OR BTRIM(seller_id) = ''
        )
    FROM staging.stg_sellers

    UNION ALL

    SELECT
        'stg_order_reviews',
        COUNT(*),
        COUNT(DISTINCT (review_id, order_id)),
        COUNT(*) FILTER (
            WHERE review_id IS NULL
               OR BTRIM(review_id) = ''
               OR order_id IS NULL
               OR BTRIM(order_id) = ''
        )
    FROM staging.stg_order_reviews

    UNION ALL

    SELECT
        'ref_zip_geolocation',
        COUNT(*),
        COUNT(DISTINCT geolocation_zip_code_prefix),
        COUNT(*) FILTER (
            WHERE geolocation_zip_code_prefix IS NULL
               OR BTRIM(geolocation_zip_code_prefix) = ''
        )
    FROM staging.ref_zip_geolocation

)

SELECT
    model_name,
    total_rows,
    distinct_keys,
    total_rows - distinct_keys AS extra_rows,
    missing_key_rows,

    CASE
        WHEN total_rows = distinct_keys
         AND missing_key_rows = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS audit_status

FROM key_checks

ORDER BY model_name;


-- =====================================================
-- CHECK B: Cross-table referential integrity
-- =====================================================

WITH relationship_checks AS (

    -- Orders -> Customers
    SELECT
        'Orders -> Customers' AS relationship,
        99441::BIGINT AS expected_child_rows,
        COUNT(*) AS actual_child_rows,
        COUNT(*) FILTER (
            WHERE c.customer_id IS NULL
        ) AS unmatched_rows

    FROM staging.stg_orders AS o

    LEFT JOIN staging.stg_customers AS c
        ON o.customer_id = c.customer_id

    UNION ALL

    -- Order Items -> Orders
    SELECT
        'Order Items -> Orders',
        112650::BIGINT,
        COUNT(*),
        COUNT(*) FILTER (
            WHERE o.order_id IS NULL
        )

    FROM staging.stg_order_items AS oi

    LEFT JOIN staging.stg_orders AS o
        ON oi.order_id = o.order_id

    UNION ALL

    -- Order Items -> Products
    SELECT
        'Order Items -> Products',
        112650::BIGINT,
        COUNT(*),
        COUNT(*) FILTER (
            WHERE p.product_id IS NULL
        )

    FROM staging.stg_order_items AS oi

    LEFT JOIN staging.stg_products AS p
        ON oi.product_id = p.product_id

    UNION ALL

    -- Order Items -> Sellers
    SELECT
        'Order Items -> Sellers',
        112650::BIGINT,
        COUNT(*),
        COUNT(*) FILTER (
            WHERE s.seller_id IS NULL
        )

    FROM staging.stg_order_items AS oi

    LEFT JOIN staging.stg_sellers AS s
        ON oi.seller_id = s.seller_id

    UNION ALL

    -- Order Payments -> Orders
    SELECT
        'Order Payments -> Orders',
        103886::BIGINT,
        COUNT(*),
        COUNT(*) FILTER (
            WHERE o.order_id IS NULL
        )

    FROM staging.stg_order_payments AS p

    LEFT JOIN staging.stg_orders AS o
        ON p.order_id = o.order_id

    UNION ALL

    -- Order Reviews -> Orders
    SELECT
        'Order Reviews -> Orders',
        99224::BIGINT,
        COUNT(*),
        COUNT(*) FILTER (
            WHERE o.order_id IS NULL
        )

    FROM staging.stg_order_reviews AS r

    LEFT JOIN staging.stg_orders AS o
        ON r.order_id = o.order_id

)

SELECT
    relationship,
    expected_child_rows,
    actual_child_rows,
    unmatched_rows,

    CASE
        WHEN actual_child_rows = expected_child_rows
         AND unmatched_rows = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS audit_status

FROM relationship_checks

ORDER BY relationship;


-- =====================================================
-- CHECK C: RAW-to-STAGING transformation fidelity
-- =====================================================

WITH comparisons AS (

    -- 1. ORDERS
    SELECT
        'stg_orders' AS model_name,
        99441::BIGINT AS expected_rows,
        COUNT(*) AS checked_rows,

        COUNT(*) FILTER (
            WHERE ROW(
                s.order_status,
                s.order_purchase_timestamp,
                s.order_approved_at,
                s.order_delivered_carrier_date,
                s.order_delivered_customer_date,
                s.order_estimated_delivery_date
            ) IS DISTINCT FROM ROW(
                NULLIF(LOWER(BTRIM(r.order_status)), ''),
                NULLIF(BTRIM(r.order_purchase_timestamp), '')::TIMESTAMP,
                NULLIF(BTRIM(r.order_approved_at), '')::TIMESTAMP,
                NULLIF(BTRIM(r.order_delivered_carrier_date), '')::TIMESTAMP,
                NULLIF(BTRIM(r.order_delivered_customer_date), '')::TIMESTAMP,
                NULLIF(BTRIM(r.order_estimated_delivery_date), '')::TIMESTAMP
            )
        ) AS inconsistent_rows

    FROM staging.stg_orders AS s
    JOIN raw.orders AS r
        ON s.order_id = r.order_id

    UNION ALL

    -- 2. ORDER ITEMS
    SELECT
        'stg_order_items',
        112650::BIGINT,
        COUNT(*),

        COUNT(*) FILTER (
            WHERE ROW(
                s.product_id,
                s.seller_id,
                s.shipping_limit_timestamp,
                s.item_price,
                s.freight_amount,
                s.item_total_amount
            ) IS DISTINCT FROM ROW(
                r.product_id,
                r.seller_id,
                NULLIF(BTRIM(r.shipping_limit_date), '')::TIMESTAMP,
                r.price,
                r.freight_value,
                (r.price + r.freight_value)::NUMERIC(15,2)
            )
        )

    FROM staging.stg_order_items AS s
    JOIN raw.order_items AS r
        ON s.order_id = r.order_id
       AND s.order_item_id = r.order_item_id

    UNION ALL

    -- 3. ORDER PAYMENTS
    SELECT
        'stg_order_payments',
        103886::BIGINT,
        COUNT(*),

        COUNT(*) FILTER (
            WHERE ROW(
                s.payment_method,
                s.payment_installments,
                s.payment_amount,
                s.is_zero_value_payment,
                s.is_zero_installment,
                s.is_undefined_payment_method
            ) IS DISTINCT FROM ROW(
                NULLIF(LOWER(BTRIM(r.payment_type)), ''),
                r.payment_installments,
                r.payment_value,
                COALESCE(r.payment_value = 0, FALSE),
                COALESCE(r.payment_installments = 0, FALSE),
                COALESCE(
                    LOWER(BTRIM(r.payment_type)) = 'not_defined',
                    FALSE
                )
            )
        )

    FROM staging.stg_order_payments AS s
    JOIN raw.order_payments AS r
        ON s.order_id = r.order_id
       AND s.payment_sequential = r.payment_sequential

    UNION ALL

    -- 4. CUSTOMERS
    SELECT
        'stg_customers',
        99441::BIGINT,
        COUNT(*),

        COUNT(*) FILTER (
            WHERE ROW(
                s.customer_unique_id,
                s.customer_zip_code_prefix,
                s.customer_city,
                s.customer_state
            ) IS DISTINCT FROM ROW(
                r.customer_unique_id,
                NULLIF(BTRIM(r.customer_zip_code_prefix), ''),
                NULLIF(LOWER(BTRIM(r.customer_city)), ''),
                NULLIF(UPPER(BTRIM(r.customer_state)), '')
            )
        )

    FROM staging.stg_customers AS s
    JOIN raw.customers AS r
        ON s.customer_id = r.customer_id

    UNION ALL

    -- 5. PRODUCTS
    SELECT
        'stg_products',
        32951::BIGINT,
        COUNT(*),

        COUNT(*) FILTER (
            WHERE ROW(
                s.product_category_name_pt,
                s.product_category_name_en,
                s.category_display_name,
                s.product_name_length,
                s.product_description_length,
                s.product_photos_qty,
                s.product_weight_g,
                s.product_length_cm,
                s.product_height_cm,
                s.product_width_cm
            ) IS DISTINCT FROM ROW(
                NULLIF(LOWER(BTRIM(r.product_category_name)), ''),
                NULLIF(LOWER(BTRIM(t.product_category_name_english)), ''),
                COALESCE(
                    NULLIF(LOWER(BTRIM(t.product_category_name_english)), ''),
                    NULLIF(LOWER(BTRIM(r.product_category_name)), ''),
                    'Uncategorized'
                ),
                r.product_name_lenght,
                r.product_description_lenght,
                r.product_photos_qty,
                r.product_weight_g,
                r.product_length_cm,
                r.product_height_cm,
                r.product_width_cm
            )
        )

    FROM staging.stg_products AS s
    JOIN raw.products AS r
        ON s.product_id = r.product_id

    LEFT JOIN raw.category_translation AS t
        ON NULLIF(LOWER(BTRIM(r.product_category_name)), '') =
           NULLIF(LOWER(BTRIM(t.product_category_name)), '')

    UNION ALL

    -- 6. SELLERS
    SELECT
        'stg_sellers',
        3095::BIGINT,
        COUNT(*),

        COUNT(*) FILTER (
            WHERE ROW(
                s.seller_zip_code_prefix,
                s.seller_city,
                s.seller_state
            ) IS DISTINCT FROM ROW(
                NULLIF(BTRIM(r.seller_zip_code_prefix), ''),
                NULLIF(LOWER(BTRIM(r.seller_city)), ''),
                NULLIF(UPPER(BTRIM(r.seller_state)), '')
            )
        )

    FROM staging.stg_sellers AS s
    JOIN raw.sellers AS r
        ON s.seller_id = r.seller_id

    UNION ALL

    -- 7. ORDER REVIEWS
    SELECT
        'stg_order_reviews',
        99224::BIGINT,
        COUNT(*),

        COUNT(*) FILTER (
            WHERE ROW(
                s.review_score,
                s.review_comment_title,
                s.review_comment_message,
                s.review_creation_timestamp,
                s.review_answer_timestamp
            ) IS DISTINCT FROM ROW(
                r.review_score,
                NULLIF(BTRIM(r.review_comment_title), ''),
                NULLIF(BTRIM(r.review_comment_message), ''),
                NULLIF(BTRIM(r.review_creation_date), '')::TIMESTAMP,
                NULLIF(BTRIM(r.review_answer_timestamp), '')::TIMESTAMP
            )
        )

    FROM staging.stg_order_reviews AS s
    JOIN raw.order_reviews AS r
        ON s.review_id = r.review_id
       AND s.order_id = r.order_id

)

SELECT
    model_name,
    expected_rows,
    checked_rows,
    inconsistent_rows,

    CASE
        WHEN checked_rows = expected_rows
         AND inconsistent_rows = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS audit_status

FROM comparisons

ORDER BY model_name;
