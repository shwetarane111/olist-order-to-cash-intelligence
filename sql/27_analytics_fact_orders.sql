
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 6.3 - TASK 1
-- MODEL: analytics.fact_orders
-- =====================================================

-- CHECK A: Source readiness

SELECT
    (SELECT COUNT(*)
     FROM staging.stg_orders)
        AS total_orders,

    (SELECT COUNT(DISTINCT order_id)
     FROM staging.stg_orders)
        AS unique_order_ids,

    (SELECT COUNT(DISTINCT order_id)
     FROM staging.stg_order_items)
        AS orders_with_items,

    (SELECT COUNT(DISTINCT order_id)
     FROM staging.stg_order_payments)
        AS orders_with_payments,

    (SELECT COUNT(DISTINCT order_id)
     FROM staging.stg_order_reviews)
        AS orders_with_reviews,

    (SELECT COUNT(*)
     FROM staging.stg_order_reviews)
        AS review_records,

    (SELECT COUNT(*)
     FROM staging.stg_orders
     WHERE order_purchase_timestamp IS NULL)
        AS missing_purchase_timestamps;


-- =====================================================
-- CHECK B: Create analytics.fact_orders
-- =====================================================

BEGIN;

CREATE TABLE analytics.fact_orders AS

WITH item_totals AS (

    -- One aggregated row per order
    SELECT
        order_id,

        COUNT(*)::INTEGER AS item_record_count,

        SUM(item_price) AS item_price_total,

        SUM(freight_amount) AS freight_total,

        SUM(item_total_amount) AS item_plus_freight_total

    FROM staging.stg_order_items

    GROUP BY order_id

),

payment_totals AS (

    -- Aggregate payments independently of items
    SELECT
        order_id,

        COUNT(*)::INTEGER AS payment_entry_count,

        SUM(payment_amount) AS recorded_payment_total

    FROM staging.stg_order_payments

    GROUP BY order_id

),

review_totals AS (

    -- Multiple reviews per order are preserved
    -- in the count, without multiplying orders.
    SELECT
        order_id,

        COUNT(*)::INTEGER AS review_record_count

    FROM staging.stg_order_reviews

    GROUP BY order_id

),

enriched_orders AS (

    SELECT
        o.order_id,
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

        o.order_status,

        -- Preserve original staged timestamps
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,

        -- Date dimension keys
        o.order_purchase_timestamp::DATE
            AS purchase_date,

        o.order_delivered_customer_date::DATE
            AS delivery_date,

        o.order_estimated_delivery_date::DATE
            AS estimated_delivery_date,

        -- Record counts
        COALESCE(i.item_record_count, 0)
            AS item_record_count,

        COALESCE(p.payment_entry_count, 0)
            AS payment_entry_count,

        COALESCE(r.review_record_count, 0)
            AS review_record_count,

        -- Source-record existence flags
        (i.order_id IS NOT NULL)
            AS has_item_records,

        (p.order_id IS NOT NULL)
            AS has_payment_records,

        (r.order_id IS NOT NULL)
            AS has_review_record,

        -- Monetary totals: do not COALESCE to zero
        i.item_price_total,
        i.freight_total,
        i.item_plus_freight_total,

        p.recorded_payment_total,

        -- Only delivered orders with both delivery
        -- timestamps can be evaluated for timeliness
        (
            o.order_status = 'delivered'

            AND o.order_delivered_customer_date
                IS NOT NULL

            AND o.order_estimated_delivery_date
                IS NOT NULL
        ) AS is_delivery_evaluable

    FROM staging.stg_orders AS o

    LEFT JOIN staging.stg_customers AS c
        ON o.customer_id = c.customer_id

    LEFT JOIN item_totals AS i
        ON o.order_id = i.order_id

    LEFT JOIN payment_totals AS p
        ON o.order_id = p.order_id

    LEFT JOIN review_totals AS r
        ON o.order_id = r.order_id

)

SELECT
    -- Order and dimensional identifiers
    e.order_id,
    e.customer_id,
    e.customer_unique_id,
    e.customer_location_key,
    e.order_status,

    -- Source timestamps
    e.order_purchase_timestamp,
    e.order_approved_at,
    e.order_delivered_carrier_date,
    e.order_delivered_customer_date,
    e.order_estimated_delivery_date,

    -- Calendar keys
    e.purchase_date,
    e.delivery_date,
    e.estimated_delivery_date,

    -- Source-record counts
    e.item_record_count,
    e.payment_entry_count,
    e.review_record_count,

    -- Presence indicators
    e.has_item_records,
    e.has_payment_records,
    e.has_review_record,

    -- Financial measures
    e.item_price_total,
    e.freight_total,
    e.item_plus_freight_total,
    e.recorded_payment_total,

    -- Reconciliation classification
    CASE
        WHEN NOT e.has_item_records
         AND NOT e.has_payment_records
            THEN 'MISSING_BOTH'

        WHEN NOT e.has_item_records
            THEN 'MISSING_ITEMS'

        WHEN NOT e.has_payment_records
            THEN 'MISSING_PAYMENTS'

        WHEN e.recorded_payment_total =
             e.item_plus_freight_total
            THEN 'MATCH'

        ELSE 'MISMATCH'
    END AS reconciliation_status,

    -- Difference is defined only when both
    -- financial source populations are present
    CASE
        WHEN e.has_item_records
         AND e.has_payment_records

        THEN
            e.recorded_payment_total
            - e.item_plus_freight_total

        ELSE NULL
    END AS payment_difference,

    CASE
        WHEN e.has_item_records
         AND e.has_payment_records

        THEN ABS(
            e.recorded_payment_total
            - e.item_plus_freight_total
        )

        ELSE NULL
    END AS absolute_payment_difference,

    -- Delivery analysis
    e.is_delivery_evaluable,

    CASE
        WHEN e.is_delivery_evaluable
        THEN e.delivery_date <= e.estimated_delivery_date
        ELSE NULL
    END AS is_delivered_on_time,

    CASE
        WHEN e.is_delivery_evaluable
        THEN e.delivery_date > e.estimated_delivery_date
        ELSE NULL
    END AS is_delivered_late,

    -- Signed calendar-day difference:
    -- negative = early, positive = late
    CASE
        WHEN e.is_delivery_evaluable
        THEN e.delivery_date - e.estimated_delivery_date
        ELSE NULL
    END AS delivery_variance_days,

    -- Valid elapsed purchase-to-delivery days
    CASE
        WHEN e.order_status = 'delivered'

         AND e.order_delivered_customer_date
             IS NOT NULL

         AND e.order_purchase_timestamp
             IS NOT NULL

         AND e.order_delivered_customer_date >=
             e.order_purchase_timestamp

        THEN
            EXTRACT(
                EPOCH FROM (
                    e.order_delivered_customer_date
                    - e.order_purchase_timestamp
                )
            ) / 86400::NUMERIC

        ELSE NULL
    END AS purchase_to_delivery_days,

    -- Preserve negative-duration anomalies as flags
    (
        e.order_status = 'delivered'

        AND e.order_delivered_customer_date IS NOT NULL

        AND e.order_purchase_timestamp IS NOT NULL

        AND e.order_delivered_customer_date <
            e.order_purchase_timestamp

    ) AS has_negative_purchase_to_delivery_duration

FROM enriched_orders AS e

WITH DATA;


-- =====================================================
-- Enforce fact-table grain and required keys
-- =====================================================

ALTER TABLE analytics.fact_orders

    ADD CONSTRAINT fact_orders_pkey
        PRIMARY KEY (order_id),

    ALTER COLUMN customer_id SET NOT NULL,

    ALTER COLUMN customer_unique_id SET NOT NULL,

    ALTER COLUMN customer_location_key SET NOT NULL,

    ALTER COLUMN order_status SET NOT NULL,

    ALTER COLUMN purchase_date SET NOT NULL,

    ADD CONSTRAINT fk_fact_orders_customer
        FOREIGN KEY (customer_unique_id)
        REFERENCES analytics.dim_customer (
            customer_unique_id
        ),

    ADD CONSTRAINT fk_fact_orders_geography
        FOREIGN KEY (customer_location_key)
        REFERENCES analytics.dim_customer_geography (
            customer_location_key
        ),

    ADD CONSTRAINT fk_fact_orders_status
        FOREIGN KEY (order_status)
        REFERENCES analytics.dim_order_status (
            order_status
        ),

    ADD CONSTRAINT fk_fact_orders_purchase_date
        FOREIGN KEY (purchase_date)
        REFERENCES analytics.dim_purchase_date (
            date
        ),

    ADD CONSTRAINT fk_fact_orders_delivery_date
        FOREIGN KEY (delivery_date)
        REFERENCES analytics.dim_delivery_date (
            date
        ),

    ADD CONSTRAINT chk_fact_orders_reconciliation
        CHECK (
            reconciliation_status IN (
                'MATCH',
                'MISMATCH',
                'MISSING_ITEMS',
                'MISSING_PAYMENTS',
                'MISSING_BOTH'
            )
        ),

    ADD CONSTRAINT chk_fact_orders_record_counts
        CHECK (
            item_record_count >= 0
            AND payment_entry_count >= 0
            AND review_record_count >= 0

            AND has_item_records =
                (item_record_count > 0)

            AND has_payment_records =
                (payment_entry_count > 0)

            AND has_review_record =
                (review_record_count > 0)
        ),

    ADD CONSTRAINT chk_fact_orders_absolute_difference
        CHECK (
            absolute_payment_difference IS NULL
            OR absolute_payment_difference >= 0
        );

COMMIT;


-- =====================================================
-- CHECK C1: Fact grain and source coverage
-- =====================================================

SELECT
    COUNT(*) AS fact_rows,

    COUNT(DISTINCT order_id)
        AS unique_order_ids,

    COUNT(*) FILTER (
        WHERE has_item_records
    ) AS orders_with_items,

    COUNT(*) FILTER (
        WHERE has_payment_records
    ) AS orders_with_payments,

    COUNT(*) FILTER (
        WHERE has_review_record
    ) AS orders_with_reviews,

    SUM(item_record_count)
        AS represented_item_records,

    SUM(payment_entry_count)
        AS represented_payment_entries,

    SUM(review_record_count)
        AS represented_review_records,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
    ) AS delivered_status_orders,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND delivery_date IS NULL
    ) AS delivered_orders_missing_actual_date,

    COUNT(*) FILTER (
        WHERE order_status = 'canceled'
          AND delivery_date IS NOT NULL
    ) AS canceled_orders_with_actual_date

FROM analytics.fact_orders;


-- =====================================================
-- CHECK C2: Order-level financial reconciliation
-- =====================================================

SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE reconciliation_status
              IN ('MATCH', 'MISMATCH')
    ) AS comparable_orders,

    COUNT(*) FILTER (
        WHERE reconciliation_status = 'MATCH'
    ) AS matched_orders,

    COUNT(*) FILTER (
        WHERE reconciliation_status = 'MISMATCH'
    ) AS mismatched_orders,

    COUNT(*) FILTER (
        WHERE reconciliation_status = 'MISSING_ITEMS'
    ) AS missing_items,

    COUNT(*) FILTER (
        WHERE reconciliation_status = 'MISSING_PAYMENTS'
    ) AS missing_payments,

    COUNT(*) FILTER (
        WHERE reconciliation_status = 'MISSING_BOTH'
    ) AS missing_both,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE reconciliation_status = 'MATCH'
        )
        / NULLIF(
            COUNT(*) FILTER (
                WHERE reconciliation_status
                      IN ('MATCH', 'MISMATCH')
            ),
            0
        ),
        2
    ) AS match_rate_pct,

    SUM(item_plus_freight_total) FILTER (
        WHERE reconciliation_status
              IN ('MATCH', 'MISMATCH')
    ) AS comparable_item_plus_freight,

    SUM(recorded_payment_total) FILTER (
        WHERE reconciliation_status
              IN ('MATCH', 'MISMATCH')
    ) AS comparable_payment_total,

    SUM(payment_difference)
        AS net_payment_difference,

    SUM(absolute_payment_difference)
        AS absolute_financial_discrepancy,

    SUM(payment_difference) FILTER (
        WHERE payment_difference > 0
    ) AS positive_differences,

    SUM(payment_difference) FILTER (
        WHERE payment_difference < 0
    ) AS negative_differences

FROM analytics.fact_orders;


-- =====================================================
-- CHECK C3: Order and customer source fidelity
-- =====================================================

SELECT
    COUNT(*) AS checked_orders,

    COUNT(*) FILTER (
        WHERE ROW(
            f.customer_id,
            f.order_status,
            f.order_purchase_timestamp,
            f.order_approved_at,
            f.order_delivered_carrier_date,
            f.order_delivered_customer_date,
            f.order_estimated_delivery_date,
            f.purchase_date,
            f.delivery_date,
            f.estimated_delivery_date
        ) IS DISTINCT FROM ROW(
            o.customer_id,
            o.order_status,
            o.order_purchase_timestamp,
            o.order_approved_at,
            o.order_delivered_carrier_date,
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date,
            o.order_purchase_timestamp::DATE,
            o.order_delivered_customer_date::DATE,
            o.order_estimated_delivery_date::DATE
        )
    ) AS inconsistent_order_attributes,

    COUNT(*) FILTER (
        WHERE ROW(
            f.customer_unique_id,
            f.customer_location_key
        ) IS DISTINCT FROM ROW(
            c.customer_unique_id,

            MD5(
                JSONB_BUILD_ARRAY(
                    c.customer_zip_code_prefix,
                    c.customer_city,
                    c.customer_state
                )::TEXT
            )
        )
    ) AS inconsistent_customer_attributes

FROM analytics.fact_orders AS f

INNER JOIN staging.stg_orders AS o
    ON f.order_id = o.order_id

LEFT JOIN staging.stg_customers AS c
    ON o.customer_id = c.customer_id;


-- =====================================================
-- CHECK C4: Independent detail-rollup validation
-- =====================================================

WITH items AS (

    SELECT
        order_id,
        COUNT(*)::INTEGER AS item_count,
        SUM(item_price) AS price_total,
        SUM(freight_amount) AS freight_total,
        SUM(item_total_amount) AS item_total

    FROM staging.stg_order_items
    GROUP BY order_id

),

payments AS (

    SELECT
        order_id,
        COUNT(*)::INTEGER AS payment_count,
        SUM(payment_amount) AS payment_total

    FROM staging.stg_order_payments
    GROUP BY order_id

),

reviews AS (

    SELECT
        order_id,
        COUNT(*)::INTEGER AS review_count

    FROM staging.stg_order_reviews
    GROUP BY order_id

)

SELECT
    COUNT(*) AS checked_orders,

    COUNT(*) FILTER (
        WHERE ROW(
            f.item_record_count,
            f.item_price_total,
            f.freight_total,
            f.item_plus_freight_total,
            f.has_item_records
        ) IS DISTINCT FROM ROW(
            COALESCE(i.item_count, 0),
            i.price_total,
            i.freight_total,
            i.item_total,
            (i.order_id IS NOT NULL)
        )
    ) AS inconsistent_item_rollups,

    COUNT(*) FILTER (
        WHERE ROW(
            f.payment_entry_count,
            f.recorded_payment_total,
            f.has_payment_records
        ) IS DISTINCT FROM ROW(
            COALESCE(p.payment_count, 0),
            p.payment_total,
            (p.order_id IS NOT NULL)
        )
    ) AS inconsistent_payment_rollups,

    COUNT(*) FILTER (
        WHERE ROW(
            f.review_record_count,
            f.has_review_record
        ) IS DISTINCT FROM ROW(
            COALESCE(r.review_count, 0),
            (r.order_id IS NOT NULL)
        )
    ) AS inconsistent_review_rollups,

    COUNT(*) FILTER (
        WHERE f.reconciliation_status
              IS DISTINCT FROM
              CASE
                  WHEN i.order_id IS NULL
                   AND p.order_id IS NULL
                      THEN 'MISSING_BOTH'

                  WHEN i.order_id IS NULL
                      THEN 'MISSING_ITEMS'

                  WHEN p.order_id IS NULL
                      THEN 'MISSING_PAYMENTS'

                  WHEN p.payment_total = i.item_total
                      THEN 'MATCH'

                  ELSE 'MISMATCH'
              END

           OR f.payment_difference
              IS DISTINCT FROM
              (p.payment_total - i.item_total)

           OR f.absolute_payment_difference
              IS DISTINCT FROM
              ABS(p.payment_total - i.item_total)
    ) AS inconsistent_reconciliation_fields

FROM analytics.fact_orders AS f

LEFT JOIN items AS i
    ON f.order_id = i.order_id

LEFT JOIN payments AS p
    ON f.order_id = p.order_id

LEFT JOIN reviews AS r
    ON f.order_id = r.order_id;


-- =====================================================
-- CHECK C5: Fulfillment logic validation
-- =====================================================

WITH expected AS (

    SELECT
        order_id,

        (
            order_status = 'delivered'
            AND order_delivered_customer_date IS NOT NULL
            AND order_estimated_delivery_date IS NOT NULL
        ) AS eligible,

        CASE
            WHEN order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
            THEN
                order_delivered_customer_date::DATE
                <= order_estimated_delivery_date::DATE
            ELSE NULL
        END AS on_time,

        CASE
            WHEN order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
            THEN
                order_delivered_customer_date::DATE
                > order_estimated_delivery_date::DATE
            ELSE NULL
        END AS late,

        CASE
            WHEN order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
            THEN
                order_delivered_customer_date::DATE
                - order_estimated_delivery_date::DATE
            ELSE NULL
        END AS variance_days,

        CASE
            WHEN order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL
             AND order_purchase_timestamp IS NOT NULL
             AND order_delivered_customer_date >=
                 order_purchase_timestamp
            THEN
                EXTRACT(
                    EPOCH FROM (
                        order_delivered_customer_date
                        - order_purchase_timestamp
                    )
                ) / 86400::NUMERIC
            ELSE NULL
        END AS elapsed_days,

        (
            order_status = 'delivered'
            AND order_delivered_customer_date IS NOT NULL
            AND order_purchase_timestamp IS NOT NULL
            AND order_delivered_customer_date <
                order_purchase_timestamp
        ) AS negative_duration

    FROM staging.stg_orders

)

SELECT
    COUNT(*) AS checked_orders,

    COUNT(*) FILTER (
        WHERE f.is_delivery_evaluable
    ) AS evaluable_delivered_orders,

    COUNT(*) FILTER (
        WHERE f.is_delivered_on_time
    ) AS on_time_delivered_orders,

    COUNT(*) FILTER (
        WHERE f.is_delivered_late
    ) AS late_delivered_orders,

    COUNT(*) FILTER (
        WHERE f.has_negative_purchase_to_delivery_duration
    ) AS negative_duration_orders,

    COUNT(*) FILTER (
        WHERE ROW(
            f.is_delivery_evaluable,
            f.is_delivered_on_time,
            f.is_delivered_late,
            f.delivery_variance_days,
            f.purchase_to_delivery_days,
            f.has_negative_purchase_to_delivery_duration
        ) IS DISTINCT FROM ROW(
            e.eligible,
            e.on_time,
            e.late,
            e.variance_days,
            e.elapsed_days,
            e.negative_duration
        )
    ) AS inconsistent_fulfillment_rows

FROM analytics.fact_orders AS f

JOIN expected AS e
    ON f.order_id = e.order_id;
