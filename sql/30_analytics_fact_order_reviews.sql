
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 6.3 - TASK 4
-- MODEL: analytics.fact_order_reviews
-- =====================================================

-- CHECK A: Review source readiness

SELECT
    COUNT(*) AS source_review_records,

    COUNT(DISTINCT (review_id, order_id))
        AS unique_review_keys,

    COUNT(DISTINCT review_id)
        AS distinct_review_ids,

    COUNT(DISTINCT order_id)
        AS distinct_reviewed_orders,

    COUNT(*) FILTER (
        WHERE review_id IS NULL
           OR BTRIM(review_id) = ''
           OR order_id IS NULL
           OR BTRIM(order_id) = ''
    ) AS missing_required_keys,

    COUNT(*) FILTER (
        WHERE review_creation_timestamp IS NULL
    ) AS missing_creation_timestamps,

    COUNT(*) FILTER (
        WHERE review_answer_timestamp IS NULL
    ) AS missing_answer_timestamps,

    COUNT(*) FILTER (
        WHERE is_missing_review_title
    ) AS missing_review_titles,

    COUNT(*) FILTER (
        WHERE is_missing_review_message
    ) AS missing_review_messages,

    COUNT(*) FILTER (
        WHERE has_no_written_feedback
    ) AS reviews_without_written_feedback,

    COUNT(*) FILTER (
        WHERE has_invalid_review_score
    ) AS invalid_review_scores

FROM staging.stg_order_reviews;


-- =====================================================
-- CHECK B: Create analytics.fact_order_reviews
-- =====================================================

BEGIN;

CREATE TABLE analytics.fact_order_reviews AS

SELECT
    -- Composite source review key
    r.review_id,
    r.order_id,

    -- Order-associated customer identifiers
    o.customer_id,
    c.customer_unique_id,

    CASE
        WHEN c.customer_id IS NOT NULL
        THEN MD5(
            JSONB_BUILD_ARRAY(
                c.customer_zip_code_prefix,
                c.customer_city,
                c.customer_state
            )::TEXT
        )
        ELSE NULL
    END AS customer_location_key,

    -- Shared dimension keys
    o.order_status,

    o.order_purchase_timestamp::DATE
        AS purchase_date,

    -- Review-specific date dimension key
    r.review_creation_timestamp::DATE
        AS review_creation_date,

    -- Review attributes
    r.review_score,
    r.review_comment_title,
    r.review_comment_message,

    -- Preserve original staged timestamps
    r.review_creation_timestamp,
    r.review_answer_timestamp,

    -- Data-quality indicators
    r.is_missing_review_title,
    r.is_missing_review_message,
    r.has_no_written_feedback,
    r.has_invalid_review_score

FROM staging.stg_order_reviews AS r

LEFT JOIN staging.stg_orders AS o
    ON r.order_id = o.order_id

LEFT JOIN staging.stg_customers AS c
    ON o.customer_id = c.customer_id

WITH DATA;


-- =====================================================
-- Enforce review grain and required attributes
-- =====================================================

ALTER TABLE analytics.fact_order_reviews

    ADD CONSTRAINT fact_order_reviews_pkey
        PRIMARY KEY (review_id, order_id),

    ALTER COLUMN customer_id SET NOT NULL,
    ALTER COLUMN customer_unique_id SET NOT NULL,
    ALTER COLUMN customer_location_key SET NOT NULL,

    ALTER COLUMN order_status SET NOT NULL,
    ALTER COLUMN purchase_date SET NOT NULL,
    ALTER COLUMN review_creation_date SET NOT NULL,

    ALTER COLUMN review_score SET NOT NULL,

    ALTER COLUMN is_missing_review_title SET NOT NULL,
    ALTER COLUMN is_missing_review_message SET NOT NULL,
    ALTER COLUMN has_no_written_feedback SET NOT NULL,
    ALTER COLUMN has_invalid_review_score SET NOT NULL,

    ADD CONSTRAINT chk_fact_reviews_quality_flags
        CHECK (
            is_missing_review_title =
                (review_comment_title IS NULL)

            AND is_missing_review_message =
                (review_comment_message IS NULL)

            AND has_no_written_feedback =
                (
                    review_comment_title IS NULL
                    AND review_comment_message IS NULL
                )

            AND has_invalid_review_score =
                (review_score NOT BETWEEN 1 AND 5)
        );


-- =====================================================
-- Dimension foreign keys
-- =====================================================

ALTER TABLE analytics.fact_order_reviews

    ADD CONSTRAINT fk_fact_reviews_customer
        FOREIGN KEY (customer_unique_id)
        REFERENCES analytics.dim_customer (
            customer_unique_id
        ),

    ADD CONSTRAINT fk_fact_reviews_geography
        FOREIGN KEY (customer_location_key)
        REFERENCES analytics.dim_customer_geography (
            customer_location_key
        ),

    ADD CONSTRAINT fk_fact_reviews_status
        FOREIGN KEY (order_status)
        REFERENCES analytics.dim_order_status (
            order_status
        ),

    ADD CONSTRAINT fk_fact_reviews_purchase_date
        FOREIGN KEY (purchase_date)
        REFERENCES analytics.dim_purchase_date (
            date
        ),

    ADD CONSTRAINT fk_fact_reviews_review_date
        FOREIGN KEY (review_creation_date)
        REFERENCES analytics.dim_review_date (
            date
        ),

    ADD CONSTRAINT fk_fact_reviews_parent_order
        FOREIGN KEY (order_id)
        REFERENCES analytics.fact_orders (
            order_id
        );

COMMIT;


-- =====================================================
-- CHECK C1: Review fact grain and quality
-- =====================================================

SELECT
    COUNT(*) AS fact_review_records,

    COUNT(DISTINCT (review_id, order_id))
        AS unique_review_keys,

    COUNT(DISTINCT review_id)
        AS distinct_review_ids,

    COUNT(DISTINCT order_id)
        AS distinct_reviewed_orders,

    ROUND(
        AVG(review_score)::NUMERIC,
        2
    ) AS average_review_score,

    COUNT(*) FILTER (
        WHERE review_score IN (4, 5)
    ) AS high_rating_reviews,

    COUNT(*) FILTER (
        WHERE is_missing_review_title
    ) AS missing_titles,

    COUNT(*) FILTER (
        WHERE is_missing_review_message
    ) AS missing_messages,

    COUNT(*) FILTER (
        WHERE has_no_written_feedback
    ) AS reviews_without_written_feedback,

    COUNT(*) FILTER (
        WHERE NOT has_no_written_feedback
    ) AS reviews_with_written_feedback,

    COUNT(*) FILTER (
        WHERE has_invalid_review_score
    ) AS invalid_review_scores,

    COUNT(*) FILTER (
        WHERE review_creation_date IS DISTINCT FROM
              review_creation_timestamp::DATE
    ) AS inconsistent_review_dates

FROM analytics.fact_order_reviews;


-- =====================================================
-- CHECK C2: Source-to-fact fidelity
-- =====================================================

WITH expected AS (

    SELECT
        r.review_id,
        r.order_id,

        o.customer_id,
        c.customer_unique_id,

        MD5(
            JSONB_BUILD_ARRAY(
                c.customer_zip_code_prefix,
                c.customer_city,
                c.customer_state
            )::TEXT
        ) AS customer_location_key,

        o.order_status,

        o.order_purchase_timestamp::DATE
            AS purchase_date,

        r.review_creation_timestamp::DATE
            AS review_creation_date,

        r.review_score,
        r.review_comment_title,
        r.review_comment_message,

        r.review_creation_timestamp,
        r.review_answer_timestamp,

        r.is_missing_review_title,
        r.is_missing_review_message,
        r.has_no_written_feedback,
        r.has_invalid_review_score

    FROM staging.stg_order_reviews AS r

    LEFT JOIN staging.stg_orders AS o
        ON r.order_id = o.order_id

    LEFT JOIN staging.stg_customers AS c
        ON o.customer_id = c.customer_id

)

SELECT
    COUNT(*) AS compared_review_keys,

    COUNT(*) FILTER (
        WHERE f.review_id IS NULL
    ) AS missing_fact_reviews,

    COUNT(*) FILTER (
        WHERE e.review_id IS NULL
    ) AS unexpected_fact_reviews,

    COUNT(*) FILTER (
        WHERE e.review_id IS NOT NULL
          AND f.review_id IS NOT NULL

          AND ROW(
              f.customer_id,
              f.customer_unique_id,
              f.customer_location_key,
              f.order_status,
              f.purchase_date,
              f.review_creation_date,
              f.review_score,
              f.review_comment_title,
              f.review_comment_message,
              f.review_creation_timestamp,
              f.review_answer_timestamp,
              f.is_missing_review_title,
              f.is_missing_review_message,
              f.has_no_written_feedback,
              f.has_invalid_review_score
          ) IS DISTINCT FROM ROW(
              e.customer_id,
              e.customer_unique_id,
              e.customer_location_key,
              e.order_status,
              e.purchase_date,
              e.review_creation_date,
              e.review_score,
              e.review_comment_title,
              e.review_comment_message,
              e.review_creation_timestamp,
              e.review_answer_timestamp,
              e.is_missing_review_title,
              e.is_missing_review_message,
              e.has_no_written_feedback,
              e.has_invalid_review_score
          )
    ) AS inconsistent_review_attributes

FROM expected AS e

FULL OUTER JOIN analytics.fact_order_reviews AS f
    ON e.review_id = f.review_id
   AND e.order_id = f.order_id;


-- =====================================================
-- CHECK C3: Cross-grain review validation
-- =====================================================

WITH review_rollups AS (

    SELECT
        order_id,
        COUNT(*)::INTEGER AS review_count

    FROM analytics.fact_order_reviews

    GROUP BY order_id

)

SELECT
    COUNT(*) AS checked_orders,

    COUNT(*) FILTER (
        WHERE r.order_id IS NOT NULL
    ) AS orders_with_reviews,

    COUNT(*) FILTER (
        WHERE r.order_id IS NULL
    ) AS orders_without_reviews,

    SUM(COALESCE(r.review_count, 0))
        AS represented_review_records,

    COUNT(*) FILTER (
        WHERE ROW(
            o.review_record_count,
            o.has_review_record
        ) IS DISTINCT FROM ROW(
            COALESCE(r.review_count, 0),
            (r.order_id IS NOT NULL)
        )
    ) AS inconsistent_review_rollups

FROM analytics.fact_orders AS o

LEFT JOIN review_rollups AS r
    ON o.order_id = r.order_id;


-- =====================================================
-- CHECK C4: Review fact dimension relationships
-- =====================================================

SELECT
    (
        SELECT COUNT(*)
        FROM analytics.fact_order_reviews
    ) AS source_fact_rows,

    COUNT(*) AS rows_after_join,

    COUNT(DISTINCT (
        f.review_id,
        f.order_id
    )) AS distinct_review_keys,

    COUNT(*) FILTER (
        WHERE c.customer_unique_id IS NULL
    ) AS missing_customers,

    COUNT(*) FILTER (
        WHERE g.customer_location_key IS NULL
    ) AS missing_customer_geography,

    COUNT(*) FILTER (
        WHERE s.order_status IS NULL
    ) AS missing_order_statuses,

    COUNT(*) FILTER (
        WHERE p.date IS NULL
    ) AS missing_purchase_dates,

    COUNT(*) FILTER (
        WHERE r.date IS NULL
    ) AS missing_review_dates

FROM analytics.fact_order_reviews AS f

LEFT JOIN analytics.dim_customer AS c
    ON f.customer_unique_id =
       c.customer_unique_id

LEFT JOIN analytics.dim_customer_geography AS g
    ON f.customer_location_key =
       g.customer_location_key

LEFT JOIN analytics.dim_order_status AS s
    ON f.order_status =
       s.order_status

LEFT JOIN analytics.dim_purchase_date AS p
    ON f.purchase_date =
       p.date

LEFT JOIN analytics.dim_review_date AS r
    ON f.review_creation_date =
       r.date;


-- CHECK C5a: Review score distribution

SELECT
    review_score,

    COUNT(*) AS review_records,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS share_pct

FROM analytics.fact_order_reviews

GROUP BY review_score

ORDER BY review_score;


-- CHECK C5b: Multiple reviews per order

WITH review_counts AS (

    SELECT
        order_id,
        COUNT(*) AS reviews_per_order

    FROM analytics.fact_order_reviews

    GROUP BY order_id

)

SELECT
    COUNT(*) AS distinct_reviewed_orders,

    COUNT(*) FILTER (
        WHERE reviews_per_order > 1
    ) AS orders_with_multiple_reviews,

    SUM(reviews_per_order - 1)
        AS additional_review_records,

    MAX(reviews_per_order)
        AS maximum_reviews_per_order

FROM review_counts;
