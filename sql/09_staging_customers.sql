
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 5.1 - TASK 4
-- MODEL: staging.stg_customers
-- =====================================================

-- CHECK A: Validate RAW customer records

SELECT
    COUNT(*) AS total_customer_rows,

    COUNT(DISTINCT customer_id)
        AS unique_customer_ids,

    COUNT(DISTINCT customer_unique_id)
        AS unique_customer_identities,

    COUNT(*) FILTER (
        WHERE customer_id IS NULL
           OR BTRIM(customer_id) = ''
           OR customer_unique_id IS NULL
           OR BTRIM(customer_unique_id) = ''
    ) AS missing_customer_identifiers,

    COUNT(*) FILTER (
        WHERE customer_city IS NULL
           OR BTRIM(customer_city) = ''
    ) AS missing_cities,

    COUNT(*) FILTER (
        WHERE customer_zip_code_prefix IS NULL
           OR BTRIM(customer_zip_code_prefix)
              !~ '^[0-9]{5}$'
    ) AS invalid_zip_prefixes,

    COUNT(*) FILTER (
        WHERE customer_state IS NULL
           OR UPPER(BTRIM(customer_state))
              !~ '^[A-Z]{2}$'
    ) AS invalid_state_formats,

    COUNT(*) FILTER (
        WHERE BTRIM(customer_zip_code_prefix)
              LIKE '0%'
    ) AS zip_prefixes_starting_with_zero

FROM raw.customers;


-- =====================================================
-- CHECK B: Create Customers STAGING view
-- =====================================================

CREATE OR REPLACE VIEW staging.stg_customers AS

WITH standardized AS (

    SELECT
        -- Preserve source customer identifiers
        c.customer_id,
        c.customer_unique_id,

        -- Preserve ZIP prefixes as TEXT
        NULLIF(
            BTRIM(c.customer_zip_code_prefix),
            ''
        ) AS customer_zip_code_prefix,

        -- Standardize geographic text
        NULLIF(
            LOWER(BTRIM(c.customer_city)),
            ''
        ) AS customer_city,

        NULLIF(
            UPPER(BTRIM(c.customer_state)),
            ''
        ) AS customer_state

    FROM raw.customers AS c

)

SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,

    -- Flag invalid ZIP formats
    COALESCE(
        customer_zip_code_prefix
            !~ '^[0-9]{5}$',
        TRUE
    ) AS has_invalid_zip_prefix,

    -- Flag invalid state-code formats
    COALESCE(
        customer_state
            !~ '^[A-Z]{2}$',
        TRUE
    ) AS has_invalid_state_format

FROM standardized;


-- =====================================================
-- CHECK C: Validate staging.stg_customers
-- =====================================================

SELECT
    COUNT(*) AS total_customer_rows,

    COUNT(DISTINCT customer_id)
        AS unique_customer_ids,

    COUNT(DISTINCT customer_unique_id)
        AS unique_customer_identities,

    COUNT(*) FILTER (
        WHERE customer_id IS NULL
           OR customer_unique_id IS NULL
    ) AS missing_customer_identifiers,

    COUNT(*) FILTER (
        WHERE customer_city IS NULL
    ) AS missing_cities,

    COUNT(*) FILTER (
        WHERE has_invalid_zip_prefix
    ) AS invalid_zip_prefixes,

    COUNT(*) FILTER (
        WHERE has_invalid_state_format
    ) AS invalid_state_formats,

    COUNT(*) FILTER (
        WHERE customer_zip_code_prefix
              LIKE '0%'
    ) AS zip_prefixes_starting_with_zero

FROM staging.stg_customers;
