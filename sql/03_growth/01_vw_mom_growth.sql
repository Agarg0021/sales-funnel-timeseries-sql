-- =============================================================================
-- 01_vw_mom_growth.sql
-- Month-over-month (MoM) sales growth, broken out by category and by region.
--
-- Technique: LAG(monthly_sales) OVER (PARTITION BY dimension ORDER BY year_month)
--   - LAG(..., 1) grabs the PREVIOUS row's value within the same partition
--     (i.e. the same category's sales from the prior month).
--   - Growth % = (current - previous) / previous * 100. Guarded against
--     divide-by-zero with NULLIF.
--
-- Structure: two independent CTEs (by_category, by_region) unioned together
-- with a `dimension_type` / `dimension_value` pair, so one dashboard-ready
-- view can drive a filter dropdown ("Category" vs "Region") instead of
-- needing two separate views wired into the dashboard.
-- =============================================================================

DROP VIEW IF EXISTS vw_mom_growth;

CREATE VIEW vw_mom_growth AS
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
    LAG(monthly_sales) OVER (
        PARTITION BY dimension_type, dimension_value
        ORDER BY year_month
    ) AS prev_month_sales,
    ROUND(
        (monthly_sales - LAG(monthly_sales) OVER (
            PARTITION BY dimension_type, dimension_value
            ORDER BY year_month
        )) * 100.0 /
        NULLIF(LAG(monthly_sales) OVER (
            PARTITION BY dimension_type, dimension_value
            ORDER BY year_month
        ), 0),
        2
    ) AS mom_growth_pct
FROM combined
ORDER BY dimension_type, dimension_value, year_month;

-- Preview:
-- SELECT * FROM vw_mom_growth WHERE dimension_type = 'category' AND dimension_value = 'Technology';
-- SELECT * FROM vw_mom_growth WHERE dimension_type = 'region' AND dimension_value = 'West';