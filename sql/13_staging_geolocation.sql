
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 5.1 - TASK 8
-- MODEL: staging.stg_geolocation
-- =====================================================

-- CHECK A: Validate RAW Geolocation baseline

SELECT
    COUNT(*) AS total_geo_rows,

    COUNT(DISTINCT geolocation_zip_code_prefix)
        AS distinct_zip_prefixes,

    COUNT(DISTINCT geolocation_state)
        AS distinct_state_codes,

    COUNT(*) FILTER (
        WHERE geolocation_zip_code_prefix IS NULL
           OR BTRIM(geolocation_zip_code_prefix)
              !~ '^[0-9]{5}$'
    ) AS invalid_zip_prefixes,

    COUNT(*) FILTER (
        WHERE geolocation_city IS NULL
           OR BTRIM(geolocation_city) = ''
    ) AS missing_cities,

    COUNT(*) FILTER (
        WHERE geolocation_state IS NULL
           OR UPPER(BTRIM(geolocation_state))
              !~ '^[A-Z]{2}$'
    ) AS invalid_state_formats,

    COUNT(*) FILTER (
        WHERE geolocation_lat IS NULL
           OR geolocation_lng IS NULL
    ) AS missing_coordinates,

    COUNT(*) FILTER (
        WHERE geolocation_lat NOT BETWEEN -90 AND 90
           OR geolocation_lng NOT BETWEEN -180 AND 180
    ) AS globally_invalid_coordinates

FROM raw.geolocation;


-- =====================================================
-- CHECK B: Create Geolocation STAGING view
-- =====================================================

CREATE OR REPLACE VIEW staging.stg_geolocation AS

WITH standardized AS (

    SELECT
        -- Preserve ZIP prefixes as TEXT
        NULLIF(
            BTRIM(g.geolocation_zip_code_prefix),
            ''
        ) AS geolocation_zip_code_prefix,

        -- Preserve original coordinate values
        g.geolocation_lat AS latitude,
        g.geolocation_lng AS longitude,

        -- Standardize city and state text
        NULLIF(
            LOWER(BTRIM(g.geolocation_city)),
            ''
        ) AS geolocation_city,

        NULLIF(
            UPPER(BTRIM(g.geolocation_state)),
            ''
        ) AS geolocation_state

    FROM raw.geolocation AS g

)

SELECT
    geolocation_zip_code_prefix,
    latitude,
    longitude,
    geolocation_city,
    geolocation_state,

    -- Invalid ZIP prefix
    (
        geolocation_zip_code_prefix IS NULL
        OR geolocation_zip_code_prefix
            !~ '^[0-9]{5}$'
    ) AS has_invalid_zip_prefix,

    -- Missing city
    (
        geolocation_city IS NULL
    ) AS has_missing_city,

    -- Invalid state-code format
    (
        geolocation_state IS NULL
        OR geolocation_state
            !~ '^[A-Z]{2}$'
    ) AS has_invalid_state_format,

    -- Missing or globally invalid coordinates
    (
        latitude IS NULL
        OR longitude IS NULL
        OR latitude NOT BETWEEN -90 AND 90
        OR longitude NOT BETWEEN -180 AND 180
    ) AS has_invalid_coordinates

FROM standardized;


-- =====================================================
-- CHECK C: Validate staging.stg_geolocation
-- =====================================================

SELECT
    COUNT(*) AS total_geo_rows,

    COUNT(DISTINCT geolocation_zip_code_prefix)
        AS distinct_zip_prefixes,

    COUNT(DISTINCT geolocation_state)
        AS distinct_state_codes,

    COUNT(*) FILTER (
        WHERE has_invalid_zip_prefix
    ) AS invalid_zip_prefixes,

    COUNT(*) FILTER (
        WHERE has_missing_city
    ) AS missing_cities,

    COUNT(*) FILTER (
        WHERE has_invalid_state_format
    ) AS invalid_state_formats,

    COUNT(*) FILTER (
        WHERE has_invalid_coordinates
    ) AS invalid_coordinates

FROM staging.stg_geolocation;


-- =====================================================
-- CHECK D2: Verify repeated ZIP prefixes
-- =====================================================

WITH zip_counts AS (

    SELECT
        geolocation_zip_code_prefix,
        COUNT(*) AS geo_rows

    FROM staging.stg_geolocation

    GROUP BY geolocation_zip_code_prefix

)

SELECT
    COUNT(*) AS distinct_zip_prefixes,

    COUNT(*) FILTER (
        WHERE geo_rows > 1
    ) AS zip_prefixes_with_multiple_rows,

    MAX(geo_rows)
        AS maximum_rows_for_one_zip

FROM zip_counts;


-- =====================================================
-- CHECK D2: Verify repeated ZIP prefixes
-- =====================================================

WITH zip_counts AS (

    SELECT
        geolocation_zip_code_prefix,
        COUNT(*) AS geo_rows

    FROM staging.stg_geolocation

    GROUP BY geolocation_zip_code_prefix

)

SELECT
    COUNT(*) AS distinct_zip_prefixes,

    COUNT(*) FILTER (
        WHERE geo_rows > 1
    ) AS zip_prefixes_with_multiple_rows,

    MAX(geo_rows)
        AS maximum_rows_for_one_zip

FROM zip_counts;
