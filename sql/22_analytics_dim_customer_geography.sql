
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 6.2 - TASK 5
-- MODEL: analytics.dim_customer_geography
-- =====================================================

-- CHECK A1: Customer location source readiness

SELECT
    COUNT(*) AS total_customer_records,

    COUNT(DISTINCT customer_id)
        AS unique_customer_ids,

    COUNT(*) FILTER (
        WHERE has_invalid_zip_prefix
    ) AS invalid_zip_prefix_records,

    COUNT(*) FILTER (
        WHERE has_invalid_state_format
    ) AS invalid_state_records,

    COUNT(*) FILTER (
        WHERE customer_city IS NULL
           OR BTRIM(customer_city) = ''
    ) AS missing_city_records,

    COUNT(*) FILTER (
        WHERE customer_zip_code_prefix LIKE '0%'
    ) AS leading_zero_zip_records

FROM staging.stg_customers;


-- CHECK A2: Location grain and key uniqueness

WITH locations AS (

    SELECT DISTINCT
        customer_zip_code_prefix,
        customer_city,
        customer_state

    FROM staging.stg_customers

),

location_keys AS (

    SELECT
        MD5(
            JSONB_BUILD_ARRAY(
                customer_zip_code_prefix,
                customer_city,
                customer_state
            )::TEXT
        ) AS customer_location_key

    FROM locations

)

SELECT
    COUNT(*) AS distinct_location_combinations,

    COUNT(DISTINCT customer_location_key)
        AS unique_location_keys,

    COUNT(*) -
        COUNT(DISTINCT customer_location_key)
        AS key_collisions

FROM location_keys;


-- CHECK A3: Customer geographic reference coverage

SELECT
    COUNT(*) AS customer_rows_after_join,

    COUNT(*) FILTER (
        WHERE g.geolocation_zip_code_prefix IS NULL
    ) AS customers_without_geo_reference,

    COUNT(DISTINCT c.customer_zip_code_prefix)
        FILTER (
            WHERE g.geolocation_zip_code_prefix IS NULL
        ) AS unmatched_distinct_zip_prefixes,

    COUNT(*) FILTER (
        WHERE g.is_outside_broad_brazil_box
    ) AS customers_linked_to_coordinate_outliers,

    COUNT(*) FILTER (
        WHERE g.geolocation_zip_code_prefix IS NOT NULL
          AND g.has_conflicting_city_state_labels
    ) AS customers_with_conflicting_reference_labels,

    COUNT(*) FILTER (
        WHERE g.geolocation_zip_code_prefix IS NOT NULL
          AND (
              c.customer_city IS DISTINCT FROM
                  g.geolocation_city

              OR c.customer_state IS DISTINCT FROM
                  g.geolocation_state
          )
    ) AS customer_reference_label_differences

FROM staging.stg_customers AS c

LEFT JOIN staging.ref_zip_geolocation AS g
    ON c.customer_zip_code_prefix =
       g.geolocation_zip_code_prefix;


-- =====================================================
-- CHECK B: Create Customer Geography dimension
-- =====================================================

BEGIN;

CREATE TABLE analytics.dim_customer_geography AS

WITH locations AS (

    SELECT
        customer_zip_code_prefix,
        customer_city,
        customer_state,

        COUNT(*)::BIGINT
            AS source_customer_record_count,

        BOOL_OR(has_invalid_zip_prefix)
            AS has_invalid_zip_prefix,

        BOOL_OR(has_invalid_state_format)
            AS has_invalid_state_format

    FROM staging.stg_customers

    GROUP BY
        customer_zip_code_prefix,
        customer_city,
        customer_state

),

enriched AS (

    SELECT

        MD5(
            JSONB_BUILD_ARRAY(
                l.customer_zip_code_prefix,
                l.customer_city,
                l.customer_state
            )::TEXT
        ) AS customer_location_key,

        -- Original standardized customer location
        l.customer_zip_code_prefix,
        l.customer_city,
        l.customer_state,

        -- Source lineage and quality
        l.source_customer_record_count,
        l.has_invalid_zip_prefix,
        l.has_invalid_state_format,

        -- ZIP reference information
        g.geolocation_city AS reference_city,
        g.geolocation_state AS reference_state,

        g.representative_latitude,
        g.representative_longitude,

        g.geo_source_row_count
            AS reference_source_row_count,

        (
            g.geolocation_zip_code_prefix IS NOT NULL
        ) AS has_geo_reference,

        COALESCE(
            g.has_conflicting_city_state_labels,
            FALSE
        ) AS has_conflicting_reference_labels,

        (
            g.geolocation_zip_code_prefix IS NOT NULL
            AND (
                l.customer_city IS DISTINCT FROM
                    g.geolocation_city

                OR l.customer_state IS DISTINCT FROM
                    g.geolocation_state
            )
        ) AS has_reference_label_disagreement,

        COALESCE(
            g.is_outside_broad_brazil_box,
            FALSE
        ) AS is_reference_coordinate_outlier,

        (
            NOT l.has_invalid_zip_prefix

            AND g.geolocation_zip_code_prefix IS NOT NULL

            AND g.representative_latitude IS NOT NULL

            AND g.representative_longitude IS NOT NULL

            AND NOT COALESCE(
                g.is_outside_broad_brazil_box,
                FALSE
            )
        ) AS has_map_ready_coordinate

    FROM locations AS l

    LEFT JOIN staging.ref_zip_geolocation AS g
        ON l.customer_zip_code_prefix =
           g.geolocation_zip_code_prefix

)

SELECT
    customer_location_key,

    customer_zip_code_prefix,
    customer_city,
    customer_state,

    source_customer_record_count,

    has_invalid_zip_prefix,
    has_invalid_state_format,

    reference_city,
    reference_state,

    representative_latitude,
    representative_longitude,

    reference_source_row_count,

    has_geo_reference,
    has_conflicting_reference_labels,
    has_reference_label_disagreement,
    is_reference_coordinate_outlier,
    has_map_ready_coordinate,

    CASE
        WHEN has_map_ready_coordinate
        THEN representative_latitude
        ELSE NULL
    END AS map_latitude,

    CASE
        WHEN has_map_ready_coordinate
        THEN representative_longitude
        ELSE NULL
    END AS map_longitude

FROM enriched

WITH DATA;


-- Enforce the dimension grain

ALTER TABLE analytics.dim_customer_geography

ADD CONSTRAINT dim_customer_geography_pkey

PRIMARY KEY (customer_location_key);


-- Require at least one source customer record

ALTER TABLE analytics.dim_customer_geography

ADD CONSTRAINT chk_customer_geo_source_count

CHECK (source_customer_record_count >= 1);


-- Enforce consistent map-ready fields

ALTER TABLE analytics.dim_customer_geography

ADD CONSTRAINT chk_customer_geo_map_fields

CHECK (

    (
        has_map_ready_coordinate

        AND map_latitude IS NOT NULL
        AND map_longitude IS NOT NULL

        AND NOT is_reference_coordinate_outlier
    )

    OR

    (
        NOT has_map_ready_coordinate

        AND map_latitude IS NULL
        AND map_longitude IS NULL
    )

);

COMMIT;


-- =====================================================
-- CHECK C1: Dimension quality and geographic coverage
-- =====================================================

SELECT
    COUNT(*) AS total_location_records,

    COUNT(DISTINCT customer_location_key)
        AS unique_location_keys,

    SUM(source_customer_record_count)
        AS represented_customer_records,

    COUNT(*) FILTER (
        WHERE NOT has_geo_reference
    ) AS locations_without_geo_reference,

    COUNT(*) FILTER (
        WHERE has_conflicting_reference_labels
    ) AS locations_with_conflicting_labels,

    COUNT(*) FILTER (
        WHERE has_reference_label_disagreement
    ) AS locations_with_label_disagreements,

    COUNT(*) FILTER (
        WHERE is_reference_coordinate_outlier
    ) AS locations_with_flagged_coordinates,

    COUNT(*) FILTER (
        WHERE has_map_ready_coordinate
    ) AS map_ready_locations,

    COUNT(*) FILTER (
        WHERE (
            has_map_ready_coordinate
            AND (
                map_latitude IS NULL
                OR map_longitude IS NULL
                OR is_reference_coordinate_outlier
            )
        )
        OR (
            NOT has_map_ready_coordinate
            AND (
                map_latitude IS NOT NULL
                OR map_longitude IS NOT NULL
            )
        )
    ) AS inconsistent_map_fields

FROM analytics.dim_customer_geography;


-- =====================================================
-- CHECK C2: Customer location source fidelity
-- =====================================================

WITH expected AS (

    SELECT
        MD5(
            JSONB_BUILD_ARRAY(
                customer_zip_code_prefix,
                customer_city,
                customer_state
            )::TEXT
        ) AS customer_location_key,

        customer_zip_code_prefix,
        customer_city,
        customer_state,

        COUNT(*)::BIGINT
            AS source_customer_record_count,

        BOOL_OR(has_invalid_zip_prefix)
            AS has_invalid_zip_prefix,

        BOOL_OR(has_invalid_state_format)
            AS has_invalid_state_format

    FROM staging.stg_customers

    GROUP BY
        customer_zip_code_prefix,
        customer_city,
        customer_state

)

SELECT
    COUNT(*) FILTER (
        WHERE d.customer_location_key IS NULL
    ) AS missing_dimension_locations,

    COUNT(*) FILTER (
        WHERE e.customer_location_key IS NULL
    ) AS unexpected_dimension_locations,

    COUNT(*) FILTER (
        WHERE e.customer_location_key IS NOT NULL
          AND d.customer_location_key IS NOT NULL
          AND ROW(
              d.customer_zip_code_prefix,
              d.customer_city,
              d.customer_state,
              d.source_customer_record_count,
              d.has_invalid_zip_prefix,
              d.has_invalid_state_format
          ) IS DISTINCT FROM ROW(
              e.customer_zip_code_prefix,
              e.customer_city,
              e.customer_state,
              e.source_customer_record_count,
              e.has_invalid_zip_prefix,
              e.has_invalid_state_format
          )
    ) AS inconsistent_source_attributes

FROM expected AS e

FULL OUTER JOIN analytics.dim_customer_geography AS d
    ON e.customer_location_key =
       d.customer_location_key;


-- =====================================================
-- CHECK C3: Geographic enrichment fidelity
-- =====================================================

WITH expected AS (

    SELECT
        d.customer_location_key,

        g.geolocation_city,
        g.geolocation_state,

        g.representative_latitude,
        g.representative_longitude,

        g.geo_source_row_count,

        (g.geolocation_zip_code_prefix IS NOT NULL)
            AS has_geo_reference,

        COALESCE(
            g.has_conflicting_city_state_labels,
            FALSE
        ) AS has_conflicting_labels,

        (
            g.geolocation_zip_code_prefix IS NOT NULL
            AND (
                d.customer_city IS DISTINCT FROM
                    g.geolocation_city

                OR d.customer_state IS DISTINCT FROM
                    g.geolocation_state
            )
        ) AS has_label_disagreement,

        COALESCE(
            g.is_outside_broad_brazil_box,
            FALSE
        ) AS has_coordinate_outlier,

        (
            NOT d.has_invalid_zip_prefix
            AND g.geolocation_zip_code_prefix IS NOT NULL
            AND g.representative_latitude IS NOT NULL
            AND g.representative_longitude IS NOT NULL
            AND NOT COALESCE(
                g.is_outside_broad_brazil_box,
                FALSE
            )
        ) AS map_ready

    FROM analytics.dim_customer_geography AS d

    LEFT JOIN staging.ref_zip_geolocation AS g
        ON d.customer_zip_code_prefix =
           g.geolocation_zip_code_prefix

)

SELECT
    COUNT(*) AS checked_locations,

    COUNT(*) FILTER (
        WHERE ROW(
            d.reference_city,
            d.reference_state,
            d.representative_latitude,
            d.representative_longitude,
            d.reference_source_row_count,
            d.has_geo_reference,
            d.has_conflicting_reference_labels,
            d.has_reference_label_disagreement,
            d.is_reference_coordinate_outlier,
            d.has_map_ready_coordinate,
            d.map_latitude,
            d.map_longitude
        ) IS DISTINCT FROM ROW(
            e.geolocation_city,
            e.geolocation_state,
            e.representative_latitude,
            e.representative_longitude,
            e.geo_source_row_count,
            e.has_geo_reference,
            e.has_conflicting_labels,
            e.has_label_disagreement,
            e.has_coordinate_outlier,
            e.map_ready,

            CASE
                WHEN e.map_ready
                THEN e.representative_latitude
                ELSE NULL
            END,

            CASE
                WHEN e.map_ready
                THEN e.representative_longitude
                ELSE NULL
            END
        )
    ) AS inconsistent_geographic_attributes

FROM analytics.dim_customer_geography AS d

JOIN expected AS e
    ON d.customer_location_key =
       e.customer_location_key;


-- =====================================================
-- CHECK C4: Safe Customer Geography to Orders join
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
        WHERE d.customer_location_key IS NULL
    ) AS orders_without_location_dimension,

    COUNT(*) FILTER (
        WHERE d.has_geo_reference IS FALSE
    ) AS orders_without_geo_reference,

    COUNT(DISTINCT c.customer_zip_code_prefix)
        FILTER (
            WHERE d.has_geo_reference IS FALSE
        ) AS unmatched_distinct_zip_prefixes,

    COUNT(*) FILTER (
        WHERE d.has_map_ready_coordinate
    ) AS orders_with_map_ready_locations,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE d.has_map_ready_coordinate
        )
        / NULLIF(
            COUNT(*) FILTER (
                WHERE c.customer_zip_code_prefix IS NOT NULL
                  AND NOT c.has_invalid_zip_prefix
            ),
            0
        ),
        2
    ) AS map_ready_order_coverage_pct

FROM staging.stg_orders AS o

LEFT JOIN staging.stg_customers AS c
    ON o.customer_id = c.customer_id

LEFT JOIN analytics.dim_customer_geography AS d
    ON d.customer_location_key = MD5(
        JSONB_BUILD_ARRAY(
            c.customer_zip_code_prefix,
            c.customer_city,
            c.customer_state
        )::TEXT
    );
