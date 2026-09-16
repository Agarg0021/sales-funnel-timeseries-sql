-- =============================================================================
-- 01_vw_top5_products_per_category.sql
-- Top 5 products by total sales, within each category.
--
-- Technique: ROW_NUMBER() OVER (PARTITION BY category ORDER BY total_sales DESC)
--   - PARTITION BY category restarts the ranking for every category, so
--     "rank 1" means "best-selling product in Furniture", not "best-selling
--     product store-wide".
--   - ROW_NUMBER (not RANK) is used deliberately: if two products in the
--     same category tie exactly on sales, ROW_NUMBER still gives each a
--     distinct rank, guaranteeing exactly 5 rows per category in the final
--     output. RANK would let ties share a rank and could return more or
--     fewer than 5 rows for a category with tied products.
--   - The ranking itself happens in `ranked_products`; the outer SELECT
--     just filters WHERE product_rank <= 5 (a window function's result
--     can't be filtered in the same SELECT's WHERE clause, hence the CTE).
-- =============================================================================

DROP VIEW IF EXISTS vw_top5_products_per_category;

CREATE VIEW vw_top5_products_per_category AS
WITH product_sales AS (
    SELECT
        category,
        sub_category,
        product_id,
        product_name,
        ROUND(SUM(sales), 2)      AS total_sales,
        SUM(quantity)             AS total_quantity,
        ROUND(SUM(profit), 2)     AS total_profit
    FROM stg_orders
    GROUP BY category, sub_category, product_id, product_name
),
ranked_products AS (
    SELECT
        category,
        sub_category,
        product_id,
        product_name,
        total_sales,
        total_quantity,
        total_profit,
        ROW_NUMBER() OVER (
            PARTITION BY category
            ORDER BY total_sales DESC
        ) AS product_rank
    FROM product_sales
)
SELECT
    category,
    sub_category,
    product_id,
    product_name,
    total_sales,
    total_quantity,
    total_profit,
    product_rank
FROM ranked_products
WHERE product_rank <= 5
ORDER BY category, product_rank;

-- Preview:
-- SELECT * FROM vw_top5_products_per_category WHERE category = 'Technology';