
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 5.1 - TASK 9
-- MODEL: staging.ref_zip_geolocation
-- =====================================================

-- CHECK A: Geographic reference readiness

SELECT
    COUNT(*) AS total_geo_rows,

    COUNT(DISTINCT geolocation_zip_code_prefix)
        AS distinct_zip_prefixes,

    COUNT(*) FILTER (
        WHERE has_invalid_zip_prefix
           OR has_missing_city
           OR has_invalid_state_format
           OR has_invalid_coordinates
    ) AS ineligible_source_rows,

    COUNT(*) FILTER (
        WHERE latitude NOT BETWEEN -34 AND 6
           OR longitude NOT BETWEEN -74 AND -28
    ) AS outside_broad_brazil_box

FROM staging.stg_geolocation;


-- =====================================================
-- CHECK B: Create one-row-per-ZIP materialized view
-- =====================================================

CREATE MATERIALIZED VIEW staging.ref_zip_geolocation AS

WITH eligible AS (

    -- Use the validated geographic records
    SELECT
        geolocation_zip_code_prefix,
        latitude,
        longitude,
        geolocation_city,
        geolocation_state

    FROM staging.stg_geolocation

    WHERE NOT has_invalid_zip_prefix
      AND NOT has_missing_city
      AND NOT has_invalid_state_format
      AND NOT has_invalid_coordinates

),

zip_statistics AS (

    -- Count source records and label combinations
    SELECT
        geolocation_zip_code_prefix,

        COUNT(*) AS geo_source_row_count,

        COUNT(
            DISTINCT (
                geolocation_city,
                geolocation_state
            )
        ) AS distinct_city_state_pairs

    FROM eligible

    GROUP BY geolocation_zip_code_prefix

),

label_counts AS (

    -- Count each city/state combination per ZIP
    SELECT
        geolocation_zip_code_prefix,
        geolocation_city,
        geolocation_state,

        COUNT(*) AS label_row_count

    FROM eligible

    GROUP BY
        geolocation_zip_code_prefix,
        geolocation_city,
        geolocation_state

),

ranked_labels AS (

    -- Prefer the most frequent combination
    -- Break frequency ties deterministically
    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY geolocation_zip_code_prefix

            ORDER BY
                label_row_count DESC,
                geolocation_state ASC,
                geolocation_city ASC
        ) AS label_rank

    FROM label_counts

),

preferred_labels AS (

    SELECT
        geolocation_zip_code_prefix,
        geolocation_city,
        geolocation_state,
        label_row_count

    FROM ranked_labels

    WHERE label_rank = 1

),

preferred_points AS (

    -- Keep points belonging to the selected label
    SELECT
        e.geolocation_zip_code_prefix,
        e.latitude,
        e.longitude,
        e.geolocation_city,
        e.geolocation_state

    FROM eligible AS e

    INNER JOIN preferred_labels AS p
        ON e.geolocation_zip_code_prefix =
           p.geolocation_zip_code_prefix

       AND e.geolocation_city =
           p.geolocation_city

       AND e.geolocation_state =
           p.geolocation_state

),

median_points AS (

    -- Calculate robust reference coordinates
    SELECT
        geolocation_zip_code_prefix,

        PERCENTILE_CONT(0.5)
            WITHIN GROUP (
                ORDER BY latitude
            ) AS median_latitude,

        PERCENTILE_CONT(0.5)
            WITHIN GROUP (
                ORDER BY longitude
            ) AS median_longitude

    FROM preferred_points

    GROUP BY geolocation_zip_code_prefix

),

ranked_points AS (

    -- Choose an observed point nearest the medians
    SELECT
        p.*,

        ROW_NUMBER() OVER (
            PARTITION BY p.geolocation_zip_code_prefix

            ORDER BY

                -- Prefer broad-Brazil-screened points
                CASE
                    WHEN p.latitude BETWEEN -34 AND 6
                     AND p.longitude BETWEEN -74 AND -28
                    THEN 0
                    ELSE 1
                END,

                -- Approximate geographic closeness
                POWER(
                    p.latitude - m.median_latitude,
                    2
                )
                +
                POWER(
                    (
                        p.longitude - m.median_longitude
                    ) * COS(RADIANS(m.median_latitude)),
                    2
                ),

                -- Deterministic coordinate tie-breakers
                p.latitude ASC,
                p.longitude ASC

        ) AS coordinate_rank

    FROM preferred_points AS p

    INNER JOIN median_points AS m
        ON p.geolocation_zip_code_prefix =
           m.geolocation_zip_code_prefix

)

SELECT
    r.geolocation_zip_code_prefix,

    r.latitude AS representative_latitude,
    r.longitude AS representative_longitude,

    r.geolocation_city,
    r.geolocation_state,

    z.geo_source_row_count,
    l.label_row_count AS selected_label_row_count,
    z.distinct_city_state_pairs,

    (
        z.distinct_city_state_pairs > 1
    ) AS has_conflicting_city_state_labels,

    (
        r.latitude NOT BETWEEN -34 AND 6
        OR r.longitude NOT BETWEEN -74 AND -28
    ) AS is_outside_broad_brazil_box,

    'modal_city_state_observed_point_nearest_median'
        ::TEXT AS selection_method

FROM ranked_points AS r

INNER JOIN zip_statistics AS z
    ON r.geolocation_zip_code_prefix =
       z.geolocation_zip_code_prefix

INNER JOIN preferred_labels AS l
    ON r.geolocation_zip_code_prefix =
       l.geolocation_zip_code_prefix

WHERE r.coordinate_rank = 1

WITH DATA;


-- =====================================================
-- Enforce one row per ZIP prefix
-- =====================================================

CREATE UNIQUE INDEX
    ux_ref_zip_geolocation_prefix

ON staging.ref_zip_geolocation (
    geolocation_zip_code_prefix
);


-- =====================================================
-- CHECK C: Validate ZIP reference
-- =====================================================

SELECT
    COUNT(*) AS total_zip_records,

    COUNT(DISTINCT geolocation_zip_code_prefix)
        AS distinct_zip_prefixes,

    SUM(geo_source_row_count)
        AS represented_source_rows,

    COUNT(*) FILTER (
        WHERE geo_source_row_count > 1
    ) AS zips_with_multiple_source_rows,

    MAX(geo_source_row_count)
        AS maximum_rows_per_zip,

    COUNT(*) FILTER (
        WHERE has_conflicting_city_state_labels
    ) AS zips_with_conflicting_location_labels,

    COUNT(*) FILTER (
        WHERE is_outside_broad_brazil_box
    ) AS selected_points_outside_broad_box,

    COUNT(*) FILTER (
        WHERE representative_latitude IS NULL
           OR representative_longitude IS NULL
    ) AS missing_representative_coordinates

FROM staging.ref_zip_geolocation;


-- =====================================================
-- CHECK D1: Validate safe geographic joins
-- =====================================================

SELECT
    'customers' AS dataset,

    (
        SELECT COUNT(*)
        FROM staging.stg_customers
    ) AS source_rows,

    (
        SELECT COUNT(*)
        FROM staging.stg_customers AS c

        LEFT JOIN staging.ref_zip_geolocation AS g
            ON c.customer_zip_code_prefix =
               g.geolocation_zip_code_prefix
    ) AS rows_after_join

UNION ALL

SELECT
    'sellers',

    (
        SELECT COUNT(*)
        FROM staging.stg_sellers
    ),

    (
        SELECT COUNT(*)
        FROM staging.stg_sellers AS s

        LEFT JOIN staging.ref_zip_geolocation AS g
            ON s.seller_zip_code_prefix =
               g.geolocation_zip_code_prefix
    );


-- =====================================================
-- CHECK D2: Unmatched distinct ZIP prefixes
-- =====================================================

SELECT
    'customers' AS dataset,
    COUNT(*) AS unmatched_distinct_zips

FROM (
    SELECT DISTINCT customer_zip_code_prefix
    FROM staging.stg_customers
) AS c

LEFT JOIN staging.ref_zip_geolocation AS g
    ON c.customer_zip_code_prefix =
       g.geolocation_zip_code_prefix

WHERE g.geolocation_zip_code_prefix IS NULL

UNION ALL

SELECT
    'sellers',
    COUNT(*)

FROM (
    SELECT DISTINCT seller_zip_code_prefix
    FROM staging.stg_sellers
) AS s

LEFT JOIN staging.ref_zip_geolocation AS g
    ON s.seller_zip_code_prefix =
       g.geolocation_zip_code_prefix

WHERE g.geolocation_zip_code_prefix IS NULL;
