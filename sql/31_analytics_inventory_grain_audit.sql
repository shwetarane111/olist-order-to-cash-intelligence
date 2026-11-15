
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 6.4 - TASK 1
-- FILE: 31_analytics_inventory_grain_audit.sql
-- =====================================================

-- CHECK A: Table structure and primary keys

WITH expected (
    model_name,
    expected_columns,
    expected_primary_key
) AS (

    VALUES
        ('dim_order_status', 2,
            ARRAY['order_status']::TEXT[]),

        ('dim_product', 16,
            ARRAY['product_id']::TEXT[]),

        ('dim_seller', 18,
            ARRAY['seller_id']::TEXT[]),

        ('dim_customer', 5,
            ARRAY['customer_unique_id']::TEXT[]),

        ('dim_customer_geography', 19,
            ARRAY['customer_location_key']::TEXT[]),

        ('dim_purchase_date', 14,
            ARRAY['date']::TEXT[]),

        ('dim_delivery_date', 14,
            ARRAY['date']::TEXT[]),

        ('dim_review_date', 14,
            ARRAY['date']::TEXT[]),

        ('fact_orders', 32,
            ARRAY['order_id']::TEXT[]),

        ('fact_order_items', 13,
            ARRAY['order_id', 'order_item_id']::TEXT[]),

        ('fact_payments', 14,
            ARRAY['order_id', 'payment_sequential']::TEXT[]),

        ('fact_order_reviews', 17,
            ARRAY['review_id', 'order_id']::TEXT[])
),

inventory AS (

    SELECT
        e.model_name,
        e.expected_columns,
        e.expected_primary_key,

        c.relkind,

        cols.actual_columns,
        pk.actual_primary_key

    FROM expected AS e

    LEFT JOIN pg_catalog.pg_namespace AS n
        ON n.nspname = 'analytics'

    LEFT JOIN pg_catalog.pg_class AS c
        ON c.relnamespace = n.oid
       AND c.relname = e.model_name

    LEFT JOIN LATERAL (

        SELECT
            COUNT(*) AS actual_columns

        FROM pg_catalog.pg_attribute AS a

        WHERE a.attrelid = c.oid
          AND a.attnum > 0
          AND NOT a.attisdropped

    ) AS cols ON TRUE

    LEFT JOIN LATERAL (

        SELECT
            ARRAY_AGG(
                a.attname::TEXT
                ORDER BY k.position
            ) AS actual_primary_key

        FROM pg_catalog.pg_constraint AS con

        CROSS JOIN LATERAL
            UNNEST(con.conkey)
            WITH ORDINALITY
            AS k(attribute_number, position)

        JOIN pg_catalog.pg_attribute AS a
            ON a.attrelid = con.conrelid
           AND a.attnum = k.attribute_number

        WHERE con.conrelid = c.oid
          AND con.contype = 'p'

    ) AS pk ON TRUE

)

SELECT
    model_name,

    CASE
        WHEN relkind = 'r'
        THEN 'TABLE'
        ELSE 'MISSING_OR_OTHER'
    END AS object_type,

    expected_columns,
    actual_columns,

    expected_primary_key,
    actual_primary_key,

    CASE
        WHEN relkind = 'r'
         AND actual_columns = expected_columns
         AND actual_primary_key =
             expected_primary_key
        THEN 'PASS'
        ELSE 'FAIL'
    END AS audit_status

FROM inventory

ORDER BY model_name;


-- =====================================================
-- CHECK B: Row counts and grain integrity
-- =====================================================

WITH actual AS (

    SELECT
        'dim_order_status' AS model_name,
        COUNT(*) AS actual_rows,
        COUNT(DISTINCT order_status) AS unique_keys,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_status), '') IS NULL
        ) AS missing_keys
    FROM analytics.dim_order_status

    UNION ALL

    SELECT
        'dim_product',
        COUNT(*),
        COUNT(DISTINCT product_id),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(product_id), '') IS NULL
        )
    FROM analytics.dim_product

    UNION ALL

    SELECT
        'dim_seller',
        COUNT(*),
        COUNT(DISTINCT seller_id),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(seller_id), '') IS NULL
        )
    FROM analytics.dim_seller

    UNION ALL

    SELECT
        'dim_customer',
        COUNT(*),
        COUNT(DISTINCT customer_unique_id),
        COUNT(*) FILTER (
            WHERE NULLIF(
                BTRIM(customer_unique_id), ''
            ) IS NULL
        )
    FROM analytics.dim_customer

    UNION ALL

    SELECT
        'dim_customer_geography',
        COUNT(*),
        COUNT(DISTINCT customer_location_key),
        COUNT(*) FILTER (
            WHERE NULLIF(
                BTRIM(customer_location_key), ''
            ) IS NULL
        )
    FROM analytics.dim_customer_geography

    UNION ALL

    SELECT
        'dim_purchase_date',
        COUNT(*),
        COUNT(DISTINCT date),
        COUNT(*) FILTER (
            WHERE date IS NULL
        )
    FROM analytics.dim_purchase_date

    UNION ALL

    SELECT
        'dim_delivery_date',
        COUNT(*),
        COUNT(DISTINCT date),
        COUNT(*) FILTER (
            WHERE date IS NULL
        )
    FROM analytics.dim_delivery_date

    UNION ALL

    SELECT
        'dim_review_date',
        COUNT(*),
        COUNT(DISTINCT date),
        COUNT(*) FILTER (
            WHERE date IS NULL
        )
    FROM analytics.dim_review_date

    UNION ALL

    SELECT
        'fact_orders',
        COUNT(*),
        COUNT(DISTINCT order_id),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_id), '') IS NULL
        )
    FROM analytics.fact_orders

    UNION ALL

    SELECT
        'fact_order_items',
        COUNT(*),
        COUNT(DISTINCT (order_id, order_item_id)),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_id), '') IS NULL
               OR order_item_id IS NULL
        )
    FROM analytics.fact_order_items

    UNION ALL

    SELECT
        'fact_payments',
        COUNT(*),
        COUNT(DISTINCT (order_id, payment_sequential)),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_id), '') IS NULL
               OR payment_sequential IS NULL
        )
    FROM analytics.fact_payments

    UNION ALL

    SELECT
        'fact_order_reviews',
        COUNT(*),
        COUNT(DISTINCT (review_id, order_id)),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(review_id), '') IS NULL
               OR NULLIF(BTRIM(order_id), '') IS NULL
        )
    FROM analytics.fact_order_reviews

),

expected (model_name, expected_rows) AS (

    VALUES
        ('dim_order_status', 8::BIGINT),
        ('dim_product', 32951::BIGINT),
        ('dim_seller', 3095::BIGINT),
        ('dim_customer', 96096::BIGINT),
        ('dim_customer_geography', 15034::BIGINT),
        ('dim_purchase_date', 774::BIGINT),
        ('dim_delivery_date', 737::BIGINT),
        ('dim_review_date', 699::BIGINT),

        ('fact_orders', 99441::BIGINT),
        ('fact_order_items', 112650::BIGINT),
        ('fact_payments', 103886::BIGINT),
        ('fact_order_reviews', 99224::BIGINT)

),

audit AS (

    SELECT
        e.model_name,
        e.expected_rows,

        a.actual_rows,
        a.unique_keys,
        a.missing_keys,

        CASE
            WHEN e.expected_rows = a.actual_rows
             AND a.actual_rows = a.unique_keys
             AND a.missing_keys = 0
            THEN 'PASS'
            ELSE 'FAIL'
        END AS audit_status

    FROM expected AS e

    LEFT JOIN actual AS a
        ON e.model_name = a.model_name

)

SELECT *

FROM (

    SELECT
        model_name,
        expected_rows,
        actual_rows,
        unique_keys,
        missing_keys,
        audit_status

    FROM audit

    UNION ALL

    SELECT
        'TOTAL',
        SUM(expected_rows),
        SUM(actual_rows),
        SUM(unique_keys),
        SUM(missing_keys),

        CASE
            WHEN COUNT(*) = 12
             AND BOOL_AND(audit_status = 'PASS')
            THEN 'PASS'
            ELSE 'FAIL'
        END

    FROM audit

) AS results

ORDER BY
    CASE
        WHEN model_name = 'TOTAL' THEN 1
        ELSE 0
    END,
    model_name;
