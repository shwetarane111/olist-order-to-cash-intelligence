
-- ==========================================================
-- PROJECT: Order-to-Cash Intelligence Platform
-- DATABASE: olist_analytics
-- SCHEMA: raw
-- PURPOSE: Create tables for all 9 Olist CSV source files
-- ==========================================================

-- 1. ORDERS
CREATE TABLE IF NOT EXISTS raw.orders (
    order_id TEXT,
    customer_id TEXT,
    order_status TEXT,
    order_purchase_timestamp TEXT,
    order_approved_at TEXT,
    order_delivered_carrier_date TEXT,
    order_delivered_customer_date TEXT,
    order_estimated_delivery_date TEXT
);

-- 2. ORDER ITEMS
CREATE TABLE IF NOT EXISTS raw.order_items (
    order_id TEXT,
    order_item_id INTEGER,
    product_id TEXT,
    seller_id TEXT,
    shipping_limit_date TEXT,
    price NUMERIC(14,2),
    freight_value NUMERIC(14,2)
);

-- 3. ORDER PAYMENTS
CREATE TABLE IF NOT EXISTS raw.order_payments (
    order_id TEXT,
    payment_sequential INTEGER,
    payment_type TEXT,
    payment_installments INTEGER,
    payment_value NUMERIC(14,2)
);

-- 4. CUSTOMERS
CREATE TABLE IF NOT EXISTS raw.customers (
    customer_id TEXT,
    customer_unique_id TEXT,
    customer_zip_code_prefix TEXT,
    customer_city TEXT,
    customer_state TEXT
);

-- 5. PRODUCTS
-- Note: "lenght" matches the original Olist column spelling
CREATE TABLE IF NOT EXISTS raw.products (
    product_id TEXT,
    product_category_name TEXT,
    product_name_lenght INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty INTEGER,
    product_weight_g NUMERIC(12,2),
    product_length_cm NUMERIC(12,2),
    product_height_cm NUMERIC(12,2),
    product_width_cm NUMERIC(12,2)
);

-- 6. SELLERS
CREATE TABLE IF NOT EXISTS raw.sellers (
    seller_id TEXT,
    seller_zip_code_prefix TEXT,
    seller_city TEXT,
    seller_state TEXT
);

-- 7. ORDER REVIEWS
CREATE TABLE IF NOT EXISTS raw.order_reviews (
    review_id TEXT,
    order_id TEXT,
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TEXT,
    review_answer_timestamp TEXT
);

-- 8. GEOLOCATION
CREATE TABLE IF NOT EXISTS raw.geolocation (
    geolocation_zip_code_prefix TEXT,
    geolocation_lat DOUBLE PRECISION,
    geolocation_lng DOUBLE PRECISION,
    geolocation_city TEXT,
    geolocation_state TEXT
);

-- 9. PRODUCT CATEGORY TRANSLATION
CREATE TABLE IF NOT EXISTS raw.category_translation (
    product_category_name TEXT,
    product_category_name_english TEXT
);

-- ==========================================================
-- VERIFY TABLE STRUCTURE
-- ==========================================================

SELECT
    table_name,
    COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'raw'
GROUP BY table_name
ORDER BY table_name;
