
-- =====================================================
-- STEP 4.6 - TASK 3
-- CHECK A: Source data-quality baseline comparison
-- =====================================================

WITH checks(metric, actual_count, expected_count) AS (
    VALUES

    -- PAYMENT EXCEPTIONS
    (
        'Zero-value payments',
        (SELECT COUNT(*)
         FROM raw.order_payments
         WHERE payment_value = 0),
        9::BIGINT
    ),

    (
        'Zero-installment payments',
        (SELECT COUNT(*)
         FROM raw.order_payments
         WHERE payment_installments = 0),
        2::BIGINT
    ),

    (
        'Undefined payment methods',
        (SELECT COUNT(*)
         FROM raw.order_payments
         WHERE payment_type = 'not_defined'),
        3::BIGINT
    ),

    (
        'Negative payment values',
        (SELECT COUNT(*)
         FROM raw.order_payments
         WHERE payment_value < 0),
        0::BIGINT
    ),

    -- PRODUCT EXCEPTIONS
    (
        'Products missing categories',
        (SELECT COUNT(*)
         FROM raw.products
         WHERE product_category_name IS NULL),
        610::BIGINT
    ),

    (
        'Products missing weights',
        (SELECT COUNT(*)
         FROM raw.products
         WHERE product_weight_g IS NULL),
        2::BIGINT
    ),

    (
        'Products with zero weight',
        (SELECT COUNT(*)
         FROM raw.products
         WHERE product_weight_g = 0),
        4::BIGINT
    ),

    -- REVIEW EXCEPTIONS
    (
        'NULL review titles',
        (SELECT COUNT(*)
         FROM raw.order_reviews
         WHERE review_comment_title IS NULL),
        87656::BIGINT
    ),

    (
        'Blank or whitespace review titles',
        (SELECT COUNT(*)
         FROM raw.order_reviews
         WHERE review_comment_title IS NOT NULL
           AND TRIM(review_comment_title) = ''),
        2::BIGINT
    ),

    (
        'NULL review messages',
        (SELECT COUNT(*)
         FROM raw.order_reviews
         WHERE review_comment_message IS NULL),
        58247::BIGINT
    ),

    (
        'Blank or whitespace review messages',
        (SELECT COUNT(*)
         FROM raw.order_reviews
         WHERE review_comment_message IS NOT NULL
           AND TRIM(review_comment_message) = ''),
        9::BIGINT
    ),

    (
        'Missing review scores',
        (SELECT COUNT(*)
         FROM raw.order_reviews
         WHERE review_score IS NULL),
        0::BIGINT
    )
)

SELECT
    metric,
    actual_count,
    expected_count,

    CASE
        WHEN actual_count = expected_count
        THEN 'PASS'
        ELSE 'FAIL'
    END AS audit_status

FROM checks

ORDER BY metric;


-- =====================================================
-- CHECK B: Full order-level financial reconciliation
-- =====================================================

WITH item_totals AS (

    SELECT
        order_id,
        SUM(price + freight_value) AS item_total

    FROM raw.order_items

    GROUP BY order_id
),

payment_totals AS (

    SELECT
        order_id,
        SUM(payment_value) AS payment_total

    FROM raw.order_payments

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

    FROM raw.orders AS o

    LEFT JOIN item_totals AS i
        ON o.order_id = i.order_id

    LEFT JOIN payment_totals AS p
        ON o.order_id = p.order_id
)

SELECT
    -- COVERAGE AND CLASSIFICATION
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

    -- MATCH RATE
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

    -- FINANCIAL TOTALS
    SUM(item_total) FILTER (
        WHERE reconciliation_status
              IN ('MATCH', 'MISMATCH')
    ) AS total_item_value,

    SUM(payment_total) FILTER (
        WHERE reconciliation_status
              IN ('MATCH', 'MISMATCH')
    ) AS total_payment_value,

    SUM(payment_difference) AS net_difference,

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
-- CHECK C: Financial mismatch rates by order status
-- =====================================================

WITH item_totals AS (

    SELECT
        order_id,
        SUM(price + freight_value) AS item_total
    FROM raw.order_items
    GROUP BY order_id

),

payment_totals AS (

    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM raw.order_payments
    GROUP BY order_id

),

comparable_orders AS (

    SELECT
        o.order_status,
        p.payment_total - i.item_total
            AS payment_difference

    FROM raw.orders AS o

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

ORDER BY mismatched_orders DESC;
