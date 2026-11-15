
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 6.4 - TASK 3
-- FILE: 33_analytics_financial_kpi_quality_audit.sql
-- =====================================================

-- CHECK A: All-record financial consistency

WITH item_fact AS (
    SELECT
        COUNT(*) AS item_records,
        SUM(item_price) AS item_price_total,
        SUM(freight_amount) AS freight_total,
        SUM(item_total_amount) AS item_freight_total
    FROM analytics.fact_order_items
),

payment_fact AS (
    SELECT
        COUNT(*) AS payment_records,
        SUM(payment_amount) AS payment_total
    FROM analytics.fact_payments
),

item_source AS (
    SELECT
        SUM(item_price) AS item_price_total,
        SUM(freight_amount) AS freight_total,
        SUM(item_total_amount) AS item_freight_total
    FROM staging.stg_order_items
),

payment_source AS (
    SELECT
        SUM(payment_amount) AS payment_total
    FROM staging.stg_order_payments
),

order_totals AS (
    SELECT
        SUM(item_plus_freight_total)
            AS order_item_total,
        SUM(recorded_payment_total)
            AS order_payment_total
    FROM analytics.fact_orders
)

SELECT
    i.item_records,
    p.payment_records,

    i.item_price_total,
    i.freight_total,
    i.item_freight_total,
    p.payment_total,

    i.item_price_total - si.item_price_total
        AS item_price_source_difference,

    i.freight_total - si.freight_total
        AS freight_source_difference,

    i.item_freight_total - si.item_freight_total
        AS item_total_source_difference,

    p.payment_total - sp.payment_total
        AS payment_source_difference,

    i.item_freight_total - o.order_item_total
        AS item_order_fact_difference,

    p.payment_total - o.order_payment_total
        AS payment_order_fact_difference

FROM item_fact AS i
CROSS JOIN payment_fact AS p
CROSS JOIN item_source AS si
CROSS JOIN payment_source AS sp
CROSS JOIN order_totals AS o;


-- CHECK B: Final order-level financial reconciliation

SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE reconciliation_status IN ('MATCH', 'MISMATCH')
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
        ) /
        NULLIF(
            COUNT(*) FILTER (
                WHERE reconciliation_status IN ('MATCH', 'MISMATCH')
            ), 0
        ),
        2
    ) AS match_rate_pct,

    SUM(item_plus_freight_total) FILTER (
        WHERE reconciliation_status IN ('MATCH', 'MISMATCH')
    ) AS comparable_item_total,

    SUM(recorded_payment_total) FILTER (
        WHERE reconciliation_status IN ('MATCH', 'MISMATCH')
    ) AS comparable_payment_total,

    SUM(payment_difference) AS net_difference,

    SUM(absolute_payment_difference)
        AS absolute_discrepancy,

    COUNT(*) FILTER (
        WHERE (
            reconciliation_status IS DISTINCT FROM
            CASE
                WHEN NOT has_item_records
                 AND NOT has_payment_records
                    THEN 'MISSING_BOTH'
                WHEN NOT has_item_records
                    THEN 'MISSING_ITEMS'
                WHEN NOT has_payment_records
                    THEN 'MISSING_PAYMENTS'
                WHEN recorded_payment_total =
                     item_plus_freight_total
                    THEN 'MATCH'
                ELSE 'MISMATCH'
            END
        )
        OR payment_difference IS DISTINCT FROM
           (recorded_payment_total - item_plus_freight_total)
        OR absolute_payment_difference IS DISTINCT FROM
           ABS(recorded_payment_total - item_plus_freight_total)
    ) AS inconsistent_reconciliation_rows,

    COUNT(*) FILTER (
        WHERE (
            NOT has_item_records
            AND item_plus_freight_total IS NOT NULL
        )
        OR (
            NOT has_payment_records
            AND recorded_payment_total IS NOT NULL
        )
    ) AS incorrectly_filled_missing_amounts

FROM analytics.fact_orders;


-- CHECK C: Fulfillment KPI validation

SELECT
    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
    ) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE is_delivery_evaluable
    ) AS evaluable_delivered_orders,

    COUNT(*) FILTER (
        WHERE is_delivered_on_time
    ) AS on_time_orders,

    COUNT(*) FILTER (
        WHERE is_delivered_late
    ) AS late_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE is_delivered_on_time
        )
        / NULLIF(
            COUNT(*) FILTER (
                WHERE is_delivery_evaluable
            ), 0
        ),
        2
    ) AS on_time_rate_pct,

    ROUND(
        AVG(purchase_to_delivery_days),
        2
    ) AS average_purchase_to_delivery_days,

    ROUND(
        AVG(delivery_variance_days::NUMERIC),
        2
    ) AS average_signed_delivery_variance_days,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND delivery_date IS NULL
    ) AS delivered_orders_missing_actual_date,

    COUNT(*) FILTER (
        WHERE order_status = 'canceled'
          AND delivery_date IS NOT NULL
    ) AS canceled_orders_with_actual_date,

    COUNT(*) FILTER (
        WHERE has_negative_purchase_to_delivery_duration
    ) AS negative_duration_orders,

    COUNT(*) FILTER (
        WHERE (
            is_delivery_evaluable
            AND (
                is_delivered_on_time IS NULL
                OR is_delivered_late IS NULL
                OR is_delivered_on_time = is_delivered_late
            )
        )
        OR (
            NOT is_delivery_evaluable
            AND (
                is_delivered_on_time IS NOT NULL
                OR is_delivered_late IS NOT NULL
                OR delivery_variance_days IS NOT NULL
            )
        )
    ) AS inconsistent_delivery_classifications

FROM analytics.fact_orders;


-- CHECK D: Customer identity and repeat-order KPIs

WITH customer_orders AS (

    SELECT
        customer_unique_id,
        COUNT(DISTINCT order_id) AS order_count

    FROM analytics.fact_orders

    GROUP BY customer_unique_id

)

SELECT
    COUNT(*) AS customer_identities,

    SUM(co.order_count) AS represented_orders,

    COUNT(*) FILTER (
        WHERE co.order_count > 1
    ) AS repeat_order_identities,

    MAX(co.order_count) AS maximum_orders_per_identity,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE co.order_count > 1
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_order_share_pct,

    ROUND(
        SUM(co.order_count)::NUMERIC
        / NULLIF(COUNT(*), 0),
        4
    ) AS average_orders_per_identity,

    COUNT(*) FILTER (
        WHERE d.customer_unique_id IS NULL
           OR d.observed_order_count <> co.order_count
    ) AS inconsistent_customer_dimension_counts

FROM customer_orders AS co

LEFT JOIN analytics.dim_customer AS d
    ON co.customer_unique_id = d.customer_unique_id;


-- CHECK E: Payment activity and quality KPIs

WITH payment_counts AS (

    SELECT
        order_id,
        COUNT(*) AS payment_entries_per_order

    FROM analytics.fact_payments

    GROUP BY order_id

),

payment_count_summary AS (

    SELECT
        COUNT(*) FILTER (
            WHERE payment_entries_per_order > 1
        ) AS multiple_entry_orders,

        MAX(payment_entries_per_order)
            AS max_entries_per_order

    FROM payment_counts

)

SELECT
    COUNT(*) AS payment_records,

    COUNT(DISTINCT p.order_id)
        AS distinct_orders_with_payments,

    SUM(p.payment_amount)
        AS all_record_payment_total,

    COUNT(*) FILTER (
        WHERE p.is_zero_value_payment
    ) AS zero_value_payments,

    COUNT(*) FILTER (
        WHERE p.is_zero_installment
    ) AS zero_installment_payments,

    COUNT(*) FILTER (
        WHERE p.is_undefined_payment_method
    ) AS undefined_payment_methods,

    COUNT(*) FILTER (
        WHERE p.has_payment_quality_flag
    ) AS flagged_payment_records,

    COUNT(DISTINCT p.order_id) FILTER (
        WHERE p.has_payment_quality_flag
    ) AS orders_with_flagged_payments,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE p.has_payment_quality_flag
        ) / NULLIF(COUNT(*), 0),
        4
    ) AS flagged_entry_rate_pct,

    MAX(s.multiple_entry_orders)
        AS orders_with_multiple_payment_entries,

    MAX(s.max_entries_per_order)
        AS maximum_entries_per_order,

    COUNT(*) FILTER (
        WHERE p.has_payment_quality_flag IS DISTINCT FROM (
            p.is_zero_value_payment
            OR p.is_zero_installment
            OR p.is_undefined_payment_method
        )
    ) AS inconsistent_payment_flags

FROM analytics.fact_payments AS p

CROSS JOIN payment_count_summary AS s;


-- CHECK F: Review and satisfaction KPIs

WITH reviews_per_order AS (

    SELECT
        order_id,
        COUNT(*) AS reviews_per_order

    FROM analytics.fact_order_reviews

    GROUP BY order_id

),

review_order_summary AS (

    SELECT
        COUNT(*) FILTER (
            WHERE reviews_per_order > 1
        ) AS orders_with_multiple_reviews,

        SUM(reviews_per_order - 1)
            AS additional_review_records,

        MAX(reviews_per_order)
            AS maximum_reviews_per_order

    FROM reviews_per_order

),

order_review_coverage AS (

    SELECT
        COUNT(*) FILTER (
            WHERE has_review_record
        ) AS orders_with_reviews,

        COUNT(*) AS total_orders

    FROM analytics.fact_orders

)

SELECT
    COUNT(*) AS review_records,

    COUNT(DISTINCT r.review_id)
        AS distinct_review_ids,

    COUNT(DISTINCT r.order_id)
        AS distinct_reviewed_orders,

    ROUND(AVG(r.review_score)::NUMERIC, 2)
        AS average_review_score,

    COUNT(*) FILTER (
        WHERE r.review_score IN (4, 5)
    ) AS high_rating_reviews,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE r.review_score IN (4, 5)
        ) / NULLIF(
            COUNT(*) FILTER (
                WHERE r.review_score BETWEEN 1 AND 5
            ), 0
        ),
        2
    ) AS high_rating_share_pct,

    COUNT(*) FILTER (
        WHERE r.has_no_written_feedback
    ) AS reviews_without_written_feedback,

    COUNT(*) FILTER (
        WHERE NOT r.has_no_written_feedback
    ) AS reviews_with_written_feedback,

    COUNT(*) FILTER (
        WHERE r.has_invalid_review_score
    ) AS invalid_review_scores,

    MAX(s.orders_with_multiple_reviews)
        AS orders_with_multiple_reviews,

    MAX(s.additional_review_records)
        AS additional_review_records,

    MAX(s.maximum_reviews_per_order)
        AS maximum_reviews_per_order,

    MAX(c.orders_with_reviews)
        AS reviewed_orders_in_orders_fact,

    ROUND(
        100.0 * MAX(c.orders_with_reviews)
        / NULLIF(MAX(c.total_orders), 0),
        2
    ) AS purchase_cohort_review_coverage_pct,

    COUNT(*) FILTER (
        WHERE r.has_no_written_feedback IS DISTINCT FROM
              (
                  r.review_comment_title IS NULL
                  AND r.review_comment_message IS NULL
              )
    ) AS inconsistent_feedback_flags

FROM analytics.fact_order_reviews AS r

CROSS JOIN review_order_summary AS s
CROSS JOIN order_review_coverage AS c;


-- CHECK G: Product category and quality validation

SELECT
    COUNT(*) AS total_products,

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
    ) AS missing_display_labels,

    COUNT(*) FILTER (
        WHERE category_status IS NULL
           OR category_status NOT IN (
               'TRANSLATED',
               'UNTRANSLATED',
               'MISSING_SOURCE_CATEGORY'
           )
    ) AS invalid_category_classifications

FROM analytics.dim_product;
