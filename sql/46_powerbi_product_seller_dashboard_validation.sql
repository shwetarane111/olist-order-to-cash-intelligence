
-- ==========================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP: 7.4 Task 5
-- PAGE: 05 Product and Seller Performance
-- FILE: 46_powerbi_product_seller_dashboard_validation.sql
-- DATABASE: olist_analytics
-- TYPE: READ-ONLY AUDIT
-- ==========================================================


-- ==========================================================
-- SQL-0: INSPECT PRODUCT CATEGORY LABEL COLUMNS
-- ==========================================================

-- Identify the category label used in your Power BI
-- dim_product table before building the category chart.

SELECT
    column_name,
    data_type

FROM information_schema.columns

WHERE table_schema = 'analytics'
  AND table_name = 'dim_product'
  AND column_name ILIKE '%categor%'

ORDER BY ordinal_position;



-- ==========================================================
-- SQL-1: FULL-DATASET AND Q1 PRODUCT/SELLER BASELINES
-- ==========================================================

WITH scoped_items AS (

    SELECT
        'ALL' AS cohort,
        order_id,
        product_id,
        seller_id,
        item_price,
        freight_amount
    FROM analytics.fact_order_items

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED',
        order_id,
        product_id,
        seller_id,
        item_price,
        freight_amount
    FROM analytics.fact_order_items

    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'

),

item_summary AS (

    SELECT
        cohort,
        COUNT(*) AS item_entries,
        COUNT(DISTINCT product_id) AS active_products,
        COUNT(DISTINCT seller_id) AS active_sellers,

        ROUND(
            SUM(item_price)::numeric, 2
        ) AS recorded_item_price,

        ROUND(
            SUM(freight_amount)::numeric, 2
        ) AS recorded_freight

    FROM scoped_items
    GROUP BY cohort

),

seller_order_pairs AS (

    SELECT DISTINCT
        cohort,
        seller_id,
        order_id
    FROM scoped_items

),

seller_order_counts AS (

    SELECT
        cohort,
        seller_id,
        COUNT(*) AS distinct_orders

    FROM seller_order_pairs

    GROUP BY cohort, seller_id

),

seller_summary AS (

    SELECT
        cohort,

        SUM(distinct_orders)
            AS seller_order_associations,

        COUNT(*) FILTER (
            WHERE distinct_orders >= 2
        ) AS multi_order_sellers

    FROM seller_order_counts

    GROUP BY cohort

),

seller_values AS (

    SELECT
        cohort,
        seller_id,
        SUM(item_price) AS seller_item_price

    FROM scoped_items

    GROUP BY cohort, seller_id

),

ranked_sellers AS (

    SELECT
        cohort,
        seller_id,
        seller_item_price,

        ROW_NUMBER() OVER (
            PARTITION BY cohort
            ORDER BY
                seller_item_price DESC,
                seller_id ASC
        ) AS seller_rank

    FROM seller_values

),

top_ten AS (

    SELECT
        cohort,

        ROUND(
            SUM(seller_item_price)::numeric,
            2
        ) AS top_ten_item_price

    FROM ranked_sellers

    WHERE seller_rank <= 10

    GROUP BY cohort

)

SELECT
    i.cohort,
    i.item_entries,
    i.recorded_item_price,
    i.recorded_freight,

    i.active_products,
    i.active_sellers,

    s.seller_order_associations,
    s.multi_order_sellers,

    ROUND(
        100.0 * s.multi_order_sellers
        / NULLIF(i.active_sellers, 0),
        2
    ) AS multi_order_seller_share_pct,

    t.top_ten_item_price,

    ROUND(
        100.0 * t.top_ten_item_price
        / NULLIF(i.recorded_item_price, 0),
        2
    ) AS top_ten_concentration_pct,

    CASE
        WHEN s.multi_order_sellers <= i.active_sellers
         AND s.seller_order_associations <= i.item_entries
        THEN 'PASS'
        ELSE 'FAIL'
    END AS population_check

FROM item_summary AS i

JOIN seller_summary AS s
    USING (cohort)

JOIN top_ten AS t
    USING (cohort)

ORDER BY i.cohort;



-- ==========================================================
-- SQL-2: TOP 10 SELLER LEADERBOARD
-- ==========================================================

WITH scoped_items AS (

    SELECT
        'ALL' AS cohort,
        seller_id,
        item_price
    FROM analytics.fact_order_items

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED',
        seller_id,
        item_price
    FROM analytics.fact_order_items

    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'

),

seller_amounts AS (

    SELECT
        cohort,
        seller_id,

        SUM(item_price) AS item_price

    FROM scoped_items

    GROUP BY cohort, seller_id

),

ranked AS (

    SELECT
        cohort,
        seller_id,
        item_price,

        ROW_NUMBER() OVER (
            PARTITION BY cohort
            ORDER BY item_price DESC, seller_id ASC
        ) AS seller_rank

    FROM seller_amounts

)

SELECT
    cohort,
    seller_rank,
    seller_id,

    ROUND(
        item_price::numeric,
        2
    ) AS item_price

FROM ranked

WHERE seller_rank <= 10

ORDER BY
    cohort,
    seller_rank;



-- ==========================================================
-- SQL-3: TOP PRODUCT CATEGORIES BY ITEM PRICE
-- ==========================================================

-- Uses a reporting-label fallback for differently named
-- English category fields.
--
-- After SQL-0, confirm that the label selected in Power BI
-- matches the reporting label used here.
-- This query does not discard untranslated/missing labels.

WITH scoped_items AS (

    SELECT
        'ALL' AS cohort,
        product_id,
        item_price
    FROM analytics.fact_order_items

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED',
        product_id,
        item_price
    FROM analytics.fact_order_items

    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'

),

labeled AS (

    SELECT
        s.cohort,
        s.item_price,

        COALESCE(
            NULLIF(
                to_jsonb(p)->>'product_category_name_english',
                ''
            ),
            NULLIF(
                to_jsonb(p)->>'category_name_english',
                ''
            ),
            NULLIF(
                to_jsonb(p)->>'category_english',
                ''
            ),
            NULLIF(
                to_jsonb(p)->>'category_label',
                ''
            ),
            NULLIF(
                to_jsonb(p)->>'product_category_name',
                ''
            ),
            CASE
                WHEN p.category_status =
                    'MISSING_SOURCE_CATEGORY'
                    THEN 'Missing source category'

                WHEN p.category_status = 'UNTRANSLATED'
                    THEN 'Untranslated category'

                ELSE 'Unlabeled category'
            END
        ) AS reporting_category

    FROM scoped_items AS s

    JOIN analytics.dim_product AS p
        ON s.product_id = p.product_id

),

category_amounts AS (

    SELECT
        cohort,
        reporting_category,

        SUM(item_price) AS category_item_price

    FROM labeled

    GROUP BY cohort, reporting_category

),

ranked AS (

    SELECT
        cohort,
        reporting_category,
        category_item_price,

        ROW_NUMBER() OVER (
            PARTITION BY cohort
            ORDER BY
                category_item_price DESC,
                reporting_category ASC
        ) AS category_rank

    FROM category_amounts

)

SELECT
    cohort,
    category_rank,
    reporting_category,

    ROUND(
        category_item_price::numeric,
        2
    ) AS recorded_item_price

FROM ranked

WHERE category_rank <= 10

ORDER BY cohort, category_rank;



-- ==========================================================
-- SQL-4: MONTHLY ITEM AND SELLER PERFORMANCE
-- ==========================================================

WITH monthly_items AS (

    SELECT
        date_trunc(
            'month',
            purchase_date
        )::date AS purchase_month,

        order_id,
        seller_id,
        product_id,
        item_price,
        freight_amount

    FROM analytics.fact_order_items

    WHERE purchase_date IS NOT NULL

),

monthly_summary AS (

    SELECT
        purchase_month,

        COUNT(*) AS item_entries,

        COUNT(DISTINCT product_id)
            AS active_products,

        COUNT(DISTINCT seller_id)
            AS active_sellers,

        ROUND(
            SUM(item_price)::numeric, 2
        ) AS recorded_item_price,

        ROUND(
            SUM(freight_amount)::numeric, 2
        ) AS recorded_freight

    FROM monthly_items

    GROUP BY purchase_month

),

seller_month_orders AS (

    SELECT
        purchase_month,
        seller_id,

        COUNT(DISTINCT order_id)
            AS distinct_orders

    FROM monthly_items

    GROUP BY purchase_month, seller_id

),

repeat_seller_months AS (

    SELECT
        purchase_month,

        COUNT(*) FILTER (
            WHERE distinct_orders >= 2
        ) AS multi_order_sellers

    FROM seller_month_orders

    GROUP BY purchase_month

)

SELECT
    m.purchase_month,
    m.item_entries,
    m.recorded_item_price,
    m.recorded_freight,
    m.active_products,
    m.active_sellers,
    r.multi_order_sellers,

    ROUND(
        100.0 * r.multi_order_sellers
        / NULLIF(m.active_sellers, 0),
        2
    ) AS multi_order_seller_share_pct

FROM monthly_summary AS m

JOIN repeat_seller_months AS r
    USING (purchase_month)

ORDER BY m.purchase_month;



-- ==========================================================
-- SQL-5: PRODUCT CATALOG CLASSIFICATION AUDIT
-- ==========================================================

-- This checks that the top-category chart does not
-- silently exclude item prices tied to untranslated
-- or missing source-category labels.

WITH scoped_items AS (

    SELECT
        'ALL' AS cohort,
        product_id,
        item_price
    FROM analytics.fact_order_items

    UNION ALL

    SELECT
        'Q1_2018_DELIVERED',
        product_id,
        item_price
    FROM analytics.fact_order_items

    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'

)

SELECT
    s.cohort,
    p.category_status,

    COUNT(*) AS item_entries,

    ROUND(
        SUM(s.item_price)::numeric,
        2
    ) AS recorded_item_price

FROM scoped_items AS s

JOIN analytics.dim_product AS p
    ON s.product_id = p.product_id

GROUP BY
    s.cohort,
    p.category_status

ORDER BY
    s.cohort,
    p.category_status;



-- ==========================================================
-- EXPECTED FULL-DATASET BASELINES
-- ==========================================================

-- Item Entries: 112,650
-- Item Price: 13,591,643.70
-- Freight: 2,251,909.54
-- Active Products: 32,951
-- Active Sellers: 3,095
-- Seller-Order Associations: 100,010
-- Multi-Order Sellers: 2,524
-- Multi-Order Seller Share: 81.55%
-- Top 10 Seller Price: 1,787,241.74
-- Top 10 Concentration: 13.15%

-- SQL-5 ALL classification:
-- TRANSLATED: 13,406,593.94
-- MISSING_SOURCE_CATEGORY: 179,535.28
-- UNTRANSLATED: 5,514.48

-- Classification totals: 13,591,643.70


-- ==========================================================
-- EXPECTED Q1 2018 DELIVERED BASELINES
-- ==========================================================

-- Item Entries: 23,572
-- Item Price: 2,704,438.38
-- Active Sellers: 1,351
-- Seller-Order Associations: 20,885
-- Multi-Order Sellers: 1,064
-- Multi-Order Seller Share: 78.76%
-- Top 10 Seller Price: 393,589.46
-- Top 10 Concentration: 14.55%

-- Q1 translated category item price: 2,653,997.57
-- Q1 translated category share: 98.13%

-- Record Q1 active product count and freight amount
-- from SQL-1; do not invent their baselines.


-- ==========================================================
-- VALIDATION RULES
-- ==========================================================

-- SQL-0:
-- Identify and verify actual category label columns.

-- SQL-1:
-- Exactly 2 rows, full data and Q1 delivered.
-- All measures match DAX Check F1.
-- Population Check must be PASS.

-- SQL-2:
-- Exactly 10 sellers per cohort.
-- Sum of item price matches Top 10 DAX value.
-- Seller IDs are the deterministic tie-breaker.

-- SQL-3:
-- Compare category names and amounts with Power BI.
-- Ensure label grouping is the same.
-- If only category_status is available in Power BI,
-- compare classification groups using SQL-5 instead.

-- SQL-4:
-- Compare at least Jan, Feb and Mar 2018 with
-- corresponding Power BI monthly chart tooltips.

-- SQL-5:
-- All category-status values collectively reproduce
-- the total recorded item price.

-- No statements mutate source data.

-- ==========================================================
-- END OF FILE
-- ==========================================================
