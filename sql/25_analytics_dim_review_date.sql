
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 6.2 - TASK 8
-- MODEL: analytics.dim_review_date
-- SOURCE: staging.stg_order_reviews
-- =====================================================

-- CHECK A: Review creation-date source readiness

SELECT
    COUNT(*) AS total_review_records,

    COUNT(DISTINCT (review_id, order_id))
        AS distinct_review_keys,

    COUNT(DISTINCT order_id)
        AS distinct_reviewed_orders,

    COUNT(*) FILTER (
        WHERE review_creation_timestamp IS NULL
    ) AS missing_review_creation_timestamps,

    MIN(review_creation_timestamp::DATE)
        AS earliest_review_date,

    MAX(review_creation_timestamp::DATE)
        AS latest_review_date,

    COUNT(DISTINCT review_creation_timestamp::DATE)
        AS dates_with_reviews,

    (
        MAX(review_creation_timestamp::DATE)
        -
        MIN(review_creation_timestamp::DATE)
        + 1
    ) AS expected_calendar_days

FROM staging.stg_order_reviews;


-- =====================================================
-- CHECK B: Create analytics.dim_review_date
-- =====================================================

BEGIN;

CREATE TABLE analytics.dim_review_date (

    date DATE PRIMARY KEY,

    calendar_year SMALLINT NOT NULL,
    calendar_quarter SMALLINT NOT NULL,
    quarter_label TEXT NOT NULL,

    month_number SMALLINT NOT NULL,
    month_name TEXT NOT NULL,

    year_month TEXT NOT NULL,
    year_month_sort INTEGER NOT NULL,

    day_of_month SMALLINT NOT NULL,

    iso_day_of_week SMALLINT NOT NULL,
    day_name TEXT NOT NULL,

    iso_week_number SMALLINT NOT NULL,
    iso_week_year SMALLINT NOT NULL,

    is_weekend BOOLEAN NOT NULL,

    CONSTRAINT chk_review_date_month
        CHECK (month_number BETWEEN 1 AND 12),

    CONSTRAINT chk_review_date_quarter
        CHECK (calendar_quarter BETWEEN 1 AND 4),

    CONSTRAINT chk_review_date_weekday
        CHECK (iso_day_of_week BETWEEN 1 AND 7),

    CONSTRAINT chk_review_date_weekend
        CHECK (
            is_weekend =
            (iso_day_of_week IN (6, 7))
        )
);


-- Generate one record for every calendar day
-- in the observed review creation-date range.

WITH review_bounds AS (

    SELECT
        MIN(review_creation_timestamp::DATE)
            AS min_review_date,

        MAX(review_creation_timestamp::DATE)
            AS max_review_date

    FROM staging.stg_order_reviews

),

calendar_days AS (

    SELECT
        gs.calendar_timestamp::DATE
            AS calendar_date

    FROM review_bounds AS b

    CROSS JOIN LATERAL GENERATE_SERIES(
        b.min_review_date::TIMESTAMP,
        b.max_review_date::TIMESTAMP,
        INTERVAL '1 day'
    ) AS gs(calendar_timestamp)

)

INSERT INTO analytics.dim_review_date (

    date,
    calendar_year,
    calendar_quarter,
    quarter_label,

    month_number,
    month_name,
    year_month,
    year_month_sort,

    day_of_month,
    iso_day_of_week,
    day_name,

    iso_week_number,
    iso_week_year,
    is_weekend

)

SELECT
    calendar_date,

    EXTRACT(YEAR FROM calendar_date)::SMALLINT,

    EXTRACT(QUARTER FROM calendar_date)::SMALLINT,

    'Q' ||
        EXTRACT(QUARTER FROM calendar_date)::INTEGER,

    EXTRACT(MONTH FROM calendar_date)::SMALLINT,

    TO_CHAR(calendar_date, 'FMMonth'),

    TO_CHAR(calendar_date, 'YYYY-MM'),

    (
        EXTRACT(YEAR FROM calendar_date)::INTEGER * 100
        +
        EXTRACT(MONTH FROM calendar_date)::INTEGER
    ),

    EXTRACT(DAY FROM calendar_date)::SMALLINT,

    EXTRACT(ISODOW FROM calendar_date)::SMALLINT,

    TO_CHAR(calendar_date, 'FMDay'),

    EXTRACT(WEEK FROM calendar_date)::SMALLINT,

    EXTRACT(ISOYEAR FROM calendar_date)::SMALLINT,

    (
        EXTRACT(ISODOW FROM calendar_date)
        IN (6, 7)
    )

FROM calendar_days

ORDER BY calendar_date;

COMMIT;


-- =====================================================
-- CHECK C1: Review Date calendar coverage
-- =====================================================

WITH source_bounds AS (

    SELECT
        MIN(review_creation_timestamp::DATE)
            AS min_review_date,

        MAX(review_creation_timestamp::DATE)
            AS max_review_date

    FROM staging.stg_order_reviews

)

SELECT
    COUNT(*) AS dimension_rows,

    COUNT(DISTINCT d.date)
        AS unique_dates,

    MIN(d.date) AS dimension_start_date,

    MAX(d.date) AS dimension_end_date,

    b.min_review_date AS source_start_date,

    b.max_review_date AS source_end_date,

    (
        b.max_review_date
        -
        b.min_review_date
        + 1
    ) AS expected_calendar_days,

    (
        b.max_review_date
        -
        b.min_review_date
        + 1
        -
        COUNT(*)
    ) AS missing_calendar_days

FROM analytics.dim_review_date AS d

CROSS JOIN source_bounds AS b

GROUP BY
    b.min_review_date,
    b.max_review_date;


-- =====================================================
-- CHECK C2: Review Date attribute fidelity
-- =====================================================

SELECT
    COUNT(*) AS checked_dates,

    COUNT(*) FILTER (

        WHERE calendar_year IS DISTINCT FROM
              EXTRACT(YEAR FROM date)::SMALLINT

           OR calendar_quarter IS DISTINCT FROM
              EXTRACT(QUARTER FROM date)::SMALLINT

           OR quarter_label IS DISTINCT FROM
              (
                  'Q' ||
                  EXTRACT(QUARTER FROM date)::INTEGER
              )

           OR month_number IS DISTINCT FROM
              EXTRACT(MONTH FROM date)::SMALLINT

           OR month_name IS DISTINCT FROM
              TO_CHAR(date, 'FMMonth')

           OR year_month IS DISTINCT FROM
              TO_CHAR(date, 'YYYY-MM')

           OR year_month_sort IS DISTINCT FROM
              (
                  EXTRACT(YEAR FROM date)::INTEGER * 100
                  +
                  EXTRACT(MONTH FROM date)::INTEGER
              )

           OR day_of_month IS DISTINCT FROM
              EXTRACT(DAY FROM date)::SMALLINT

           OR iso_day_of_week IS DISTINCT FROM
              EXTRACT(ISODOW FROM date)::SMALLINT

           OR day_name IS DISTINCT FROM
              TO_CHAR(date, 'FMDay')

           OR iso_week_number IS DISTINCT FROM
              EXTRACT(WEEK FROM date)::SMALLINT

           OR iso_week_year IS DISTINCT FROM
              EXTRACT(ISOYEAR FROM date)::SMALLINT

           OR is_weekend IS DISTINCT FROM
              (
                  EXTRACT(ISODOW FROM date)
                  IN (6, 7)
              )

    ) AS inconsistent_attribute_rows

FROM analytics.dim_review_date;


-- =====================================================
-- CHECK C3: Review Date to Reviews safe join
-- =====================================================

SELECT
    (
        SELECT COUNT(*)
        FROM staging.stg_order_reviews
    ) AS source_review_rows,

    COUNT(*) AS rows_after_join,

    COUNT(DISTINCT (r.review_id, r.order_id))
        AS distinct_joined_review_keys,

    COUNT(DISTINCT r.order_id)
        AS distinct_reviewed_orders,

    COUNT(*) FILTER (
        WHERE r.review_creation_timestamp IS NULL
    ) AS reviews_missing_creation_date,

    COUNT(*) FILTER (
        WHERE r.review_creation_timestamp IS NOT NULL
          AND d.date IS NULL
    ) AS unmatched_nonnull_review_dates,

    COUNT(*) FILTER (
        WHERE d.date IS NOT NULL
    ) AS reviews_matched_to_calendar

FROM staging.stg_order_reviews AS r

LEFT JOIN analytics.dim_review_date AS d
    ON r.review_creation_timestamp::DATE =
       d.date;
