
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 6.2 - TASK 2
-- MODEL: analytics.dim_product
-- SOURCE: staging.stg_products
-- =====================================================

-- CHECK A1: Source readiness

SELECT
    COUNT(*) AS total_products,

    COUNT(DISTINCT product_id)
        AS distinct_product_ids,

    COUNT(*) FILTER (
        WHERE product_id IS NULL
           OR BTRIM(product_id) = ''
    ) AS missing_product_ids,

    COUNT(*) FILTER (
        WHERE category_status = 'TRANSLATED'
    ) AS translated_products,

    COUNT(*) FILTER (
        WHERE category_status = 'UNTRANSLATED'
    ) AS untranslated_products,

    COUNT(*) FILTER (
        WHERE category_status = 'MISSING_SOURCE_CATEGORY'
    ) AS missing_source_categories,

    COUNT(*) FILTER (
        WHERE category_display_name IS NULL
           OR BTRIM(category_display_name) = ''
    ) AS missing_display_labels

FROM staging.stg_products;


-- CHECK A2: Inspect STAGING product columns

SELECT
    ordinal_position,
    column_name,
    data_type

FROM information_schema.columns

WHERE table_schema = 'staging'
  AND table_name = 'stg_products'

ORDER BY ordinal_position;


-- =====================================================
-- CHECK B: Create analytics.dim_product
-- =====================================================

BEGIN;

CREATE TABLE analytics.dim_product AS

SELECT
    -- Product identifier
    product_id,

    -- Category attributes
    product_category_name_pt,
    product_category_name_en,
    category_display_name,
    category_status,

    -- Catalog attributes
    product_name_length,
    product_description_length,
    product_photos_qty,

    -- Physical attributes
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,

    -- Data-quality indicators
    is_untranslated_category,
    has_missing_catalog_attributes,
    has_missing_physical_attributes,
    is_zero_weight

FROM staging.stg_products

WITH DATA;


-- Enforce one row per product
ALTER TABLE analytics.dim_product

ADD CONSTRAINT dim_product_pkey

PRIMARY KEY (product_id);


-- Require valid category classifications
ALTER TABLE analytics.dim_product

ADD CONSTRAINT chk_dim_product_category_status

CHECK (
    category_status IN (
        'TRANSLATED',
        'UNTRANSLATED',
        'MISSING_SOURCE_CATEGORY'
    )
);


-- Require a category classification and display label
ALTER TABLE analytics.dim_product

ALTER COLUMN category_status SET NOT NULL;


ALTER TABLE analytics.dim_product

ALTER COLUMN category_display_name SET NOT NULL;


COMMIT;


-- =====================================================
-- CHECK C1: Product dimension quality
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
           OR BTRIM(category_display_name) = ''
    ) AS missing_display_labels

FROM analytics.dim_product;


-- =====================================================
-- CHECK C2: Exact source-to-dimension comparison
-- =====================================================

WITH source_products AS (

    SELECT
        product_id,
        product_category_name_pt,
        product_category_name_en,
        category_display_name,
        category_status,
        product_name_length,
        product_description_length,
        product_photos_qty,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm,
        is_untranslated_category,
        has_missing_catalog_attributes,
        has_missing_physical_attributes,
        is_zero_weight

    FROM staging.stg_products

),

source_only AS (

    SELECT * FROM source_products

    EXCEPT ALL

    SELECT * FROM analytics.dim_product

),

dimension_only AS (

    SELECT * FROM analytics.dim_product

    EXCEPT ALL

    SELECT * FROM source_products

)

SELECT
    (SELECT COUNT(*) FROM source_only)
        AS source_only_rows,

    (SELECT COUNT(*) FROM dimension_only)
        AS dimension_only_rows;


-- =====================================================
-- CHECK C3: Product-to-Order-Items relationship
-- =====================================================

SELECT
    (
        SELECT COUNT(*)
        FROM staging.stg_order_items
    ) AS source_item_rows,

    COUNT(*) AS rows_after_join,

    COUNT(*) FILTER (
        WHERE p.product_id IS NULL
    ) AS unmatched_product_rows

FROM staging.stg_order_items AS oi

LEFT JOIN analytics.dim_product AS p
    ON oi.product_id = p.product_id;
