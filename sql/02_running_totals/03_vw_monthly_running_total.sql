-- =============================================================================
-- 03_vw_monthly_running_total.sql
-- Day 2: Cumulative (running) sales total per category, month over month.
-- This is the classic "YTD-style" dashboard metric: each category resets
-- its own running total independently.
--
-- Technique: SUM(...) OVER (PARTITION BY category ORDER BY year_month)
--   - PARTITION BY category makes the running total restart for each
--     category, instead of accumulating across all categories combined.
-- =============================================================================

DROP VIEW IF EXISTS vw_monthly_running_total;

CREATE VIEW vw_monthly_running_total AS
WITH monthly_category_sales AS (
    SELECT
        strftime('%Y-%m', order_date) AS year_month,
        category,
        ROUND(SUM(sales), 2) AS monthly_sales
    FROM stg_orders
    GROUP BY year_month, category
)
SELECT
    year_month,
    category,
    monthly_sales,
    ROUND(
        SUM(monthly_sales) OVER (
            PARTITION BY category
            ORDER BY year_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 2
    ) AS running_total_sales
FROM monthly_category_sales
ORDER BY category, year_month;

-- Preview:
-- SELECT * FROM vw_monthly_running_total WHERE category = 'Technology' LIMIT 15;
