-- =============================================================================
-- 04_sanity_checks.sql
-- Day 1: Confirm the dataset is clean and shaped correctly before building
-- window-function views on top of it in Days 2-5.
-- =============================================================================

-- 1. Row counts & date range
SELECT
    COUNT(*)                AS total_rows,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS total_customers,
    MIN(order_date)         AS first_order,
    MAX(order_date)         AS last_order
FROM stg_orders;

-- 2. Any NULLs in key columns? (should return 0 rows)
SELECT *
FROM stg_orders
WHERE order_id IS NULL
   OR order_date IS NULL
   OR customer_id IS NULL
   OR category IS NULL
   OR sales IS NULL;

-- 3. Sales by category (sanity on category distribution)
SELECT category, COUNT(*) AS line_items, ROUND(SUM(sales), 2) AS total_sales
FROM stg_orders
GROUP BY category
ORDER BY total_sales DESC;

-- 4. Monthly order volume (quick look at seasonality before we build MoM/YoY views)
SELECT
    strftime('%Y-%m', order_date) AS year_month,
    COUNT(DISTINCT order_id)      AS orders,
    ROUND(SUM(sales), 2)          AS total_sales
FROM stg_orders
GROUP BY year_month
ORDER BY year_month;

-- 5. Customers with the most active months (preview of Day 5 streak analysis)
SELECT
    customer_id,
    customer_name,
    COUNT(DISTINCT strftime('%Y-%m', order_date)) AS active_months
FROM stg_orders
GROUP BY customer_id, customer_name
ORDER BY active_months DESC
LIMIT 10;
