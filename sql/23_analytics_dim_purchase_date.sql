-- CHECK A: Purchase-date source readiness

SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE order_purchase_timestamp IS NULL
    ) AS missing_purchase_timestamps,

    MIN(order_purchase_timestamp::DATE)
        AS earliest_purchase_date,

    MAX(order_purchase_timestamp::DATE)
        AS latest_purchase_date,

    COUNT(DISTINCT order_purchase_timestamp::DATE)
        AS dates_with_orders,

    (
        MAX(order_purchase_timestamp::DATE)
        -
        MIN(order_purchase_timestamp::DATE)
        + 1
    ) AS expected_calendar_days

FROM staging.stg_orders;


-- =====================================================
-- CHECK B: Create analytics.dim_purchase_date
-- =====================================================

BEGIN;

CREATE TABLE analytics.dim_purchase_date (

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

    CONSTRAINT chk_purchase_date_month
        CHECK (month_number BETWEEN 1 AND 12),

    CONSTRAINT chk_purchase_date_quarter
        CHECK (calendar_quarter BETWEEN 1 AND 4),

    CONSTRAINT chk_purchase_date_weekday
        CHECK (iso_day_of_week BETWEEN 1 AND 7),

    CONSTRAINT chk_purchase_date_weekend
        CHECK (
            is_weekend =
            (iso_day_of_week IN (6, 7))
        )

);


-- Generate every calendar date in the observed
-- order purchase-date range.

WITH bounds AS (

    SELECT
        MIN(order_purchase_timestamp::DATE)
            AS min_purchase_date,

        MAX(order_purchase_timestamp::DATE)
            AS max_purchase_date

    FROM staging.stg_orders

),

calendar_days AS (

    SELECT
        gs.calendar_timestamp::DATE
            AS calendar_date

    FROM bounds AS b

    CROSS JOIN LATERAL GENERATE_SERIES(
        b.min_purchase_date::TIMESTAMP,
        b.max_purchase_date::TIMESTAMP,
        INTERVAL '1 day'
    ) AS gs(calendar_timestamp)

)

INSERT INTO analytics.dim_purchase_date (

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
-- CHECK C1: Date dimension coverage
-- =====================================================

WITH source_bounds AS (

    SELECT
        MIN(order_purchase_timestamp::DATE)
            AS min_purchase_date,

        MAX(order_purchase_timestamp::DATE)
            AS max_purchase_date

    FROM staging.stg_orders

)

SELECT
    COUNT(*) AS dimension_rows,

    COUNT(DISTINCT d.date)
        AS unique_dates,

    MIN(d.date) AS dimension_start_date,

    MAX(d.date) AS dimension_end_date,

    b.min_purchase_date AS source_start_date,

    b.max_purchase_date AS source_end_date,

    (
        b.max_purchase_date
        -
        b.min_purchase_date
        + 1
    ) AS expected_calendar_days,

    (
        b.max_purchase_date
        -
        b.min_purchase_date
        + 1
        -
        COUNT(*)
    ) AS missing_calendar_days

FROM analytics.dim_purchase_date AS d

CROSS JOIN source_bounds AS b

GROUP BY
    b.min_purchase_date,
    b.max_purchase_date;


-- =====================================================
-- CHECK C2: Calendar attribute fidelity
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

FROM analytics.dim_purchase_date;


-- =====================================================
-- CHECK C3: Purchase Date to Orders join
-- =====================================================

SELECT
    (
        SELECT COUNT(*)
        FROM staging.stg_orders
    ) AS source_order_rows,

    COUNT(*) AS rows_after_join,

    COUNT(DISTINCT o.order_id)
        AS distinct_joined_orders,

    COUNT(*) FILTER (
        WHERE d.date IS NULL
    ) AS unmatched_purchase_dates

FROM staging.stg_orders AS o

LEFT JOIN analytics.dim_purchase_date AS d
    ON o.order_purchase_timestamp::DATE = d.date;
