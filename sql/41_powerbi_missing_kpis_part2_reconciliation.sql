-- ================================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- STEP 7.3 - TASK 11
-- FILE: 41_powerbi_missing_kpis_part2_reconciliation.sql
-- Independent PostgreSQL validation, full data & Q1 delivered cohort.
-- Run each SELECT separately in pgAdmin (all are read-only).
-- ================================================================

-- CHECK SQL-1: Strict 5-digit customer ZIP denominators / map coverage.
WITH scoped_orders AS (
    SELECT 'ALL'::TEXT AS cohort, order_id, customer_location_key
    FROM analytics.fact_orders
    UNION ALL
    SELECT 'Q1_2018_DELIVERED', order_id, customer_location_key
    FROM analytics.fact_orders
    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
), classified AS (
    SELECT s.cohort, s.order_id,
           g.customer_location_key IS NULL AS missing_dimension_link,
           COALESCE(g.customer_zip_code_prefix ~ '^[0-9]{5}$', FALSE)
               AS valid_customer_zip,
           g.has_geo_reference,
           g.has_map_ready_coordinate
    FROM scoped_orders s
    LEFT JOIN analytics.dim_customer_geography g
        ON s.customer_location_key = g.customer_location_key
)
SELECT cohort,
       COUNT(*) AS all_orders,
       COUNT(*) FILTER (WHERE valid_customer_zip) AS valid_zip_orders,
       COUNT(*) FILTER (WHERE valid_customer_zip AND has_geo_reference IS TRUE)
           AS valid_zip_matched_orders,
       COUNT(*) FILTER (WHERE valid_customer_zip AND has_map_ready_coordinate IS TRUE)
           AS valid_zip_map_ready_orders,
       COUNT(*) FILTER (WHERE missing_dimension_link) AS missing_dimension_links,
       ROUND(100.0 * COUNT(*) FILTER (
           WHERE valid_customer_zip AND has_geo_reference IS TRUE
       ) / NULLIF(COUNT(*) FILTER (WHERE valid_customer_zip), 0), 2)
           AS customer_zip_reference_coverage_pct,
       ROUND(100.0 * COUNT(*) FILTER (
           WHERE valid_customer_zip AND has_map_ready_coordinate IS TRUE
       ) / NULLIF(COUNT(*) FILTER (WHERE valid_customer_zip), 0), 2)
           AS map_ready_customer_order_coverage_valid_zip_pct
FROM classified
GROUP BY cohort ORDER BY cohort;

-- CHECK SQL-2: Strict 5-digit seller ZIP denominator / coverage.
SELECT COUNT(*) AS total_sellers,
       COUNT(*) FILTER (WHERE seller_zip_code_prefix ~ '^[0-9]{5}$')
           AS sellers_with_valid_zip,
       COUNT(*) FILTER (
           WHERE seller_zip_code_prefix ~ '^[0-9]{5}$'
             AND has_geo_reference IS TRUE
       ) AS valid_zip_sellers_with_reference,
       ROUND(100.0 * COUNT(*) FILTER (
           WHERE seller_zip_code_prefix ~ '^[0-9]{5}$'
             AND has_geo_reference IS TRUE
       ) / NULLIF(COUNT(*) FILTER (
           WHERE seller_zip_code_prefix ~ '^[0-9]{5}$'
       ), 0), 2) AS seller_zip_reference_coverage_pct
FROM analytics.dim_seller;

-- CHECK SQL-3: Seller-order association, multi-order, and top-ten share.
WITH scoped_items AS (
    SELECT 'ALL'::TEXT AS cohort, seller_id, order_id, item_price
    FROM analytics.fact_order_items
    UNION ALL
    SELECT 'Q1_2018_DELIVERED', seller_id, order_id, item_price
    FROM analytics.fact_order_items
    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
), seller_orders AS (
    SELECT cohort, seller_id, COUNT(DISTINCT order_id) AS distinct_orders
    FROM scoped_items
    GROUP BY cohort, seller_id
), seller_prices AS (
    SELECT cohort, seller_id, SUM(item_price) AS item_price_total
    FROM scoped_items
    GROUP BY cohort, seller_id
), ranked_seller_prices AS (
    SELECT cohort, seller_id, item_price_total,
           ROW_NUMBER() OVER (
               PARTITION BY cohort
               ORDER BY item_price_total DESC, seller_id ASC
           ) AS seller_rank
    FROM seller_prices
), orders_summary AS (
    SELECT cohort,
           SUM(distinct_orders) AS seller_order_associations,
           COUNT(*) AS active_sellers,
           COUNT(*) FILTER (WHERE distinct_orders > 1)
               AS sellers_with_multiple_distinct_orders
    FROM seller_orders
    GROUP BY cohort
), price_summary AS (
    SELECT cohort,
           SUM(item_price_total) AS total_seller_item_price,
           SUM(item_price_total) FILTER (WHERE seller_rank <= 10)
               AS top_10_seller_item_price
    FROM ranked_seller_prices
    GROUP BY cohort
)
SELECT o.cohort, o.seller_order_associations, o.active_sellers,
       o.sellers_with_multiple_distinct_orders,
       ROUND(100.0 * o.sellers_with_multiple_distinct_orders /
             NULLIF(o.active_sellers, 0), 2) AS multi_order_seller_share_pct,
       p.total_seller_item_price, p.top_10_seller_item_price,
       ROUND(100.0 * p.top_10_seller_item_price /
             NULLIF(p.total_seller_item_price, 0), 2)
           AS top_10_seller_item_price_concentration_pct
FROM orders_summary o
JOIN price_summary p USING (cohort)
ORDER BY o.cohort;

-- CHECK SQL-4: Category-status share under ALL and Q1 cohort.
-- Tests Product-dimension filter removal using verified category_status.
WITH scoped_items AS (
    SELECT 'ALL'::TEXT AS cohort, product_id, item_price
    FROM analytics.fact_order_items
    UNION ALL
    SELECT 'Q1_2018_DELIVERED', product_id, item_price
    FROM analytics.fact_order_items
    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
)
SELECT i.cohort,
       SUM(i.item_price) AS all_category_item_price,
       SUM(i.item_price) FILTER (
           WHERE p.category_status = 'TRANSLATED'
       ) AS translated_category_item_price,
       ROUND(100.0 * SUM(i.item_price) FILTER (
           WHERE p.category_status = 'TRANSLATED'
       ) / NULLIF(SUM(i.item_price), 0), 2)
           AS translated_category_item_price_share_pct
FROM scoped_items i
JOIN analytics.dim_product p ON i.product_id = p.product_id
GROUP BY i.cohort
ORDER BY i.cohort;

-- CHECK SQL-5: Payment-method amount share by cohort.
WITH scoped_payments AS (
    SELECT 'ALL'::TEXT AS cohort, payment_method, payment_amount,
           payment_installments
    FROM analytics.fact_payments
    UNION ALL
    SELECT 'Q1_2018_DELIVERED', payment_method, payment_amount,
           payment_installments
    FROM analytics.fact_payments
    WHERE order_status = 'delivered'
      AND purchase_date >= DATE '2018-01-01'
      AND purchase_date < DATE '2018-04-01'
), method_summary AS (
    SELECT cohort, payment_method,
           COUNT(*) AS entries,
           SUM(payment_amount) AS recorded_payment_amount,
           COUNT(*) FILTER (
               WHERE payment_method = 'credit_card'
                 AND payment_installments > 0
           ) AS eligible_credit_card_entries,
           ROUND(AVG(payment_installments) FILTER (
               WHERE payment_method = 'credit_card'
                 AND payment_installments > 0
           )::NUMERIC, 4) AS avg_valid_credit_card_installments
    FROM scoped_payments
    GROUP BY cohort, payment_method
)
SELECT cohort, payment_method, entries,
       recorded_payment_amount,
       ROUND(100.0 * recorded_payment_amount /
             NULLIF(SUM(recorded_payment_amount) OVER (PARTITION BY cohort), 0), 2)
           AS amount_share_pct,
       eligible_credit_card_entries,
       avg_valid_credit_card_installments
FROM method_summary
ORDER BY cohort, payment_method;

-- CHECK SQL-6: Prove Product-category share retains a Seller selection.
-- Highest item-price seller: total price descending, seller_id ascending.
WITH leading_seller AS (
    SELECT seller_id
    FROM analytics.fact_order_items
    GROUP BY seller_id
    ORDER BY SUM(item_price) DESC, seller_id ASC
    LIMIT 1
)
SELECT i.seller_id,
       SUM(i.item_price) AS selected_seller_item_price,
       SUM(i.item_price) FILTER (
           WHERE p.category_status = 'TRANSLATED'
       ) AS selected_seller_translated_category_price,
       ROUND(100.0 * SUM(i.item_price) FILTER (
           WHERE p.category_status = 'TRANSLATED'
       ) / NULLIF(SUM(i.item_price), 0), 2)
           AS selected_seller_translated_category_share_pct
FROM analytics.fact_order_items AS i
JOIN leading_seller AS ls ON i.seller_id = ls.seller_id
JOIN analytics.dim_product AS p ON i.product_id = p.product_id
GROUP BY i.seller_id;
