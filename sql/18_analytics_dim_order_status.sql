
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 6.2 - TASK 1
-- MODEL: analytics.dim_order_status
-- SOURCE: staging.stg_orders
-- =====================================================

-- CHECK A1: Source readiness

SELECT
    COUNT(*) AS total_orders,

    COUNT(DISTINCT order_status)
        AS distinct_statuses,

    COUNT(*) FILTER (
        WHERE order_status IS NULL
           OR BTRIM(order_status) = ''
    ) AS missing_statuses

FROM staging.stg_orders;


-- CHECK A2: Inspect every source order status

SELECT
    order_status,
    COUNT(*) AS order_count

FROM staging.stg_orders

GROUP BY order_status

ORDER BY order_count DESC, order_status;


-- =====================================================
-- CHECK B: Create and populate the dimension
-- =====================================================

BEGIN;

CREATE TABLE IF NOT EXISTS analytics.dim_order_status (

    order_status TEXT PRIMARY KEY,

    status_label TEXT NOT NULL

);

INSERT INTO analytics.dim_order_status (
    order_status,
    status_label
)

SELECT DISTINCT

    order_status,

    INITCAP(
        REPLACE(order_status, '_', ' ')
    ) AS status_label

FROM staging.stg_orders

WHERE order_status IS NOT NULL
  AND BTRIM(order_status) <> ''

ON CONFLICT (order_status)

DO UPDATE SET
    status_label = EXCLUDED.status_label;

COMMIT;


-- =====================================================
-- CHECK C1: Dimension structure and quality
-- =====================================================

SELECT
    COUNT(*) AS dimension_rows,

    COUNT(DISTINCT order_status)
        AS unique_statuses,

    COUNT(*) FILTER (
        WHERE order_status IS NULL
           OR BTRIM(order_status) = ''
    ) AS missing_status_keys,

    COUNT(*) FILTER (
        WHERE status_label IS NULL
           OR BTRIM(status_label) = ''
    ) AS missing_labels,

    COUNT(*) FILTER (
        WHERE status_label IS DISTINCT FROM
              INITCAP(REPLACE(order_status, '_', ' '))
    ) AS inconsistent_labels

FROM analytics.dim_order_status;


-- =====================================================
-- CHECK C2: Source-to-dimension coverage
-- =====================================================

WITH source_statuses AS (

    SELECT DISTINCT order_status
    FROM staging.stg_orders

),

source_only AS (

    SELECT order_status
    FROM source_statuses

    EXCEPT

    SELECT order_status
    FROM analytics.dim_order_status

),

dimension_only AS (

    SELECT order_status
    FROM analytics.dim_order_status

    EXCEPT

    SELECT order_status
    FROM source_statuses

)

SELECT
    'SOURCE_ONLY' AS issue_type,
    order_status

FROM source_only

UNION ALL

SELECT
    'DIMENSION_ONLY',
    order_status

FROM dimension_only;


-- =====================================================
-- CHECK C3: Safe join validation
-- =====================================================

SELECT
    (
        SELECT COUNT(*)
        FROM staging.stg_orders
    ) AS source_order_rows,

    COUNT(*) AS rows_after_join,

    COUNT(*) FILTER (
        WHERE d.order_status IS NULL
    ) AS unmatched_order_rows

FROM staging.stg_orders AS o

LEFT JOIN analytics.dim_order_status AS d
    ON o.order_status = d.order_status;
