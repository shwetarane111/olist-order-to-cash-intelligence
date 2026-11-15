
-- =====================================================
-- Project: Order-to-Cash Intelligence Platform
-- Database: olist_analytics
-- Purpose: Create warehouse schemas
-- =====================================================

-- Layer 1: Original source data
CREATE SCHEMA IF NOT EXISTS raw;

-- Layer 2: Cleaned and standardized data
CREATE SCHEMA IF NOT EXISTS staging;

-- Layer 3: Business-ready analytical models
CREATE SCHEMA IF NOT EXISTS analytics;

-- =====================================================
-- Verify schema creation
-- =====================================================

SELECT
    schema_name
FROM information_schema.schemata
WHERE schema_name IN ('raw', 'staging', 'analytics')
ORDER BY schema_name;
