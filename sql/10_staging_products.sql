
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 5.1 - TASK 5
-- MODEL: staging.stg_products
-- =====================================================

-- CHECK A: Validate RAW Products baseline

SELECT
    COUNT(*) AS total_products,

    COUNT(DISTINCT product_id)
        AS unique_product_ids,

    COUNT(*) FILTER (
        WHERE product_id IS NULL
           OR BTRIM(product_id) = ''
    ) AS missing_product_ids,

    COUNT(*) FILTER (
        WHERE NULLIF(
            BTRIM(product_category_name), ''
        ) IS NULL
    ) AS missing_source_categories,

    COUNT(*) FILTER (
        WHERE product_name_lenght IS NULL
           OR product_description_lenght IS NULL
           OR product_photos_qty IS NULL
    ) AS missing_catalog_attributes,

    COUNT(*) FILTER (
        WHERE product_weight_g IS NULL
           OR product_length_cm IS NULL
           OR product_height_cm IS NULL
           OR product_width_cm IS NULL
    ) AS missing_physical_attributes,

    COUNT(*) FILTER (
        WHERE product_weight_g = 0
    ) AS zero_weight_products,

    COUNT(*) FILTER (
        WHERE product_weight_g < 0
           OR product_length_cm < 0
           OR product_height_cm < 0
           OR product_width_cm < 0
    ) AS negative_physical_values

FROM raw.products;


-- =====================================================
-- CHECK B: Create Products STAGING view
-- =====================================================

CREATE OR REPLACE VIEW staging.stg_products AS

WITH standardized_products AS (

    SELECT
        p.product_id,

        -- Preserve and standardize source category
        NULLIF(
            LOWER(BTRIM(p.product_category_name)),
            ''
        ) AS product_category_name_pt,

        -- Correct original source spelling
        p.product_name_lenght
            AS product_name_length,

        p.product_description_lenght
            AS product_description_length,

        p.product_photos_qty,

        -- Preserve physical measurements
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm

    FROM raw.products AS p

),

standardized_translations AS (

    SELECT
        NULLIF(
            LOWER(BTRIM(product_category_name)),
            ''
        ) AS category_name_pt,

        NULLIF(
            LOWER(BTRIM(product_category_name_english)),
            ''
        ) AS category_name_en

    FROM raw.category_translation

),

products_with_translations AS (

    SELECT
        p.*,

        t.category_name_en
            AS product_category_name_en

    FROM standardized_products AS p

    LEFT JOIN standardized_translations AS t
        ON p.product_category_name_pt =
           t.category_name_pt

)

SELECT
    product_id,

    -- Original and translated category names
    product_category_name_pt,
    product_category_name_en,

    -- Display fallback; does not invent a translation
    COALESCE(
        product_category_name_en,
        product_category_name_pt,
        'Uncategorized'
    ) AS category_display_name,

    -- Explicit category completeness status
    CASE
        WHEN product_category_name_pt IS NULL
            THEN 'MISSING_SOURCE_CATEGORY'

        WHEN product_category_name_en IS NULL
            THEN 'UNTRANSLATED'

        ELSE 'TRANSLATED'
    END AS category_status,

    -- Standardized catalog attributes
    product_name_length,
    product_description_length,
    product_photos_qty,

    -- Original physical measurements
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,

    -- Data-quality flags
    (
        product_category_name_pt IS NULL
    ) AS is_missing_source_category,

    (
        product_category_name_pt IS NOT NULL
        AND product_category_name_en IS NULL
    ) AS is_untranslated_category,

    (
        product_name_length IS NULL
        OR product_description_length IS NULL
        OR product_photos_qty IS NULL
    ) AS has_missing_catalog_attributes,

    (
        product_weight_g IS NULL
        OR product_length_cm IS NULL
        OR product_height_cm IS NULL
        OR product_width_cm IS NULL
    ) AS has_missing_physical_attributes,

    COALESCE(
        product_weight_g = 0,
        FALSE
    ) AS is_zero_weight

FROM products_with_translations;


-- =====================================================
-- CHECK C: Validate staging.stg_products
-- =====================================================

SELECT
    COUNT(*) AS total_products,

    COUNT(DISTINCT product_id)
        AS unique_product_ids,

    COUNT(*) FILTER (
        WHERE category_status = 'TRANSLATED'
    ) AS translated_products,

    COUNT(*) FILTER (
        WHERE category_status = 'UNTRANSLATED'
    ) AS untranslated_products,

    COUNT(*) FILTER (
        WHERE category_status = 'MISSING_SOURCE_CATEGORY'
    ) AS missing_source_categories,

    COUNT(DISTINCT product_category_name_pt)
        FILTER (
            WHERE is_untranslated_category
        ) AS distinct_untranslated_categories,

    COUNT(*) FILTER (
        WHERE has_missing_catalog_attributes
    ) AS missing_catalog_attributes,

    COUNT(*) FILTER (
        WHERE has_missing_physical_attributes
    ) AS missing_physical_attributes,

    COUNT(*) FILTER (
        WHERE is_zero_weight
    ) AS zero_weight_products,

    COUNT(*) FILTER (
        WHERE category_display_name IS NULL
    ) AS missing_display_labels

FROM staging.stg_products;
