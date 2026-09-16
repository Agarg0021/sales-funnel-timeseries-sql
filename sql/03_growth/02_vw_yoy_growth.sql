-- =============================================================================
-- 02_vw_yoy_growth.sql
-- Year-over-year (YoY) sales growth, broken out by category and by region.
--
-- Technique: LAG(monthly_sales, 12) OVER (PARTITION BY dimension ORDER BY year_month)
--   - Same LAG pattern as MoM, but with an offset of 12 rows instead of 1,
--     since our partition is ordered by calendar month and 12 months back
--     is "this month, last year".
--   - This only works cleanly because every dimension_value has one row per
--     month with no gaps (every category/region sells something most months
--     in this dataset) — LAG counts *rows*, not calendar time, so a missing
--     month would silently pull the wrong prior period. Safe here; worth a
--     comment for anyone porting this pattern to sparser data.
-- =============================================================================

DROP VIEW IF EXISTS vw_yoy_growth;

CREATE VIEW vw_yoy_growth AS
WITH by_category AS (
    SELECT
        'category'                     AS dimension_type,
        category                       AS dimension_value,
        strftime('%Y-%m', order_date)  AS year_month,
        ROUND(SUM(sales), 2)           AS monthly_sales
    FROM stg_orders
    GROUP BY category, year_month
),
by_region AS (
    SELECT
        'region'                       AS dimension_type,
        region                         AS dimension_value,
        strftime('%Y-%m', order_date)  AS year_month,
        ROUND(SUM(sales), 2)           AS monthly_sales
    FROM stg_orders
    GROUP BY region, year_month
),
combined AS (
    SELECT * FROM by_category
    UNION ALL
    SELECT * FROM by_region
)
SELECT
    dimension_type,
    dimension_value,
    year_month,
    monthly_sales,
    LAG(monthly_sales, 12) OVER (
        PARTITION BY dimension_type, dimension_value
        ORDER BY year_month
    ) AS same_month_last_year_sales,
    ROUND(
        (monthly_sales - LAG(monthly_sales, 12) OVER (
            PARTITION BY dimension_type, dimension_value
            ORDER BY year_month
        )) * 100.0 /
        NULLIF(LAG(monthly_sales, 12) OVER (
            PARTITION BY dimension_type, dimension_value
            ORDER BY year_month
        ), 0),
        2
    ) AS yoy_growth_pct
FROM combined
ORDER BY dimension_type, dimension_value, year_month;

-- Preview:
-- SELECT * FROM vw_yoy_growth WHERE dimension_type = 'category' AND dimension_value = 'Furniture'
--   AND yoy_growth_pct IS NOT NULL;
