
-- =====================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 5.2 - TASK 3
-- FILE: 17_staging_quality_financial_audit.sql
-- =====================================================

-- CHECK A1: Payment-quality flag validation

SELECT
    COUNT(*) AS total_payment_rows,

    COUNT(*) FILTER (
        WHERE is_zero_value_payment
    ) AS zero_value_payments,

    COUNT(*) FILTER (
        WHERE is_zero_installment
    ) AS zero_installment_payments,

    COUNT(*) FILTER (
        WHERE is_undefined_payment_method
    ) AS undefined_payment_methods,

    COUNT(*) FILTER (
        WHERE has_payment_quality_flag
    ) AS flagged_payment_rows,

    COUNT(DISTINCT order_id) FILTER (
        WHERE has_payment_quality_flag
    ) AS orders_with_flagged_payments,

    COUNT(*) FILTER (
        WHERE is_zero_value_payment
          AND is_undefined_payment_method
    ) AS overlapping_zero_undefined_flags,

    COUNT(*) FILTER (
        WHERE has_payment_quality_flag
              IS DISTINCT FROM (
                  is_zero_value_payment
                  OR is_zero_installment
                  OR is_undefined_payment_method
              )
    ) AS inconsistent_overall_flags

FROM staging.stg_order_payments;


-- CHECK A2: Product data-quality validation

SELECT
    COUNT(*) AS total_products,

    COUNT(*) FILTER (
        WHERE category_status = 'TRANSLATED'
    ) AS translated_products,

    COUNT(*) FILTER (
        WHERE category_status = 'UNTRANSLATED'
    ) AS untranslated_products,

    COUNT(*) FILTER (
        WHERE category_status =
              'MISSING_SOURCE_CATEGORY'
    ) AS missing_source_categories,

    COUNT(DISTINCT product_category_name_pt)
        FILTER (
            WHERE is_untranslated_category
        ) AS untranslated_category_names,

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
    ) AS missing_display_labels,

    COUNT(*) FILTER (
        WHERE category_status IS NULL
           OR category_status NOT IN (
               'TRANSLATED',
               'UNTRANSLATED',
               'MISSING_SOURCE_CATEGORY'
           )
    ) AS unexpected_category_statuses

FROM staging.stg_products;


-- CHECK A3: Review data-quality validation

SELECT
    COUNT(*) AS total_review_rows,

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
    ) AS missing_answer_timestamps,

    COUNT(*) FILTER (
        WHERE is_missing_review_title
              IS DISTINCT FROM
              (review_comment_title IS NULL)

           OR is_missing_review_message
              IS DISTINCT FROM
              (review_comment_message IS NULL)

           OR has_no_written_feedback
              IS DISTINCT FROM (
                  review_comment_title IS NULL
                  AND review_comment_message IS NULL
              )
    ) AS inconsistent_feedback_flags

FROM staging.stg_order_reviews;


-- =====================================================
-- CHECK B: STAGING financial reconciliation
-- =====================================================

WITH item_totals AS (

    SELECT
        order_id,
        SUM(item_total_amount) AS item_total

    FROM staging.stg_order_items
    GROUP BY order_id

),

payment_totals AS (

    SELECT
        order_id,
        SUM(payment_amount) AS payment_total

    FROM staging.stg_order_payments
    GROUP BY order_id

),

reconciled AS (

    SELECT
        o.order_id,
        o.order_status,

        i.item_total,
        p.payment_total,

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
        END AS reconciliation_status,

        p.payment_total - i.item_total
            AS payment_difference

    FROM staging.stg_orders AS o

    LEFT JOIN item_totals AS i
        ON o.order_id = i.order_id

    LEFT JOIN payment_totals AS p
        ON o.order_id = p.order_id

)

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
            ), 0
        ),
        2
    ) AS match_rate_pct,

    SUM(item_total) FILTER (
        WHERE reconciliation_status
              IN ('MATCH', 'MISMATCH')
    ) AS total_item_value,

    SUM(payment_total) FILTER (
        WHERE reconciliation_status
              IN ('MATCH', 'MISMATCH')
    ) AS total_payment_value,

    SUM(payment_difference)
        AS net_difference,

    SUM(ABS(payment_difference))
        AS absolute_difference,

    SUM(payment_difference) FILTER (
        WHERE payment_difference > 0
    ) AS positive_differences,

    SUM(payment_difference) FILTER (
        WHERE payment_difference < 0
    ) AS negative_differences

FROM reconciled;


-- =====================================================
-- CHECK C: Mismatch rates by order status
-- =====================================================

WITH item_totals AS (

    SELECT
        order_id,
        SUM(item_total_amount) AS item_total

    FROM staging.stg_order_items
    GROUP BY order_id

),

payment_totals AS (

    SELECT
        order_id,
        SUM(payment_amount) AS payment_total

    FROM staging.stg_order_payments
    GROUP BY order_id

),

comparable_orders AS (

    SELECT
        o.order_status,

        p.payment_total - i.item_total
            AS payment_difference

    FROM staging.stg_orders AS o

    INNER JOIN item_totals AS i
        ON o.order_id = i.order_id

    INNER JOIN payment_totals AS p
        ON o.order_id = p.order_id

)

SELECT
    order_status,

    COUNT(*) AS comparable_orders,

    COUNT(*) FILTER (
        WHERE payment_difference <> 0
    ) AS mismatched_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE payment_difference <> 0
        ) / COUNT(*),
        3
    ) AS mismatch_rate_pct

FROM comparable_orders

GROUP BY order_status

ORDER BY mismatched_orders DESC, order_status;
