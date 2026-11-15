
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 6.2 - TASK 7
-- MODEL: analytics.dim_delivery_date
-- SOURCE: staging.stg_orders
-- =====================================================

-- CHECK A1: Actual delivery-date source readiness

SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
    ) AS orders_missing_delivery_timestamp,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NOT NULL
    ) AS orders_with_delivery_timestamp,

    MIN(order_delivered_customer_date::DATE)
        AS earliest_delivery_date,

    MAX(order_delivered_customer_date::DATE)
        AS latest_delivery_date,

    COUNT(DISTINCT order_delivered_customer_date::DATE)
        AS dates_with_deliveries,

    (
        MAX(order_delivered_customer_date::DATE)
        -
        MIN(order_delivered_customer_date::DATE)
        + 1
    ) AS expected_calendar_days,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
    ) AS delivered_status_orders,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_delivered_customer_date IS NULL
    ) AS delivered_orders_missing_actual_date,

    COUNT(*) FILTER (
        WHERE order_status <> 'delivered'
          AND order_delivered_customer_date IS NOT NULL
    ) AS non_delivered_orders_with_actual_date

FROM staging.stg_orders;


-- CHECK A2: Actual delivery timestamp coverage by status

SELECT
    order_status,

    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NOT NULL
    ) AS orders_with_actual_delivery,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
    ) AS orders_missing_actual_delivery

FROM staging.stg_orders

GROUP BY order_status

ORDER BY total_orders DESC, order_status;


-- =====================================================
-- CHECK B: Create analytics.dim_delivery_date
-- =====================================================

BEGIN;

CREATE TABLE analytics.dim_delivery_date (

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

    CONSTRAINT chk_delivery_date_month
        CHECK (month_number BETWEEN 1 AND 12),

    CONSTRAINT chk_delivery_date_quarter
        CHECK (calendar_quarter BETWEEN 1 AND 4),

    CONSTRAINT chk_delivery_date_weekday
        CHECK (iso_day_of_week BETWEEN 1 AND 7),

    CONSTRAINT chk_delivery_date_weekend
        CHECK (
            is_weekend =
            (iso_day_of_week IN (6, 7))
        )

);


-- Build a continuous calendar using observed
-- actual customer-delivery dates.

WITH delivery_bounds AS (

    SELECT
        MIN(order_delivered_customer_date::DATE)
            AS min_delivery_date,

        MAX(order_delivered_customer_date::DATE)
            AS max_delivery_date

    FROM staging.stg_orders

),

calendar_days AS (

    SELECT
        gs.calendar_timestamp::DATE
            AS calendar_date

    FROM delivery_bounds AS b

    CROSS JOIN LATERAL GENERATE_SERIES(
        b.min_delivery_date::TIMESTAMP,
        b.max_delivery_date::TIMESTAMP,
        INTERVAL '1 day'
    ) AS gs(calendar_timestamp)

)

INSERT INTO analytics.dim_delivery_date (

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
-- CHECK C1: Delivery Date calendar coverage
-- =====================================================

WITH source_bounds AS (

    SELECT
        MIN(order_delivered_customer_date::DATE)
            AS min_delivery_date,

        MAX(order_delivered_customer_date::DATE)
            AS max_delivery_date

    FROM staging.stg_orders

)

SELECT
    COUNT(*) AS dimension_rows,

    COUNT(DISTINCT d.date)
        AS unique_dates,

    MIN(d.date) AS dimension_start_date,

    MAX(d.date) AS dimension_end_date,

    b.min_delivery_date AS source_start_date,

    b.max_delivery_date AS source_end_date,

    (
        b.max_delivery_date
        -
        b.min_delivery_date
        + 1
    ) AS expected_calendar_days,

    (
        b.max_delivery_date
        -
        b.min_delivery_date
        + 1
        -
        COUNT(*)
    ) AS missing_calendar_days

FROM analytics.dim_delivery_date AS d

CROSS JOIN source_bounds AS b

GROUP BY
    b.min_delivery_date,
    b.max_delivery_date;


-- =====================================================
-- CHECK C2: Delivery Date attribute fidelity
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

FROM analytics.dim_delivery_date;


-- =====================================================
-- CHECK C3: Delivery Date to Orders safe join
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
        WHERE o.order_delivered_customer_date IS NULL
    ) AS orders_missing_actual_delivery_date,

    COUNT(*) FILTER (
        WHERE o.order_delivered_customer_date IS NOT NULL
          AND d.date IS NULL
    ) AS unmatched_nonnull_delivery_dates,

    COUNT(*) FILTER (
        WHERE d.date IS NOT NULL
    ) AS orders_matched_to_delivery_calendar

FROM staging.stg_orders AS o

LEFT JOIN analytics.dim_delivery_date AS d
    ON o.order_delivered_customer_date::DATE =
       d.date;
