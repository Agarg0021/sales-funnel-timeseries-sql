-- =============================================================================
-- 02_vw_customer_percentile_rank.sql
-- Where each customer's total lifetime spend falls relative to every other
-- customer — both as a percentile (0.0-1.0) and a plain numeric rank.
--
-- Technique: PERCENT_RANK() OVER (ORDER BY total_sales)
--   - PERCENT_RANK returns (rank - 1) / (total_rows - 1), so the lowest
--     spender is 0.0 and the highest spender is 1.0. This is what a
--     dashboard uses for "this customer is in the top X%" badges.
--   - RANK() is included alongside it for a plain "#N of M customers"
--     display, since PERCENT_RANK alone isn't intuitive to show a customer
--     directly (RANK ties customers with identical spend at the same
--     number, unlike ROW_NUMBER in the Day 4 product view above, which is
--     the correct choice here — two customers who spent exactly the same
--     amount should show the same rank).
--   - segment_percentile_rank re-runs PERCENT_RANK PARTITIONed by segment,
--     so a dashboard can also show "top X% within Consumer/Corporate/Home
--     Office", not just store-wide.
-- =============================================================================

DROP VIEW IF EXISTS vw_customer_percentile_rank;

CREATE VIEW vw_customer_percentile_rank AS
WITH customer_totals AS (
    SELECT
        customer_id,
        customer_name,
        segment,
        region,
        ROUND(SUM(sales), 2)   AS total_sales,
        COUNT(DISTINCT order_id) AS total_orders
    FROM stg_orders
    GROUP BY customer_id, customer_name, segment, region
)
SELECT
    customer_id,
    customer_name,
    segment,
    region,
    total_sales,
    total_orders,
    RANK() OVER (ORDER BY total_sales DESC) AS overall_rank,
    ROUND(
        PERCENT_RANK() OVER (ORDER BY total_sales), 4
    ) AS overall_percentile,
    ROUND(
        PERCENT_RANK() OVER (PARTITION BY segment ORDER BY total_sales), 4
    ) AS segment_percentile
FROM customer_totals
ORDER BY overall_rank;

-- Preview:
-- Top 10 spenders store-wide:
-- SELECT * FROM vw_customer_percentile_rank ORDER BY overall_rank LIMIT 10;
--
-- Customers in the top 10% (percentile >= 0.90) within their own segment:
-- SELECT * FROM vw_customer_percentile_rank WHERE segment_percentile >= 0.90;
