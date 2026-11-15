
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 5.1 - TASK 7
-- MODEL: staging.stg_order_reviews
-- =====================================================

-- CHECK A: Validate RAW review timestamp strings

WITH timestamp_fields AS (

    SELECT
        t.field_name,
        NULLIF(BTRIM(t.raw_value), '') AS cleaned_value

    FROM raw.order_reviews AS r

    CROSS JOIN LATERAL (
        VALUES
            (
                'review_creation_date',
                r.review_creation_date
            ),
            (
                'review_answer_timestamp',
                r.review_answer_timestamp
            )
    ) AS t(field_name, raw_value)

),

validated AS (

    SELECT
        field_name,
        cleaned_value,

        CASE
            WHEN cleaned_value IS NULL
                THEN FALSE

            WHEN cleaned_value !~
                '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
                THEN TRUE

            ELSE NOT pg_input_is_valid(
                cleaned_value,
                'timestamp without time zone'
            )
        END AS is_invalid

    FROM timestamp_fields
)

SELECT
    field_name,

    COUNT(*) AS total_review_rows,

    COUNT(*) FILTER (
        WHERE cleaned_value IS NULL
    ) AS missing_or_blank,

    COUNT(*) FILTER (
        WHERE is_invalid
    ) AS invalid_nonblank

FROM validated

GROUP BY field_name
ORDER BY field_name;


-- =====================================================
-- CHECK B: Create Order Reviews STAGING view
-- =====================================================

CREATE OR REPLACE VIEW staging.stg_order_reviews AS

WITH standardized AS (

    SELECT
        -- Preserve the logical composite key
        r.review_id,
        r.order_id,

        -- Preserve original numeric score
        r.review_score,

        -- Convert blank/whitespace-only comments to NULL
        NULLIF(
            BTRIM(r.review_comment_title),
            ''
        ) AS review_comment_title,

        NULLIF(
            BTRIM(r.review_comment_message),
            ''
        ) AS review_comment_message,

        -- Convert source timestamp strings
        NULLIF(
            BTRIM(r.review_creation_date),
            ''
        )::TIMESTAMP AS review_creation_timestamp,

        NULLIF(
            BTRIM(r.review_answer_timestamp),
            ''
        )::TIMESTAMP AS review_answer_timestamp

    FROM raw.order_reviews AS r

)

SELECT
    review_id,
    order_id,
    review_score,

    review_comment_title,
    review_comment_message,

    review_creation_timestamp,
    review_answer_timestamp,

    -- Individual missing-feedback indicators
    (
        review_comment_title IS NULL
    ) AS is_missing_review_title,

    (
        review_comment_message IS NULL
    ) AS is_missing_review_message,

    -- Both written fields are absent
    (
        review_comment_title IS NULL
        AND review_comment_message IS NULL
    ) AS has_no_written_feedback,

    -- NULL or outside the valid 1-5 range
    (
        review_score IS NULL
        OR review_score NOT BETWEEN 1 AND 5
    ) AS has_invalid_review_score

FROM standardized;


-- =====================================================
-- CHECK C: Validate staging.stg_order_reviews
-- =====================================================

SELECT
    COUNT(*) AS total_review_rows,

    COUNT(DISTINCT review_id)
        AS distinct_review_ids,

    COUNT(DISTINCT order_id)
        AS distinct_reviewed_orders,

    COUNT(DISTINCT (review_id, order_id))
        AS unique_composite_keys,

    COUNT(*) FILTER (
        WHERE review_id IS NULL
           OR BTRIM(review_id) = ''
           OR order_id IS NULL
           OR BTRIM(order_id) = ''
    ) AS missing_key_rows,

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
    ) AS invalid_review_scores,

    COUNT(*) FILTER (
        WHERE review_creation_timestamp IS NULL
    ) AS missing_creation_timestamps,

    COUNT(*) FILTER (
        WHERE review_answer_timestamp IS NULL
    ) AS missing_answer_timestamps

FROM staging.stg_order_reviews;


-- =====================================================
-- CHECK D: Verify review relationships and grain
-- =====================================================

WITH review_counts AS (

    SELECT
        order_id,
        COUNT(*) AS review_count

    FROM staging.stg_order_reviews

    GROUP BY order_id

)

SELECT
    COUNT(*) AS orders_with_reviews,

    COUNT(*) FILTER (
        WHERE review_count > 1
    ) AS orders_with_multiple_reviews,

    MAX(review_count)
        AS maximum_reviews_per_order,

    SUM(review_count - 1)
        AS additional_review_records

FROM review_counts;
