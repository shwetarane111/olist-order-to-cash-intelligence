
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 6.4 - TASK 2
-- FILE: 32_analytics_relationship_integrity_audit.sql
-- =====================================================

-- CHECK A: Verify expected foreign-key constraints

WITH expected (
    fact_table,
    fk_name,
    child_column,
    parent_table,
    parent_column
) AS (

    VALUES
    -- fact_orders: 5
    ('fact_orders', 'fk_fact_orders_customer',
     'customer_unique_id', 'dim_customer', 'customer_unique_id'),

    ('fact_orders', 'fk_fact_orders_geography',
     'customer_location_key', 'dim_customer_geography',
     'customer_location_key'),

    ('fact_orders', 'fk_fact_orders_status',
     'order_status', 'dim_order_status', 'order_status'),

    ('fact_orders', 'fk_fact_orders_purchase_date',
     'purchase_date', 'dim_purchase_date', 'date'),

    ('fact_orders', 'fk_fact_orders_delivery_date',
     'delivery_date', 'dim_delivery_date', 'date'),

    -- fact_order_items: 7
    ('fact_order_items', 'fk_fact_items_product',
     'product_id', 'dim_product', 'product_id'),

    ('fact_order_items', 'fk_fact_items_seller',
     'seller_id', 'dim_seller', 'seller_id'),

    ('fact_order_items', 'fk_fact_items_customer',
     'customer_unique_id', 'dim_customer', 'customer_unique_id'),

    ('fact_order_items', 'fk_fact_items_geography',
     'customer_location_key', 'dim_customer_geography',
     'customer_location_key'),

    ('fact_order_items', 'fk_fact_items_status',
     'order_status', 'dim_order_status', 'order_status'),

    ('fact_order_items', 'fk_fact_items_purchase_date',
     'purchase_date', 'dim_purchase_date', 'date'),

    ('fact_order_items', 'fk_fact_items_parent_order',
     'order_id', 'fact_orders', 'order_id'),

    -- fact_payments: 5
    ('fact_payments', 'fk_fact_payments_customer',
     'customer_unique_id', 'dim_customer', 'customer_unique_id'),

    ('fact_payments', 'fk_fact_payments_geography',
     'customer_location_key', 'dim_customer_geography',
     'customer_location_key'),

    ('fact_payments', 'fk_fact_payments_status',
     'order_status', 'dim_order_status', 'order_status'),

    ('fact_payments', 'fk_fact_payments_purchase_date',
     'purchase_date', 'dim_purchase_date', 'date'),

    ('fact_payments', 'fk_fact_payments_parent_order',
     'order_id', 'fact_orders', 'order_id'),

    -- fact_order_reviews: 6
    ('fact_order_reviews', 'fk_fact_reviews_customer',
     'customer_unique_id', 'dim_customer', 'customer_unique_id'),

    ('fact_order_reviews', 'fk_fact_reviews_geography',
     'customer_location_key', 'dim_customer_geography',
     'customer_location_key'),

    ('fact_order_reviews', 'fk_fact_reviews_status',
     'order_status', 'dim_order_status', 'order_status'),

    ('fact_order_reviews', 'fk_fact_reviews_purchase_date',
     'purchase_date', 'dim_purchase_date', 'date'),

    ('fact_order_reviews', 'fk_fact_reviews_review_date',
     'review_creation_date', 'dim_review_date', 'date'),

    ('fact_order_reviews', 'fk_fact_reviews_parent_order',
     'order_id', 'fact_orders', 'order_id')
),

actual AS (

    SELECT
        child.relname::TEXT AS fact_table,
        con.conname::TEXT AS fk_name,
        child_col.attname::TEXT AS child_column,
        parent.relname::TEXT AS parent_table,
        parent_col.attname::TEXT AS parent_column,
        parent_ns.nspname::TEXT AS parent_schema,
        con.convalidated AS is_validated,
        con.conenforced AS is_enforced,
        CARDINALITY(con.conkey) AS child_column_count,
        CARDINALITY(con.confkey) AS parent_column_count

    FROM pg_catalog.pg_constraint AS con

    JOIN pg_catalog.pg_class AS child
        ON child.oid = con.conrelid

    JOIN pg_catalog.pg_namespace AS child_ns
        ON child_ns.oid = child.relnamespace

    JOIN pg_catalog.pg_class AS parent
        ON parent.oid = con.confrelid

    JOIN pg_catalog.pg_namespace AS parent_ns
        ON parent_ns.oid = parent.relnamespace

    LEFT JOIN pg_catalog.pg_attribute AS child_col
        ON child_col.attrelid = con.conrelid
       AND child_col.attnum = con.conkey[1]

    LEFT JOIN pg_catalog.pg_attribute AS parent_col
        ON parent_col.attrelid = con.confrelid
       AND parent_col.attnum = con.confkey[1]

    WHERE con.contype = 'f'
      AND child_ns.nspname = 'analytics'
      AND child.relname IN (
          'fact_orders',
          'fact_order_items',
          'fact_payments',
          'fact_order_reviews'
      )
),

audit AS (

    SELECT
        COALESCE(e.fact_table, a.fact_table) AS fact_table,
        COALESCE(e.fk_name, a.fk_name) AS fk_name,

        CASE
            WHEN e.fk_name IS NOT NULL
             AND a.fk_name IS NOT NULL
             AND e.child_column = a.child_column
             AND e.parent_table = a.parent_table
             AND e.parent_column = a.parent_column
             AND a.parent_schema = 'analytics'
             AND a.child_column_count = 1
             AND a.parent_column_count = 1
             AND a.is_validated IS TRUE
             AND a.is_enforced IS TRUE
            THEN 'PASS'
            ELSE 'FAIL'
        END AS audit_status

    FROM expected AS e

    FULL OUTER JOIN actual AS a
        ON e.fact_table = a.fact_table
       AND e.fk_name = a.fk_name

)

SELECT
    fact_table,
    fk_name,
    audit_status

FROM audit

UNION ALL

SELECT
    'TOTAL',
    'Expected 23 foreign keys',

    CASE
        WHEN COUNT(*) = 23
         AND BOOL_AND(audit_status = 'PASS')
        THEN 'PASS'
        ELSE 'FAIL'
    END

FROM audit

ORDER BY fact_table, fk_name;


-- =====================================================
-- CHECK B: Integrated dimension joins and cardinality
-- =====================================================

WITH checks AS (

    -- 1. ORDERS
    SELECT
        'fact_orders' AS fact_model,
        99441::BIGINT AS expected_rows,
        COUNT(*) AS joined_rows,
        COUNT(DISTINCT f.order_id) AS distinct_grain_keys,

        COUNT(*) FILTER (
            WHERE c.customer_unique_id IS NULL
               OR g.customer_location_key IS NULL
               OR s.order_status IS NULL
               OR pd.date IS NULL
               OR (
                   f.delivery_date IS NOT NULL
                   AND dd.date IS NULL
               )
        ) AS unexpected_dimension_gaps,

        0::BIGINT AS missing_parent_orders,

        COUNT(*) FILTER (
            WHERE f.delivery_date IS NULL
        ) AS documented_null_delivery_dates

    FROM analytics.fact_orders AS f

    LEFT JOIN analytics.dim_customer AS c
        ON f.customer_unique_id = c.customer_unique_id

    LEFT JOIN analytics.dim_customer_geography AS g
        ON f.customer_location_key = g.customer_location_key

    LEFT JOIN analytics.dim_order_status AS s
        ON f.order_status = s.order_status

    LEFT JOIN analytics.dim_purchase_date AS pd
        ON f.purchase_date = pd.date

    LEFT JOIN analytics.dim_delivery_date AS dd
        ON f.delivery_date = dd.date

    UNION ALL

    -- 2. ORDER ITEMS
    SELECT
        'fact_order_items',
        112650::BIGINT,
        COUNT(*),
        COUNT(DISTINCT (f.order_id, f.order_item_id)),

        COUNT(*) FILTER (
            WHERE p.product_id IS NULL
               OR se.seller_id IS NULL
               OR c.customer_unique_id IS NULL
               OR g.customer_location_key IS NULL
               OR s.order_status IS NULL
               OR pd.date IS NULL
        ),

        COUNT(*) FILTER (
            WHERE o.order_id IS NULL
        ),

        0::BIGINT

    FROM analytics.fact_order_items AS f

    LEFT JOIN analytics.dim_product AS p
        ON f.product_id = p.product_id

    LEFT JOIN analytics.dim_seller AS se
        ON f.seller_id = se.seller_id

    LEFT JOIN analytics.dim_customer AS c
        ON f.customer_unique_id = c.customer_unique_id

    LEFT JOIN analytics.dim_customer_geography AS g
        ON f.customer_location_key = g.customer_location_key

    LEFT JOIN analytics.dim_order_status AS s
        ON f.order_status = s.order_status

    LEFT JOIN analytics.dim_purchase_date AS pd
        ON f.purchase_date = pd.date

    LEFT JOIN analytics.fact_orders AS o
        ON f.order_id = o.order_id

    UNION ALL

    -- 3. PAYMENTS
    SELECT
        'fact_payments',
        103886::BIGINT,
        COUNT(*),
        COUNT(DISTINCT (f.order_id, f.payment_sequential)),

        COUNT(*) FILTER (
            WHERE c.customer_unique_id IS NULL
               OR g.customer_location_key IS NULL
               OR s.order_status IS NULL
               OR pd.date IS NULL
        ),

        COUNT(*) FILTER (
            WHERE o.order_id IS NULL
        ),

        0::BIGINT

    FROM analytics.fact_payments AS f

    LEFT JOIN analytics.dim_customer AS c
        ON f.customer_unique_id = c.customer_unique_id

    LEFT JOIN analytics.dim_customer_geography AS g
        ON f.customer_location_key = g.customer_location_key

    LEFT JOIN analytics.dim_order_status AS s
        ON f.order_status = s.order_status

    LEFT JOIN analytics.dim_purchase_date AS pd
        ON f.purchase_date = pd.date

    LEFT JOIN analytics.fact_orders AS o
        ON f.order_id = o.order_id

    UNION ALL

    -- 4. REVIEWS
    SELECT
        'fact_order_reviews',
        99224::BIGINT,
        COUNT(*),
        COUNT(DISTINCT (f.review_id, f.order_id)),

        COUNT(*) FILTER (
            WHERE c.customer_unique_id IS NULL
               OR g.customer_location_key IS NULL
               OR s.order_status IS NULL
               OR pd.date IS NULL
               OR rd.date IS NULL
        ),

        COUNT(*) FILTER (
            WHERE o.order_id IS NULL
        ),

        0::BIGINT

    FROM analytics.fact_order_reviews AS f

    LEFT JOIN analytics.dim_customer AS c
        ON f.customer_unique_id = c.customer_unique_id

    LEFT JOIN analytics.dim_customer_geography AS g
        ON f.customer_location_key = g.customer_location_key

    LEFT JOIN analytics.dim_order_status AS s
        ON f.order_status = s.order_status

    LEFT JOIN analytics.dim_purchase_date AS pd
        ON f.purchase_date = pd.date

    LEFT JOIN analytics.dim_review_date AS rd
        ON f.review_creation_date = rd.date

    LEFT JOIN analytics.fact_orders AS o
        ON f.order_id = o.order_id

)

SELECT
    fact_model,
    expected_rows,
    joined_rows,
    distinct_grain_keys,
    unexpected_dimension_gaps,
    missing_parent_orders,
    documented_null_delivery_dates,

    CASE
        WHEN expected_rows = joined_rows
         AND joined_rows = distinct_grain_keys
         AND unexpected_dimension_gaps = 0
         AND missing_parent_orders = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS audit_status

FROM checks

ORDER BY fact_model;


-- =====================================================
-- CHECK C: Cross-fact order-context integrity
-- =====================================================

WITH comparisons AS (

    -- Order Items
    SELECT
        'fact_order_items' AS fact_model,
        112650::BIGINT AS expected_rows,
        COUNT(*) AS checked_rows,

        COUNT(*) FILTER (
            WHERE o.order_id IS NULL
               OR ROW(
                   f.customer_id,
                   f.customer_unique_id,
                   f.customer_location_key,
                   f.order_status,
                   f.purchase_date
               ) IS DISTINCT FROM ROW(
                   o.customer_id,
                   o.customer_unique_id,
                   o.customer_location_key,
                   o.order_status,
                   o.purchase_date
               )
        ) AS inconsistent_order_context

    FROM analytics.fact_order_items AS f

    LEFT JOIN analytics.fact_orders AS o
        ON f.order_id = o.order_id

    UNION ALL

    -- Payments
    SELECT
        'fact_payments',
        103886::BIGINT,
        COUNT(*),

        COUNT(*) FILTER (
            WHERE o.order_id IS NULL
               OR ROW(
                   f.customer_id,
                   f.customer_unique_id,
                   f.customer_location_key,
                   f.order_status,
                   f.purchase_date
               ) IS DISTINCT FROM ROW(
                   o.customer_id,
                   o.customer_unique_id,
                   o.customer_location_key,
                   o.order_status,
                   o.purchase_date
               )
        )

    FROM analytics.fact_payments AS f

    LEFT JOIN analytics.fact_orders AS o
        ON f.order_id = o.order_id

    UNION ALL

    -- Reviews
    SELECT
        'fact_order_reviews',
        99224::BIGINT,
        COUNT(*),

        COUNT(*) FILTER (
            WHERE o.order_id IS NULL
               OR ROW(
                   f.customer_id,
                   f.customer_unique_id,
                   f.customer_location_key,
                   f.order_status,
                   f.purchase_date
               ) IS DISTINCT FROM ROW(
                   o.customer_id,
                   o.customer_unique_id,
                   o.customer_location_key,
                   o.order_status,
                   o.purchase_date
               )
        )

    FROM analytics.fact_order_reviews AS f

    LEFT JOIN analytics.fact_orders AS o
        ON f.order_id = o.order_id

)

SELECT
    fact_model,
    expected_rows,
    checked_rows,
    inconsistent_order_context,

    CASE
        WHEN expected_rows = checked_rows
         AND inconsistent_order_context = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS audit_status

FROM comparisons

ORDER BY fact_model;


-- =====================================================
-- CHECK D1: Geographic coverage across all facts
-- =====================================================

WITH geographic_coverage AS (

    -- Orders
    SELECT
        'fact_orders' AS fact_model,
        COUNT(*) AS fact_records,

        COUNT(*) FILTER (
            WHERE g.customer_location_key IS NULL
        ) AS missing_dimension_links,

        COUNT(*) FILTER (
            WHERE g.has_geo_reference IS FALSE
        ) AS records_without_geo_reference,

        COUNT(*) FILTER (
            WHERE g.is_reference_coordinate_outlier
        ) AS records_with_flagged_coordinates,

        COUNT(*) FILTER (
            WHERE g.has_map_ready_coordinate
        ) AS map_ready_records

    FROM analytics.fact_orders AS f

    LEFT JOIN analytics.dim_customer_geography AS g
        ON f.customer_location_key = g.customer_location_key

    UNION ALL

    -- Order Items
    SELECT
        'fact_order_items',
        COUNT(*),

        COUNT(*) FILTER (
            WHERE g.customer_location_key IS NULL
        ),

        COUNT(*) FILTER (
            WHERE g.has_geo_reference IS FALSE
        ),

        COUNT(*) FILTER (
            WHERE g.is_reference_coordinate_outlier
        ),

        COUNT(*) FILTER (
            WHERE g.has_map_ready_coordinate
        )

    FROM analytics.fact_order_items AS f

    LEFT JOIN analytics.dim_customer_geography AS g
        ON f.customer_location_key = g.customer_location_key

    UNION ALL

    -- Payments
    SELECT
        'fact_payments',
        COUNT(*),

        COUNT(*) FILTER (
            WHERE g.customer_location_key IS NULL
        ),

        COUNT(*) FILTER (
            WHERE g.has_geo_reference IS FALSE
        ),

        COUNT(*) FILTER (
            WHERE g.is_reference_coordinate_outlier
        ),

        COUNT(*) FILTER (
            WHERE g.has_map_ready_coordinate
        )

    FROM analytics.fact_payments AS f

    LEFT JOIN analytics.dim_customer_geography AS g
        ON f.customer_location_key = g.customer_location_key

    UNION ALL

    -- Reviews
    SELECT
        'fact_order_reviews',
        COUNT(*),

        COUNT(*) FILTER (
            WHERE g.customer_location_key IS NULL
        ),

        COUNT(*) FILTER (
            WHERE g.has_geo_reference IS FALSE
        ),

        COUNT(*) FILTER (
            WHERE g.is_reference_coordinate_outlier
        ),

        COUNT(*) FILTER (
            WHERE g.has_map_ready_coordinate
        )

    FROM analytics.fact_order_reviews AS f

    LEFT JOIN analytics.dim_customer_geography AS g
        ON f.customer_location_key = g.customer_location_key

)

SELECT
    fact_model,
    fact_records,
    missing_dimension_links,
    records_without_geo_reference,
    records_with_flagged_coordinates,
    map_ready_records,

    ROUND(
        100.0 * map_ready_records
        / NULLIF(fact_records, 0),
        2
    ) AS map_ready_pct,

    CASE
        WHEN missing_dimension_links = 0
         AND fact_records = (
             records_without_geo_reference
             + records_with_flagged_coordinates
             + map_ready_records
         )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS audit_status

FROM geographic_coverage

ORDER BY fact_model;


-- =====================================================
-- CHECK D2: Seller geographic coverage
-- =====================================================

SELECT
    COUNT(*) AS total_sellers,

    COUNT(*) FILTER (
        WHERE NOT has_geo_reference
    ) AS sellers_without_geo_reference,

    COUNT(*) FILTER (
        WHERE is_reference_coordinate_outlier
    ) AS sellers_with_flagged_coordinates,

    COUNT(*) FILTER (
        WHERE has_map_ready_coordinate
    ) AS map_ready_sellers,

    COUNT(*) FILTER (
        WHERE has_reference_label_disagreement
    ) AS seller_reference_label_disagreements,

    COUNT(*) FILTER (
        WHERE has_conflicting_reference_labels
    ) AS sellers_with_conflicting_reference_labels,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE has_map_ready_coordinate
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS map_ready_seller_pct

FROM analytics.dim_seller;
