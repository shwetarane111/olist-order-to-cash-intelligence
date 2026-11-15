
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 6.2 - TASK 9
-- FILE: 26_analytics_dimensions_audit.sql
-- PURPOSE: Final dimension validation
-- =====================================================

-- CHECK A: Dimension inventory, grain and structure

WITH actual AS (

    SELECT
        'dim_order_status' AS model_name,
        COUNT(*) AS actual_rows,
        COUNT(DISTINCT order_status) AS unique_keys
    FROM analytics.dim_order_status

    UNION ALL

    SELECT
        'dim_product',
        COUNT(*),
        COUNT(DISTINCT product_id)
    FROM analytics.dim_product

    UNION ALL

    SELECT
        'dim_seller',
        COUNT(*),
        COUNT(DISTINCT seller_id)
    FROM analytics.dim_seller

    UNION ALL

    SELECT
        'dim_customer',
        COUNT(*),
        COUNT(DISTINCT customer_unique_id)
    FROM analytics.dim_customer

    UNION ALL

    SELECT
        'dim_customer_geography',
        COUNT(*),
        COUNT(DISTINCT customer_location_key)
    FROM analytics.dim_customer_geography

    UNION ALL

    SELECT
        'dim_purchase_date',
        COUNT(*),
        COUNT(DISTINCT date)
    FROM analytics.dim_purchase_date

    UNION ALL

    SELECT
        'dim_delivery_date',
        COUNT(*),
        COUNT(DISTINCT date)
    FROM analytics.dim_delivery_date

    UNION ALL

    SELECT
        'dim_review_date',
        COUNT(*),
        COUNT(DISTINCT date)
    FROM analytics.dim_review_date

),

expected (
    model_name,
    expected_rows,
    expected_columns
) AS (

    VALUES
        ('dim_order_status', 8::BIGINT, 2),
        ('dim_product', 32951::BIGINT, 16),
        ('dim_seller', 3095::BIGINT, 18),
        ('dim_customer', 96096::BIGINT, 5),
        ('dim_customer_geography', 15034::BIGINT, 19),
        ('dim_purchase_date', 774::BIGINT, 14),
        ('dim_delivery_date', 737::BIGINT, 14),
        ('dim_review_date', 699::BIGINT, 14)

),

column_counts AS (

    SELECT
        table_name AS model_name,
        COUNT(*) AS actual_columns

    FROM information_schema.columns

    WHERE table_schema = 'analytics'

    GROUP BY table_name

),

audit AS (

    SELECT
        e.model_name,
        e.expected_rows,
        a.actual_rows,
        a.unique_keys,
        e.expected_columns,
        c.actual_columns,

        CASE
            WHEN e.expected_rows = a.actual_rows
             AND a.actual_rows = a.unique_keys
             AND e.expected_columns = c.actual_columns
            THEN 'PASS'
            ELSE 'FAIL'
        END AS audit_status

    FROM expected AS e

    LEFT JOIN actual AS a
        ON e.model_name = a.model_name

    LEFT JOIN column_counts AS c
        ON e.model_name = c.model_name

)

SELECT *
FROM (

    SELECT
        model_name,
        expected_rows,
        actual_rows,
        unique_keys,
        expected_columns,
        actual_columns,
        audit_status

    FROM audit

    UNION ALL

    SELECT
        'TOTAL',
        SUM(expected_rows),
        SUM(actual_rows),
        SUM(unique_keys),
        SUM(expected_columns),
        SUM(actual_columns),

        CASE
            WHEN COUNT(*) = 8
             AND BOOL_AND(audit_status = 'PASS')
            THEN 'PASS'
            ELSE 'FAIL'
        END

    FROM audit

) AS results

ORDER BY
    CASE WHEN model_name = 'TOTAL' THEN 1 ELSE 0 END,
    model_name;


-- =====================================================
-- CHECK B: Integrated fact-to-dimension join audit
-- =====================================================

WITH order_context AS (

    SELECT
        o.order_id,

        (
            c.customer_id IS NULL

            OR dc.customer_unique_id IS NULL

            OR ds.order_status IS NULL

            OR dg.customer_location_key IS NULL

            OR pd.date IS NULL

            OR (
                o.order_delivered_customer_date IS NOT NULL
                AND dd.date IS NULL
            )

        ) AS has_context_gap

    FROM staging.stg_orders AS o

    LEFT JOIN staging.stg_customers AS c
        ON o.customer_id = c.customer_id

    LEFT JOIN analytics.dim_customer AS dc
        ON c.customer_unique_id = dc.customer_unique_id

    LEFT JOIN analytics.dim_order_status AS ds
        ON o.order_status = ds.order_status

    LEFT JOIN analytics.dim_customer_geography AS dg
        ON dg.customer_location_key = MD5(
            JSONB_BUILD_ARRAY(
                c.customer_zip_code_prefix,
                c.customer_city,
                c.customer_state
            )::TEXT
        )

    LEFT JOIN analytics.dim_purchase_date AS pd
        ON o.order_purchase_timestamp::DATE = pd.date

    LEFT JOIN analytics.dim_delivery_date AS dd
        ON o.order_delivered_customer_date::DATE = dd.date

),

fact_path_checks AS (

    -- Planned Fact 1: Orders

    SELECT
        'fact_orders' AS fact_model,
        99441::BIGINT AS expected_rows,

        COUNT(*) AS joined_rows,

        COUNT(DISTINCT oc.order_id)
            AS distinct_grain_keys,

        COUNT(*) FILTER (
            WHERE oc.has_context_gap
        ) AS rows_with_dimension_gaps

    FROM order_context AS oc

    UNION ALL

    -- Planned Fact 2: Order Items

    SELECT
        'fact_order_items',
        112650::BIGINT,

        COUNT(*),

        COUNT(DISTINCT (
            oi.order_id,
            oi.order_item_id
        )),

        COUNT(*) FILTER (
            WHERE oc.order_id IS NULL
               OR oc.has_context_gap
               OR p.product_id IS NULL
               OR s.seller_id IS NULL
        )

    FROM staging.stg_order_items AS oi

    LEFT JOIN order_context AS oc
        ON oi.order_id = oc.order_id

    LEFT JOIN analytics.dim_product AS p
        ON oi.product_id = p.product_id

    LEFT JOIN analytics.dim_seller AS s
        ON oi.seller_id = s.seller_id

    UNION ALL

    -- Planned Fact 3: Payments

    SELECT
        'fact_payments',
        103886::BIGINT,

        COUNT(*),

        COUNT(DISTINCT (
            p.order_id,
            p.payment_sequential
        )),

        COUNT(*) FILTER (
            WHERE oc.order_id IS NULL
               OR oc.has_context_gap
        )

    FROM staging.stg_order_payments AS p

    LEFT JOIN order_context AS oc
        ON p.order_id = oc.order_id

    UNION ALL

    -- Planned Fact 4: Reviews

    SELECT
        'fact_order_reviews',
        99224::BIGINT,

        COUNT(*),

        COUNT(DISTINCT (
            r.review_id,
            r.order_id
        )),

        COUNT(*) FILTER (
            WHERE oc.order_id IS NULL
               OR oc.has_context_gap
               OR rd.date IS NULL
        )

    FROM staging.stg_order_reviews AS r

    LEFT JOIN order_context AS oc
        ON r.order_id = oc.order_id

    LEFT JOIN analytics.dim_review_date AS rd
        ON r.review_creation_timestamp::DATE = rd.date

)

SELECT
    fact_model,
    expected_rows,
    joined_rows,
    distinct_grain_keys,
    rows_with_dimension_gaps,

    CASE
        WHEN expected_rows = joined_rows
         AND joined_rows = distinct_grain_keys
         AND rows_with_dimension_gaps = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS audit_status

FROM fact_path_checks

ORDER BY fact_model;
