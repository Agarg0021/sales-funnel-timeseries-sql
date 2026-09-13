-- =============================================================================
-- 01_vw_daily_sales_running_total.sql
-- Day 2: Running total of sales, day by day, across the whole store.
--
-- Technique: SUM(...) OVER (ORDER BY ... ROWS UNBOUNDED PRECEDING)
--   - We first aggregate to one row per day (daily_sales CTE), because the
--     window function should run over one row per date, not one row per
--     line item.
--   - ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW is the explicit form
--     of a running total: "sum everything from the start up to this row".
-- =============================================================================

DROP VIEW IF EXISTS vw_daily_sales_running_total;

CREATE VIEW vw_daily_sales_running_total AS
WITH daily_sales AS (
    SELECT
        order_date,
        ROUND(SUM(sales), 2)   AS daily_sales,
        COUNT(DISTINCT order_id) AS daily_orders
    FROM stg_orders
    GROUP BY order_date
)
SELECT
    order_date,
    daily_sales,
    daily_orders,
    ROUND(
        SUM(daily_sales) OVER (
            ORDER BY order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 2
    ) AS running_total_sales
FROM daily_sales
ORDER BY order_date;

-- Preview:
-- SELECT * FROM vw_daily_sales_running_total LIMIT 15;
