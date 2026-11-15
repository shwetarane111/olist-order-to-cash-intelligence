
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 6.2 - TASK 3
-- MODEL: analytics.dim_seller
-- =====================================================

-- CHECK A1: Seller source readiness

SELECT
    COUNT(*) AS total_sellers,

    COUNT(DISTINCT seller_id)
        AS distinct_seller_ids,

    COUNT(*) FILTER (
        WHERE seller_id IS NULL
           OR BTRIM(seller_id) = ''
    ) AS missing_seller_ids,

    COUNT(*) FILTER (
        WHERE has_invalid_zip_prefix
    ) AS invalid_zip_prefixes,

    COUNT(*) FILTER (
        WHERE has_invalid_state_format
    ) AS invalid_state_formats,

    COUNT(*) FILTER (
        WHERE seller_zip_code_prefix LIKE '0%'
    ) AS sellers_with_leading_zero_zips

FROM staging.stg_sellers;


-- CHECK A2: Geographic reference coverage

SELECT
    COUNT(*) AS seller_rows_after_join,

    COUNT(*) FILTER (
        WHERE g.geolocation_zip_code_prefix IS NULL
    ) AS sellers_without_geo_reference,

    COUNT(DISTINCT s.seller_zip_code_prefix)
        FILTER (
            WHERE g.geolocation_zip_code_prefix IS NULL
        ) AS unmatched_distinct_zip_prefixes,

    COUNT(*) FILTER (
        WHERE g.is_outside_broad_brazil_box
    ) AS sellers_linked_to_coordinate_outliers,

    COUNT(*) FILTER (
        WHERE g.geolocation_zip_code_prefix IS NOT NULL
          AND (
              s.seller_city IS DISTINCT FROM
                  g.geolocation_city

              OR s.seller_state IS DISTINCT FROM
                  g.geolocation_state
          )
    ) AS seller_reference_label_differences

FROM staging.stg_sellers AS s

LEFT JOIN staging.ref_zip_geolocation AS g
    ON s.seller_zip_code_prefix =
       g.geolocation_zip_code_prefix;


-- =====================================================
-- CHECK B: Create analytics.dim_seller
-- =====================================================

BEGIN;

CREATE TABLE analytics.dim_seller AS

SELECT

    -- Original seller identity and location
    s.seller_id,
    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state,

    -- Source-quality flags
    s.has_invalid_zip_prefix,
    s.has_invalid_state_format,

    -- Reference location labels
    g.geolocation_city AS reference_city,
    g.geolocation_state AS reference_state,

    -- Representative observed coordinates
    g.representative_latitude,
    g.representative_longitude,

    -- Geographic reference metadata
    g.geo_source_row_count AS reference_source_row_count,

    -- Does the seller ZIP have a geographic match?
    (
        g.geolocation_zip_code_prefix IS NOT NULL
    ) AS has_geo_reference,

    -- Does the reference ZIP contain multiple
    -- city/state combinations?
    COALESCE(
        g.has_conflicting_city_state_labels,
        FALSE
    ) AS has_conflicting_reference_labels,

    -- Do the seller and reference labels disagree?
    (
        g.geolocation_zip_code_prefix IS NOT NULL
        AND (
            s.seller_city IS DISTINCT FROM
                g.geolocation_city

            OR s.seller_state IS DISTINCT FROM
                g.geolocation_state
        )
    ) AS has_reference_label_disagreement,

    -- Is the representative coordinate flagged?
    COALESCE(
        g.is_outside_broad_brazil_box,
        FALSE
    ) AS is_reference_coordinate_outlier,

    -- Can the coordinate be used on our map?
    (
        g.geolocation_zip_code_prefix IS NOT NULL

        AND g.representative_latitude IS NOT NULL

        AND g.representative_longitude IS NOT NULL

        AND NOT COALESCE(
            g.is_outside_broad_brazil_box,
            FALSE
        )
    ) AS has_map_ready_coordinate,

    -- Safe latitude for Power BI maps
    CASE
        WHEN g.geolocation_zip_code_prefix IS NOT NULL
         AND g.representative_latitude IS NOT NULL
         AND g.representative_longitude IS NOT NULL
         AND NOT COALESCE(
             g.is_outside_broad_brazil_box,
             FALSE
         )
        THEN g.representative_latitude
        ELSE NULL
    END AS map_latitude,

    -- Safe longitude for Power BI maps
    CASE
        WHEN g.geolocation_zip_code_prefix IS NOT NULL
         AND g.representative_latitude IS NOT NULL
         AND g.representative_longitude IS NOT NULL
         AND NOT COALESCE(
             g.is_outside_broad_brazil_box,
             FALSE
         )
        THEN g.representative_longitude
        ELSE NULL
    END AS map_longitude

FROM staging.stg_sellers AS s

LEFT JOIN staging.ref_zip_geolocation AS g
    ON s.seller_zip_code_prefix =
       g.geolocation_zip_code_prefix

WITH DATA;


-- Enforce the Seller dimension grain

ALTER TABLE analytics.dim_seller

ADD CONSTRAINT dim_seller_pkey

PRIMARY KEY (seller_id);


-- Map-ready coordinates must be complete and safe

ALTER TABLE analytics.dim_seller

ADD CONSTRAINT chk_dim_seller_map_ready

CHECK (
    NOT has_map_ready_coordinate
    OR (
        map_latitude IS NOT NULL
        AND map_longitude IS NOT NULL
        AND NOT is_reference_coordinate_outlier
    )
);


-- Do not allow only one mapping coordinate

ALTER TABLE analytics.dim_seller

ADD CONSTRAINT chk_dim_seller_map_coordinate_pair

CHECK (
    (map_latitude IS NULL)
    =
    (map_longitude IS NULL)
);


COMMIT;


-- =====================================================
-- CHECK C1: Seller dimension quality
-- =====================================================

SELECT
    COUNT(*) AS total_sellers,

    COUNT(DISTINCT seller_id)
        AS unique_seller_ids,

    COUNT(*) FILTER (
        WHERE seller_zip_code_prefix LIKE '0%'
    ) AS sellers_with_leading_zero_zips,

    COUNT(*) FILTER (
        WHERE has_invalid_zip_prefix
           OR has_invalid_state_format
    ) AS invalid_source_location_flags,

    COUNT(*) FILTER (
        WHERE NOT has_geo_reference
    ) AS sellers_without_geo_reference,

    COUNT(*) FILTER (
        WHERE has_conflicting_reference_labels
    ) AS sellers_with_conflicting_reference_labels,

    COUNT(*) FILTER (
        WHERE has_reference_label_disagreement
    ) AS sellers_with_label_disagreements,

    COUNT(*) FILTER (
        WHERE is_reference_coordinate_outlier
    ) AS sellers_with_flagged_coordinates,

    COUNT(*) FILTER (
        WHERE has_map_ready_coordinate
    ) AS map_ready_sellers,

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

FROM analytics.dim_seller;


-- =====================================================
-- CHECK C2: Source-to-dimension fidelity
-- =====================================================

SELECT

    COUNT(*) AS checked_sellers,

    COUNT(*) FILTER (
        WHERE d.seller_id IS NULL
    ) AS missing_dimension_sellers,

    COUNT(*) FILTER (
        WHERE ROW(
            d.seller_zip_code_prefix,
            d.seller_city,
            d.seller_state,
            d.has_invalid_zip_prefix,
            d.has_invalid_state_format
        ) IS DISTINCT FROM ROW(
            s.seller_zip_code_prefix,
            s.seller_city,
            s.seller_state,
            s.has_invalid_zip_prefix,
            s.has_invalid_state_format
        )
    ) AS source_attribute_differences,

    COUNT(*) FILTER (
        WHERE ROW(
            d.reference_city,
            d.reference_state,
            d.representative_latitude,
            d.representative_longitude,
            d.reference_source_row_count,
            d.has_geo_reference,
            d.has_conflicting_reference_labels,
            d.is_reference_coordinate_outlier
        ) IS DISTINCT FROM ROW(
            g.geolocation_city,
            g.geolocation_state,
            g.representative_latitude,
            g.representative_longitude,
            g.geo_source_row_count,
            (g.geolocation_zip_code_prefix IS NOT NULL),
            COALESCE(
                g.has_conflicting_city_state_labels,
                FALSE
            ),
            COALESCE(
                g.is_outside_broad_brazil_box,
                FALSE
            )
        )
    ) AS reference_attribute_differences,

    COUNT(*) FILTER (
        WHERE d.has_reference_label_disagreement
              IS DISTINCT FROM (
                  g.geolocation_zip_code_prefix IS NOT NULL
                  AND (
                      s.seller_city IS DISTINCT FROM
                          g.geolocation_city
                      OR s.seller_state IS DISTINCT FROM
                          g.geolocation_state
                  )
              )

           OR d.has_map_ready_coordinate
              IS DISTINCT FROM (
                  g.geolocation_zip_code_prefix IS NOT NULL
                  AND g.representative_latitude IS NOT NULL
                  AND g.representative_longitude IS NOT NULL
                  AND NOT COALESCE(
                      g.is_outside_broad_brazil_box,
                      FALSE
                  )
              )

           OR d.map_latitude
              IS DISTINCT FROM (
                  CASE
                      WHEN g.geolocation_zip_code_prefix
                               IS NOT NULL
                       AND g.representative_latitude IS NOT NULL
                       AND g.representative_longitude IS NOT NULL
                       AND NOT COALESCE(
                           g.is_outside_broad_brazil_box,
                           FALSE
                       )
                      THEN g.representative_latitude
                      ELSE NULL
                  END
              )

           OR d.map_longitude
              IS DISTINCT FROM (
                  CASE
                      WHEN g.geolocation_zip_code_prefix
                               IS NOT NULL
                       AND g.representative_latitude IS NOT NULL
                       AND g.representative_longitude IS NOT NULL
                       AND NOT COALESCE(
                           g.is_outside_broad_brazil_box,
                           FALSE
                       )
                      THEN g.representative_longitude
                      ELSE NULL
                  END
              )
    ) AS derived_flag_or_map_differences

FROM staging.stg_sellers AS s

LEFT JOIN staging.ref_zip_geolocation AS g
    ON s.seller_zip_code_prefix =
       g.geolocation_zip_code_prefix

LEFT JOIN analytics.dim_seller AS d
    ON s.seller_id = d.seller_id;


-- =====================================================
-- CHECK C3: Safe Seller-to-Order-Items join
-- =====================================================

SELECT

    (
        SELECT COUNT(*)
        FROM staging.stg_order_items
    ) AS source_item_rows,

    COUNT(*) AS rows_after_join,

    COUNT(*) FILTER (
        WHERE s.seller_id IS NULL
    ) AS unmatched_seller_rows

FROM staging.stg_order_items AS oi

LEFT JOIN analytics.dim_seller AS s
    ON oi.seller_id = s.seller_id;
