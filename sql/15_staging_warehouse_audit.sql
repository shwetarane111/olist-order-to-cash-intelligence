
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 5.2 - TASK 1
-- STAGING completeness and structure audit
-- =====================================================

WITH expected (
    model_name,
    source_table,
    expected_rows,
    expected_columns
) AS (
    VALUES
        ('stg_orders', 'orders', 99441::BIGINT, 8),
        ('stg_order_items', 'order_items', 112650::BIGINT, 8),
        ('stg_order_payments', 'order_payments', 103886::BIGINT, 9),
        ('stg_customers', 'customers', 99441::BIGINT, 7),
        ('stg_products', 'products', 32951::BIGINT, 17),
        ('stg_sellers', 'sellers', 3095::BIGINT, 6),
        ('stg_order_reviews', 'order_reviews', 99224::BIGINT, 11),
        ('stg_geolocation', 'geolocation', 1000163::BIGINT, 9)
),

raw_counts AS (
    SELECT 'orders' AS source_table, COUNT(*) AS rows
    FROM raw.orders

    UNION ALL
    SELECT 'order_items', COUNT(*) FROM raw.order_items

    UNION ALL
    SELECT 'order_payments', COUNT(*) FROM raw.order_payments

    UNION ALL
    SELECT 'customers', COUNT(*) FROM raw.customers

    UNION ALL
    SELECT 'products', COUNT(*) FROM raw.products

    UNION ALL
    SELECT 'sellers', COUNT(*) FROM raw.sellers

    UNION ALL
    SELECT 'order_reviews', COUNT(*) FROM raw.order_reviews

    UNION ALL
    SELECT 'geolocation', COUNT(*) FROM raw.geolocation
),

staging_counts AS (
    SELECT 'stg_orders' AS model_name, COUNT(*) AS rows
    FROM staging.stg_orders

    UNION ALL
    SELECT 'stg_order_items', COUNT(*)
    FROM staging.stg_order_items

    UNION ALL
    SELECT 'stg_order_payments', COUNT(*)
    FROM staging.stg_order_payments

    UNION ALL
    SELECT 'stg_customers', COUNT(*)
    FROM staging.stg_customers

    UNION ALL
    SELECT 'stg_products', COUNT(*)
    FROM staging.stg_products

    UNION ALL
    SELECT 'stg_sellers', COUNT(*)
    FROM staging.stg_sellers

    UNION ALL
    SELECT 'stg_order_reviews', COUNT(*)
    FROM staging.stg_order_reviews

    UNION ALL
    SELECT 'stg_geolocation', COUNT(*)
    FROM staging.stg_geolocation
),

column_counts AS (
    SELECT
        table_name AS model_name,
        COUNT(*) AS columns
    FROM information_schema.columns
    WHERE table_schema = 'staging'
    GROUP BY table_name
),

audit AS (
    SELECT
        e.model_name,
        e.expected_rows,
        r.rows AS raw_rows,
        s.rows AS staging_rows,
        e.expected_columns,
        c.columns AS actual_columns,

        CASE
            WHEN e.expected_rows = r.rows
             AND r.rows = s.rows
             AND e.expected_columns = c.columns
            THEN 'PASS'
            ELSE 'FAIL'
        END AS audit_status

    FROM expected e

    LEFT JOIN raw_counts r
        ON e.source_table = r.source_table

    LEFT JOIN staging_counts s
        ON e.model_name = s.model_name

    LEFT JOIN column_counts c
        ON e.model_name = c.model_name
)

SELECT *
FROM (
    SELECT
        model_name,
        expected_rows,
        raw_rows,
        staging_rows,
        expected_columns,
        actual_columns,
        audit_status
    FROM audit

    UNION ALL

    SELECT
        'TOTAL',
        SUM(expected_rows),
        SUM(raw_rows),
        SUM(staging_rows),
        SUM(expected_columns),
        SUM(actual_columns),

        CASE
            WHEN COUNT(*) = 8
             AND BOOL_AND(audit_status = 'PASS')
            THEN 'PASS'
            ELSE 'FAIL'
        END

    FROM audit
) results

ORDER BY
    CASE WHEN model_name = 'TOTAL' THEN 1 ELSE 0 END,
    model_name;


-- =====================================================
-- CHECK B: Geographic reference completeness
-- =====================================================

SELECT
    COUNT(*) AS total_zip_records,

    COUNT(DISTINCT geolocation_zip_code_prefix)
        AS unique_zip_prefixes,

    SUM(geo_source_row_count)
        AS represented_geolocation_rows,

    COUNT(*) FILTER (
        WHERE representative_latitude IS NULL
           OR representative_longitude IS NULL
    ) AS missing_coordinates,

    COUNT(*) FILTER (
        WHERE has_conflicting_city_state_labels
    ) AS conflicting_location_zips,

    COUNT(*) FILTER (
        WHERE is_outside_broad_brazil_box
    ) AS selected_coordinate_outliers

FROM staging.ref_zip_geolocation;


-- =====================================================
-- CHECK C: Verify STAGING objects
-- =====================================================

SELECT
    n.nspname AS schema_name,
    c.relname AS object_name,

    CASE c.relkind
        WHEN 'v' THEN 'VIEW'
        WHEN 'm' THEN 'MATERIALIZED VIEW'
    END AS object_type

FROM pg_catalog.pg_class c

JOIN pg_catalog.pg_namespace n
    ON c.relnamespace = n.oid

WHERE n.nspname = 'staging'
  AND c.relkind IN ('v', 'm')

ORDER BY object_type, object_name;
