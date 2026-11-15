
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- DATABASE: olist_analytics
-- STEP: 4.6 - RAW Warehouse Audit
-- TASK 1: Table and Column Count Verification
-- =====================================================

-- 1. Define expected source baselines
WITH expected AS (
    SELECT *
    FROM (
        VALUES
            ('orders', 99441::BIGINT, 8),
            ('order_items', 112650::BIGINT, 7),
            ('order_payments', 103886::BIGINT, 5),
            ('customers', 99441::BIGINT, 5),
            ('products', 32951::BIGINT, 9),
            ('sellers', 3095::BIGINT, 4),
            ('order_reviews', 99224::BIGINT, 7),
            ('geolocation', 1000163::BIGINT, 5),
            ('category_translation', 71::BIGINT, 2)
    ) AS t(
        table_name,
        expected_rows,
        expected_columns
    )
),

-- 2. Count actual records in PostgreSQL
actual_rows AS (
    SELECT 'orders' AS table_name, COUNT(*) AS row_count
    FROM raw.orders

    UNION ALL
    SELECT 'order_items', COUNT(*)
    FROM raw.order_items

    UNION ALL
    SELECT 'order_payments', COUNT(*)
    FROM raw.order_payments

    UNION ALL
    SELECT 'customers', COUNT(*)
    FROM raw.customers

    UNION ALL
    SELECT 'products', COUNT(*)
    FROM raw.products

    UNION ALL
    SELECT 'sellers', COUNT(*)
    FROM raw.sellers

    UNION ALL
    SELECT 'order_reviews', COUNT(*)
    FROM raw.order_reviews

    UNION ALL
    SELECT 'geolocation', COUNT(*)
    FROM raw.geolocation

    UNION ALL
    SELECT 'category_translation', COUNT(*)
    FROM raw.category_translation
),

-- 3. Count actual columns using PostgreSQL metadata
actual_columns AS (
    SELECT
        table_name,
        COUNT(*)::INTEGER AS column_count
    FROM information_schema.columns
    WHERE table_schema = 'raw'
    GROUP BY table_name
),

-- 4. Compare expected vs actual values
audit_results AS (
    SELECT
        e.table_name,
        e.expected_rows,
        a.row_count AS actual_rows,
        e.expected_columns,
        c.column_count AS actual_columns,

        CASE
            WHEN e.expected_rows = a.row_count
             AND e.expected_columns = c.column_count
            THEN 'PASS'
            ELSE 'FAIL'
        END AS audit_status

    FROM expected AS e

    LEFT JOIN actual_rows AS a
        ON e.table_name = a.table_name

    LEFT JOIN actual_columns AS c
        ON e.table_name = c.table_name
)

-- 5. Show results and warehouse totals
SELECT *
FROM (
    SELECT
        table_name,
        expected_rows,
        actual_rows,
        expected_columns,
        actual_columns,
        audit_status
    FROM audit_results

    UNION ALL

    SELECT
        'TOTAL',
        SUM(expected_rows),
        SUM(actual_rows),
        SUM(expected_columns)::INTEGER,
        SUM(actual_columns)::INTEGER,
        CASE
            WHEN COUNT(*) = 9
             AND BOOL_AND(audit_status = 'PASS')
            THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM audit_results

) AS final_audit

ORDER BY
    CASE WHEN table_name = 'TOTAL' THEN 1 ELSE 0 END,
    table_name;
