
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 6.2 - TASK 4
-- MODEL: analytics.dim_customer
-- =====================================================

-- CHECK A: Customer identity source readiness

WITH identity_orders AS (

    SELECT
        c.customer_unique_id,

        COUNT(*) AS observed_order_count,

        MIN(o.order_purchase_timestamp)
            AS first_purchase,

        MAX(o.order_purchase_timestamp)
            AS last_purchase

    FROM staging.stg_customers AS c

    INNER JOIN staging.stg_orders AS o
        ON c.customer_id = o.customer_id

    GROUP BY c.customer_unique_id

)

SELECT
    COUNT(*) AS distinct_customer_identities,

    SUM(observed_order_count)
        AS linked_order_records,

    COUNT(*) FILTER (
        WHERE observed_order_count > 1
    ) AS multi_order_identities,

    MAX(observed_order_count)
        AS max_orders_per_identity,

    SUM(observed_order_count - 1)
        AS additional_order_records,

    COUNT(*) FILTER (
        WHERE customer_unique_id IS NULL
           OR BTRIM(customer_unique_id) = ''
    ) AS missing_identity_keys,

    COUNT(*) FILTER (
        WHERE first_purchase IS NULL
           OR last_purchase IS NULL
    ) AS identities_missing_purchase_dates

FROM identity_orders;


-- =====================================================
-- CHECK B: Create analytics.dim_customer
-- =====================================================

BEGIN;

CREATE TABLE analytics.dim_customer (

    customer_unique_id TEXT PRIMARY KEY,

    first_observed_purchase_timestamp
        TIMESTAMP WITHOUT TIME ZONE NOT NULL,

    last_observed_purchase_timestamp
        TIMESTAMP WITHOUT TIME ZONE NOT NULL,

    observed_order_count INTEGER NOT NULL,

    has_multiple_observed_orders BOOLEAN NOT NULL,

    CONSTRAINT chk_customer_order_count
        CHECK (observed_order_count >= 1),

    CONSTRAINT chk_customer_purchase_dates
        CHECK (
            last_observed_purchase_timestamp >=
            first_observed_purchase_timestamp
        ),

    CONSTRAINT chk_customer_repeat_indicator
        CHECK (
            has_multiple_observed_orders =
            (observed_order_count > 1)
        )

);

INSERT INTO analytics.dim_customer (

    customer_unique_id,
    first_observed_purchase_timestamp,
    last_observed_purchase_timestamp,
    observed_order_count,
    has_multiple_observed_orders

)

SELECT
    c.customer_unique_id,

    MIN(o.order_purchase_timestamp),

    MAX(o.order_purchase_timestamp),

    COUNT(*)::INTEGER,

    (COUNT(*) > 1)

FROM staging.stg_customers AS c

INNER JOIN staging.stg_orders AS o
    ON c.customer_id = o.customer_id

GROUP BY c.customer_unique_id;

COMMIT;


-- =====================================================
-- CHECK C1: Customer dimension quality
-- =====================================================

SELECT
    COUNT(*) AS total_customer_identities,

    COUNT(DISTINCT customer_unique_id)
        AS unique_identity_keys,

    SUM(observed_order_count)
        AS total_observed_orders,

    COUNT(*) FILTER (
        WHERE has_multiple_observed_orders
    ) AS multi_order_identities,

    MAX(observed_order_count)
        AS max_orders_per_identity,

    SUM(observed_order_count - 1)
        AS additional_order_records,

    COUNT(*) FILTER (
        WHERE first_observed_purchase_timestamp IS NULL
           OR last_observed_purchase_timestamp IS NULL
    ) AS missing_purchase_dates,

    COUNT(*) FILTER (
        WHERE last_observed_purchase_timestamp <
              first_observed_purchase_timestamp
    ) AS invalid_date_ranges,

    COUNT(*) FILTER (
        WHERE has_multiple_observed_orders
              IS DISTINCT FROM
              (observed_order_count > 1)
    ) AS inconsistent_repeat_indicators

FROM analytics.dim_customer;


-- =====================================================
-- CHECK C2: Source-to-dimension fidelity
-- =====================================================

WITH expected AS (

    SELECT
        c.customer_unique_id,

        MIN(o.order_purchase_timestamp)
            AS first_purchase,

        MAX(o.order_purchase_timestamp)
            AS last_purchase,

        COUNT(*)::INTEGER
            AS observed_order_count,

        (COUNT(*) > 1)
            AS has_multiple_observed_orders

    FROM staging.stg_customers AS c

    INNER JOIN staging.stg_orders AS o
        ON c.customer_id = o.customer_id

    GROUP BY c.customer_unique_id

)

SELECT
    COUNT(*) FILTER (
        WHERE d.customer_unique_id IS NULL
    ) AS missing_dimension_identities,

    COUNT(*) FILTER (
        WHERE e.customer_unique_id IS NULL
    ) AS unexpected_dimension_identities,

    COUNT(*) FILTER (
        WHERE e.customer_unique_id IS NOT NULL
          AND d.customer_unique_id IS NOT NULL
          AND ROW(
              d.first_observed_purchase_timestamp,
              d.last_observed_purchase_timestamp,
              d.observed_order_count,
              d.has_multiple_observed_orders
          ) IS DISTINCT FROM ROW(
              e.first_purchase,
              e.last_purchase,
              e.observed_order_count,
              e.has_multiple_observed_orders
          )
    ) AS inconsistent_attribute_rows

FROM expected AS e

FULL OUTER JOIN analytics.dim_customer AS d
    ON e.customer_unique_id = d.customer_unique_id;


-- =====================================================
-- CHECK C3: Customer identity join validation
-- =====================================================

SELECT
    (
        SELECT COUNT(*)
        FROM staging.stg_orders
    ) AS source_order_rows,

    COUNT(*) AS rows_after_join,

    COUNT(DISTINCT o.order_id)
        AS distinct_joined_orders,

    COUNT(*) FILTER (
        WHERE c.customer_id IS NULL
    ) AS orders_without_customer_record,

    COUNT(*) FILTER (
        WHERE d.customer_unique_id IS NULL
    ) AS orders_without_customer_identity

FROM staging.stg_orders AS o

LEFT JOIN staging.stg_customers AS c
    ON o.customer_id = c.customer_id

LEFT JOIN analytics.dim_customer AS d
    ON c.customer_unique_id = d.customer_unique_id;
