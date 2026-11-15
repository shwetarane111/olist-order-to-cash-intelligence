
-- =====================================================
-- STEP 4.6 - TASK 2
-- CHECK A: Logical primary-key integrity
-- =====================================================

WITH key_checks AS (

    SELECT
        'orders' AS table_name,
        COUNT(*) AS total_rows,
        COUNT(DISTINCT order_id) AS distinct_keys,
        COUNT(*) FILTER (
            WHERE order_id IS NULL
               OR TRIM(order_id) = ''
        ) AS missing_key_rows
    FROM raw.orders

    UNION ALL

    SELECT
        'order_items',
        COUNT(*),
        COUNT(DISTINCT (order_id, order_item_id)),
        COUNT(*) FILTER (
            WHERE order_id IS NULL
               OR TRIM(order_id) = ''
               OR order_item_id IS NULL
        )
    FROM raw.order_items

    UNION ALL

    SELECT
        'order_payments',
        COUNT(*),
        COUNT(DISTINCT (order_id, payment_sequential)),
        COUNT(*) FILTER (
            WHERE order_id IS NULL
               OR TRIM(order_id) = ''
               OR payment_sequential IS NULL
        )
    FROM raw.order_payments

    UNION ALL

    SELECT
        'customers',
        COUNT(*),
        COUNT(DISTINCT customer_id),
        COUNT(*) FILTER (
            WHERE customer_id IS NULL
               OR TRIM(customer_id) = ''
        )
    FROM raw.customers

    UNION ALL

    SELECT
        'products',
        COUNT(*),
        COUNT(DISTINCT product_id),
        COUNT(*) FILTER (
            WHERE product_id IS NULL
               OR TRIM(product_id) = ''
        )
    FROM raw.products

    UNION ALL

    SELECT
        'sellers',
        COUNT(*),
        COUNT(DISTINCT seller_id),
        COUNT(*) FILTER (
            WHERE seller_id IS NULL
               OR TRIM(seller_id) = ''
        )
    FROM raw.sellers

    UNION ALL

    SELECT
        'order_reviews',
        COUNT(*),
        COUNT(DISTINCT (review_id, order_id)),
        COUNT(*) FILTER (
            WHERE review_id IS NULL
               OR TRIM(review_id) = ''
               OR order_id IS NULL
               OR TRIM(order_id) = ''
        )
    FROM raw.order_reviews

    UNION ALL

    SELECT
        'category_translation',
        COUNT(*),
        COUNT(DISTINCT product_category_name),
        COUNT(*) FILTER (
            WHERE product_category_name IS NULL
               OR TRIM(product_category_name) = ''
        )
    FROM raw.category_translation

)

SELECT
    table_name,
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

ORDER BY table_name;


-- =====================================================
-- CHECK B: Cross-table referential integrity
-- =====================================================

WITH relationship_checks AS (

    -- 1. Orders -> Customers
    SELECT
        'Orders -> Customers' AS relationship,
        COUNT(*) AS child_rows,
        COUNT(*) FILTER (
            WHERE c.customer_id IS NULL
        ) AS unmatched_rows

    FROM raw.orders AS o
    LEFT JOIN raw.customers AS c
        ON o.customer_id = c.customer_id

    UNION ALL

    -- 2. Order Items -> Orders
    SELECT
        'Order Items -> Orders',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE o.order_id IS NULL
        )

    FROM raw.order_items AS oi
    LEFT JOIN raw.orders AS o
        ON oi.order_id = o.order_id

    UNION ALL

    -- 3. Order Items -> Products
    SELECT
        'Order Items -> Products',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE p.product_id IS NULL
        )

    FROM raw.order_items AS oi
    LEFT JOIN raw.products AS p
        ON oi.product_id = p.product_id

    UNION ALL

    -- 4. Order Items -> Sellers
    SELECT
        'Order Items -> Sellers',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE s.seller_id IS NULL
        )

    FROM raw.order_items AS oi
    LEFT JOIN raw.sellers AS s
        ON oi.seller_id = s.seller_id

    UNION ALL

    -- 5. Order Payments -> Orders
    SELECT
        'Order Payments -> Orders',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE o.order_id IS NULL
        )

    FROM raw.order_payments AS pay
    LEFT JOIN raw.orders AS o
        ON pay.order_id = o.order_id

    UNION ALL

    -- 6. Order Reviews -> Orders
    SELECT
        'Order Reviews -> Orders',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE o.order_id IS NULL
        )

    FROM raw.order_reviews AS r
    LEFT JOIN raw.orders AS o
        ON r.order_id = o.order_id

)

SELECT
    relationship,
    child_rows,
    unmatched_rows,

    CASE
        WHEN unmatched_rows = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS audit_status

FROM relationship_checks

ORDER BY relationship;


-- =====================================================
-- CHECK C: Orders without related source records
-- Informational findings, not automatic failures
-- =====================================================

SELECT

    (
        SELECT COUNT(*)
        FROM raw.orders AS o
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.order_items AS oi
            WHERE oi.order_id = o.order_id
        )
    ) AS orders_without_items,

    (
        SELECT COUNT(*)
        FROM raw.orders AS o
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.order_payments AS p
            WHERE p.order_id = o.order_id
        )
    ) AS orders_without_payments,

    (
        SELECT COUNT(*)
        FROM raw.orders AS o
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.order_reviews AS r
            WHERE r.order_id = o.order_id
        )
    ) AS orders_without_reviews;
