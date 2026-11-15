
-- ============================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP: 7.4 Task 6
-- PAGE: 06 Geographic Coverage & Data Quality
-- FILE: 47_powerbi_geographic_dashboard_validation.sql
-- DATABASE: olist_analytics
-- TYPE: READ-ONLY VALIDATION
-- ============================================================

-- Dashboard geographic visual:
-- Top 10 Customer States by Map-Ready Orders.
--
-- No Azure Maps, exact customer coordinates,
-- or Power BI cloud workspace is required.


-- ============================================================
-- SQL-0: INSPECT REQUIRED GEOGRAPHIC FIELDS
-- ============================================================

SELECT
    table_name,
    column_name,
    data_type

FROM information_schema.columns

WHERE table_schema = 'analytics'
  AND table_name IN (
      'dim_customer_geography',
      'dim_seller'
  )
  AND (
      column_name ILIKE '%geo%'
      OR column_name ILIKE '%state%'
      OR column_name ILIKE '%zip%'
      OR column_name ILIKE '%coordinate%'
      OR column_name ILIKE '%lat%'
      OR column_name ILIKE '%lng%'
  )

ORDER BY
    table_name,
    ordinal_position;



-- ============================================================
-- SQL-1: GEOGRAPHIC COMPLETENESS ACROSS FOUR FACTS
-- FULL DATASET AND Q1 2018 DELIVERED COHORT
-- ============================================================

WITH base_records AS (

    SELECT
        'Orders' AS fact_name,
        order_status,
        purchase_date,
        customer_location_key
    FROM analytics.fact_orders

    UNION ALL

    SELECT
        'Order Items',
        order_status,
        purchase_date,
        customer_location_key
    FROM analytics.fact_order_items

    UNION ALL

    SELECT
        'Payments',
        order_status,
        purchase_date,
        customer_location_key
    FROM analytics.fact_payments

    UNION ALL

    SELECT
        'Reviews',
        order_status,
        purchase_date,
        customer_location_key
    FROM analytics.fact_order_reviews
),

scoped_records AS (

    SELECT
        'ALL' AS cohort,
        fact_name,
        customer_location_key
    FROM base_records

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED',
        fact_name,
        customer_location_key
    FROM base_records

    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
),

classified AS (

    SELECT
        s.cohort,
        s.fact_name,

        CASE
            WHEN g.customer_location_key IS NULL
                THEN 'MISSING_DIMENSION_LINK'

            WHEN g.has_geo_reference IS NOT TRUE
                THEN 'MISSING_GEO_REFERENCE'

            WHEN g.is_reference_coordinate_outlier IS TRUE
                THEN 'FLAGGED_COORDINATE'

            WHEN g.has_map_ready_coordinate IS TRUE
                THEN 'MAP_READY'

            ELSE 'OTHER_INSPECT'
        END AS quality_status

    FROM scoped_records AS s

    LEFT JOIN analytics.dim_customer_geography AS g
        ON s.customer_location_key = g.customer_location_key
),

aggregates AS (

    SELECT
        cohort,
        fact_name,

        COUNT(*) AS total_records,

        COUNT(*) FILTER (
            WHERE quality_status = 'MISSING_DIMENSION_LINK'
        ) AS missing_dimension_links,

        COUNT(*) FILTER (
            WHERE quality_status = 'MISSING_GEO_REFERENCE'
        ) AS without_geo_reference,

        COUNT(*) FILTER (
            WHERE quality_status = 'FLAGGED_COORDINATE'
        ) AS flagged_coordinate_records,

        COUNT(*) FILTER (
            WHERE quality_status = 'MAP_READY'
        ) AS map_ready_records,

        COUNT(*) FILTER (
            WHERE quality_status = 'OTHER_INSPECT'
        ) AS other_inspect_records

    FROM classified

    GROUP BY cohort, fact_name
)

SELECT
    cohort,
    fact_name,
    total_records,
    missing_dimension_links,
    without_geo_reference,
    flagged_coordinate_records,
    map_ready_records,
    other_inspect_records,

    ROUND(
        100.0 * map_ready_records
        / NULLIF(total_records, 0),
        2
    ) AS map_ready_share_pct,

    total_records
      - missing_dimension_links
      - without_geo_reference
      - flagged_coordinate_records
      - map_ready_records
      - other_inspect_records
        AS partition_difference,

    CASE
        WHEN missing_dimension_links = 0
         AND other_inspect_records = 0
         AND total_records =
               without_geo_reference
             + flagged_coordinate_records
             + map_ready_records
        THEN 'PASS'
        ELSE 'FAIL'
    END AS audit_status

FROM aggregates

ORDER BY
    cohort,
    fact_name;



-- ============================================================
-- SQL-2: TOP 10 CUSTOMER STATES BY MAP-READY ORDERS
-- ============================================================

-- This is the new substitute for Azure Maps.
-- Rank states by counts of map-ready Orders fact rows.
-- Use a deterministic state-code tie-breaker.

WITH scoped_orders AS (

    SELECT
        'ALL' AS cohort,
        customer_location_key
    FROM analytics.fact_orders

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED',
        customer_location_key
    FROM analytics.fact_orders

    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
),

state_summary AS (

    SELECT
        o.cohort,

        COALESCE(
            NULLIF(TRIM(g.customer_state), ''),
            'UNKNOWN_STATE'
        ) AS customer_state,

        COUNT(*) AS total_orders,

        COUNT(*) FILTER (
            WHERE g.has_map_ready_coordinate IS TRUE
        ) AS map_ready_orders

    FROM scoped_orders AS o

    LEFT JOIN analytics.dim_customer_geography AS g
        ON o.customer_location_key = g.customer_location_key

    GROUP BY
        o.cohort,
        COALESCE(
            NULLIF(TRIM(g.customer_state), ''),
            'UNKNOWN_STATE'
        )
),

ranked AS (

    SELECT
        cohort,
        customer_state,
        total_orders,
        map_ready_orders,

        ROW_NUMBER() OVER (
            PARTITION BY cohort
            ORDER BY
                map_ready_orders DESC,
                customer_state ASC
        ) AS state_rank

    FROM state_summary
)

SELECT
    cohort,
    state_rank,
    customer_state,
    total_orders,
    map_ready_orders

FROM ranked

WHERE state_rank <= 10

ORDER BY
    cohort,
    state_rank;



-- ============================================================
-- SQL-3: MONTHLY GEOGRAPHIC COVERAGE
-- ============================================================

-- The month represents order purchase month.
-- It does not represent the date of geographic
-- reference updates or customer movements.

WITH base_records AS (

    SELECT
        'Orders' AS fact_name,
        purchase_date,
        customer_location_key
    FROM analytics.fact_orders

    UNION ALL

    SELECT
        'Order Items',
        purchase_date,
        customer_location_key
    FROM analytics.fact_order_items

    UNION ALL

    SELECT
        'Payments',
        purchase_date,
        customer_location_key
    FROM analytics.fact_payments

    UNION ALL

    SELECT
        'Reviews',
        purchase_date,
        customer_location_key
    FROM analytics.fact_order_reviews
)

SELECT
    date_trunc(
        'month',
        b.purchase_date
    )::date AS purchase_month,

    b.fact_name,

    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE g.has_map_ready_coordinate IS TRUE
    ) AS map_ready_records,

    COUNT(*) FILTER (
        WHERE g.has_geo_reference IS NOT TRUE
    ) AS records_without_geo_reference,

    COUNT(*) FILTER (
        WHERE g.is_reference_coordinate_outlier IS TRUE
    ) AS flagged_records,

    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE g.has_map_ready_coordinate IS TRUE
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS map_ready_share_pct

FROM base_records AS b

LEFT JOIN analytics.dim_customer_geography AS g
    ON b.customer_location_key = g.customer_location_key

WHERE b.purchase_date IS NOT NULL

GROUP BY
    1,
    b.fact_name

ORDER BY
    purchase_month,
    fact_name;



-- ============================================================
-- SQL-4A: CUSTOMER GEOGRAPHY DIMENSION QUALITY
-- ============================================================

SELECT
    COUNT(*) AS geography_dimension_rows,

    COUNT(*) FILTER (
        WHERE has_map_ready_coordinate IS TRUE
    ) AS map_ready_geography_rows,

    COUNT(*) FILTER (
        WHERE has_geo_reference IS TRUE
    ) AS geographic_reference_rows,

    COUNT(*) FILTER (
        WHERE has_geo_reference IS NOT TRUE
    ) AS without_reference_rows,

    COUNT(*) FILTER (
        WHERE is_reference_coordinate_outlier IS TRUE
    ) AS flagged_reference_coordinates,

    COUNT(*) FILTER (
        WHERE has_map_ready_coordinate IS TRUE
          AND (
              geolocation_lat IS NULL
              OR geolocation_lng IS NULL
              OR geolocation_lat NOT BETWEEN -90 AND 90
              OR geolocation_lng NOT BETWEEN -180 AND 180
          )
    ) AS invalid_map_ready_lat_lng

FROM analytics.dim_customer_geography;



-- ============================================================
-- SQL-4B: SELLER GEOGRAPHY REFERENCE COVERAGE
-- ============================================================

SELECT
    COUNT(*) AS seller_dimension_rows,

    COUNT(*) FILTER (
        WHERE has_geo_reference IS TRUE
    ) AS sellers_with_geo_reference

FROM analytics.dim_seller;



-- ============================================================
-- SQL-5: ORDER GEOGRAPHIC EXCEPTION DISTRIBUTION
-- ============================================================

WITH scoped_orders AS (

    SELECT
        'ALL' AS cohort,
        customer_location_key
    FROM analytics.fact_orders

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED',
        customer_location_key
    FROM analytics.fact_orders

    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
),

classified AS (

    SELECT
        o.cohort,

        CASE
            WHEN g.customer_location_key IS NULL
                THEN 'Missing Dimension Link'

            WHEN g.has_geo_reference IS NOT TRUE
                THEN 'Missing ZIP Reference'

            WHEN g.is_reference_coordinate_outlier IS TRUE
                THEN 'Flagged Coordinate'

            WHEN g.has_map_ready_coordinate IS TRUE
                THEN 'Map-Ready'

            ELSE 'Other / Inspect'
        END AS geographic_quality_category

    FROM scoped_orders AS o

    LEFT JOIN analytics.dim_customer_geography AS g
        ON o.customer_location_key = g.customer_location_key
)

SELECT
    cohort,
    geographic_quality_category,
    COUNT(*) AS orders

FROM classified

GROUP BY
    cohort,
    geographic_quality_category

ORDER BY
    cohort,
    geographic_quality_category;



-- ============================================================
-- VERIFIED FULL-DATASET BASELINES
-- ============================================================

-- ORDERS
-- Total:                  99,441
-- Without reference:        278
-- Flagged:                    1
-- Map-ready:             99,162
-- Map-ready share:       99.72%

-- ORDER ITEMS
-- Total:                 112,650
-- Without reference:        302
-- Flagged:                    1
-- Map-ready:            112,347
-- Map-ready share:       99.73%

-- PAYMENTS
-- Total:                 103,886
-- Without reference:        287
-- Flagged:                    1
-- Map-ready:            103,598
-- Map-ready share:       99.72%

-- REVIEWS
-- Total:                  99,224
-- Without reference:        279
-- Flagged:                    1
-- Map-ready:             98,944
-- Map-ready share:       99.72%

-- No missing geography dimension links.
-- No Other / Inspect fact records.
-- All population partition differences: 0.

-- Customer geography dimension rows: 15,034.
-- Map-ready customer locations: 14,876.
-- Invalid map-ready lat/lng: 0.

-- Seller dimension rows: 3,095.
-- Sellers with geographic reference: 3,088.


-- ============================================================
-- VERIFIED Q1 2018 DELIVERED BASELINES
-- ============================================================

-- ORDERS
-- Total:                  20,627
-- Without reference:         59
-- Flagged:                    0
-- Map-ready:             20,568
-- Share:                  99.71%

-- ORDER ITEMS
-- Total:                  23,572
-- Without reference:         62
-- Flagged:                    0
-- Map-ready:             23,510
-- Share:                  99.74%

-- PAYMENTS
-- Total:                  21,424
-- Without reference:         62
-- Flagged:                    0
-- Map-ready:             21,362
-- Share:                  99.71%

-- REVIEWS
-- Total:                  20,630
-- Without reference:         58
-- Flagged:                    0
-- Map-ready:             20,572
-- Share:                  99.72%


-- ============================================================
-- ACCEPTANCE CRITERIA
-- ============================================================

-- SQL-0:
-- Geographic reference and state columns exist.

-- SQL-1:
-- Exactly 8 rows across two cohorts/four facts.
-- All audit_status values = PASS.
-- All partition differences = 0.
-- No missing dimension links.
-- No Other / Inspect populations.

-- SQL-2:
-- Top 10 state names and order counts must
-- reconcile with Power BI DAX G5.
-- Do not invent or assume state rankings.

-- SQL-3:
-- Compare monthly values with the Power BI chart.
-- Include January, February, March 2018.

-- SQL-4A:
-- Geography rows: 15,034.
-- Map-ready geography rows: 14,876.
-- Invalid map-ready coordinates: 0.

-- SQL-4B:
-- Seller rows: 3,095.
-- Matched reference sellers: 3,088.

-- SQL-5:
-- ALL: Missing 278, Flagged 1, Map-ready 99,162.
-- Q1: Missing 59, Flagged 0, Map-ready 20,568.

-- All statements are read-only.
-- No changes to PostgreSQL source data.

-- ============================================================
-- END OF FILE
-- ============================================================
