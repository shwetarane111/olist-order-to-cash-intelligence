
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 5.1 - TASK 6
-- MODEL: staging.stg_sellers
-- =====================================================

-- CHECK A: Validate RAW Sellers baseline

SELECT
    COUNT(*) AS total_sellers,

    COUNT(DISTINCT seller_id)
        AS unique_seller_ids,

    COUNT(*) FILTER (
        WHERE seller_id IS NULL
           OR BTRIM(seller_id) = ''
    ) AS missing_seller_ids,

    COUNT(*) FILTER (
        WHERE seller_city IS NULL
           OR BTRIM(seller_city) = ''
    ) AS missing_cities,

    COUNT(*) FILTER (
        WHERE seller_zip_code_prefix IS NULL
           OR BTRIM(seller_zip_code_prefix)
              !~ '^[0-9]{5}$'
    ) AS invalid_zip_prefixes,

    COUNT(*) FILTER (
        WHERE seller_state IS NULL
           OR UPPER(BTRIM(seller_state))
              !~ '^[A-Z]{2}$'
    ) AS invalid_state_formats,

    COUNT(*) FILTER (
        WHERE BTRIM(seller_zip_code_prefix)
              LIKE '0%'
    ) AS zip_prefixes_starting_with_zero

FROM raw.sellers;


-- =====================================================
-- CHECK B: Create Sellers STAGING view
-- =====================================================

CREATE OR REPLACE VIEW staging.stg_sellers AS

WITH standardized AS (

    SELECT
        -- Preserve original seller identifier
        s.seller_id,

        -- Preserve ZIP prefix as text
        NULLIF(
            BTRIM(s.seller_zip_code_prefix),
            ''
        ) AS seller_zip_code_prefix,

        -- Standardize city spelling format
        NULLIF(
            LOWER(BTRIM(s.seller_city)),
            ''
        ) AS seller_city,

        -- Standardize state-code format
        NULLIF(
            UPPER(BTRIM(s.seller_state)),
            ''
        ) AS seller_state

    FROM raw.sellers AS s

)

SELECT
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state,

    -- Missing or incorrectly formatted ZIP prefix
    COALESCE(
        seller_zip_code_prefix
            !~ '^[0-9]{5}$',
        TRUE
    ) AS has_invalid_zip_prefix,

    -- Missing or incorrectly formatted state code
    COALESCE(
        seller_state
            !~ '^[A-Z]{2}$',
        TRUE
    ) AS has_invalid_state_format

FROM standardized;


-- =====================================================
-- CHECK C: Validate staging.stg_sellers
-- =====================================================

SELECT
    COUNT(*) AS total_sellers,

    COUNT(DISTINCT seller_id)
        AS unique_seller_ids,

    COUNT(*) FILTER (
        WHERE seller_id IS NULL
           OR BTRIM(seller_id) = ''
    ) AS missing_seller_ids,

    COUNT(*) FILTER (
        WHERE seller_city IS NULL
    ) AS missing_cities,

    COUNT(*) FILTER (
        WHERE has_invalid_zip_prefix
    ) AS invalid_zip_prefixes,

    COUNT(*) FILTER (
        WHERE has_invalid_state_format
    ) AS invalid_state_formats,

    COUNT(*) FILTER (
        WHERE seller_zip_code_prefix LIKE '0%'
    ) AS zip_prefixes_starting_with_zero

FROM staging.stg_sellers;
