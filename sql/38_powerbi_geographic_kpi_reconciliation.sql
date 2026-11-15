
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 7.3 - TASK 8
-- FILE: 38_powerbi_geographic_kpi_reconciliation.sql
-- =====================================================

-- CHECK F1: Geographic coverage by fact and cohort

WITH fact_rows AS (

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

scoped_rows AS (

    SELECT
        'ALL' AS cohort,
        fact_name,
        customer_location_key
    FROM fact_rows

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED',
        fact_name,
        customer_location_key
    FROM fact_rows
    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
),

coverage AS (

    SELECT
        f.cohort,
        f.fact_name,

        COUNT(*) AS fact_records,

        COUNT(*) FILTER (
            WHERE g.customer_location_key IS NULL
        ) AS missing_dimension_links,

        COUNT(*) FILTER (
            WHERE g.has_geo_reference IS FALSE
        ) AS records_without_geo_reference,

        COUNT(*) FILTER (
            WHERE g.is_reference_coordinate_outlier IS TRUE
        ) AS records_with_flagged_coordinates,

        COUNT(*) FILTER (
            WHERE g.has_map_ready_coordinate IS TRUE
        ) AS map_ready_records

    FROM scoped_rows AS f

    LEFT JOIN analytics.dim_customer_geography AS g
        ON f.customer_location_key = g.customer_location_key

    GROUP BY
        f.cohort,
        f.fact_name
)

SELECT
    cohort,
    fact_name,
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

    fact_records
        - records_without_geo_reference
        - records_with_flagged_coordinates
        - map_ready_records
        AS geographic_partition_difference,

    CASE
        WHEN missing_dimension_links = 0
         AND fact_records =
             records_without_geo_reference
             + records_with_flagged_coordinates
             + map_ready_records
        THEN 'PASS'
        ELSE 'FAIL'
    END AS audit_status

FROM coverage

ORDER BY cohort, fact_name;


-- CHECK G1: Customer Geography dimension coverage

SELECT
    COUNT(*) AS customer_geography_locations,

    COUNT(*) FILTER (
        WHERE has_map_ready_coordinate IS TRUE
    ) AS map_ready_locations,

    COUNT(*) FILTER (
        WHERE has_map_ready_coordinate IS NOT TRUE
    ) AS locations_not_map_ready,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE has_map_ready_coordinate IS TRUE
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS map_ready_location_rate_pct

FROM analytics.dim_customer_geography;


-- CHECK G2: Seller geographic quality

SELECT
    COUNT(*) AS total_sellers,

    COUNT(*) FILTER (
        WHERE has_geo_reference IS FALSE
    ) AS sellers_without_geo_reference,

    COUNT(*) FILTER (
        WHERE is_reference_coordinate_outlier IS TRUE
    ) AS sellers_with_flagged_coordinates,

    COUNT(*) FILTER (
        WHERE has_map_ready_coordinate IS TRUE
    ) AS map_ready_sellers,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE has_map_ready_coordinate IS TRUE
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS map_ready_seller_share_pct,

    COUNT(*) FILTER (
        WHERE has_reference_label_disagreement IS TRUE
    ) AS sellers_with_label_disagreement,

    COUNT(*) FILTER (
        WHERE has_conflicting_reference_labels IS TRUE
    ) AS sellers_with_conflicting_labels

FROM analytics.dim_seller;
