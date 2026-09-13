-- =============================================================================
-- 02_vw_7day_moving_avg.sql
-- Day 2: 7-day moving average of daily sales — smooths out day-to-day noise
-- so a dashboard trend line is readable.
--
-- Technique: AVG(...) OVER (ORDER BY ... ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
--   - "6 PRECEDING AND CURRENT ROW" = a 7-row window (today + previous 6 days).
--   - Because not every calendar date necessarily has an order in this data,
--     we first build a complete daily series (LEFT JOIN dim_date -> stg_orders,
--     COALESCE missing days to 0) so the 7-day window is a true 7 *calendar*
--     days, not just "the last 7 rows that happened to have sales".
-- =============================================================================

DROP VIEW IF EXISTS vw_7day_moving_avg;

CREATE VIEW vw_7day_moving_avg AS
WITH calendar_sales AS (
    SELECT
        d.date_key AS order_date,
        COALESCE(ROUND(SUM(s.sales), 2), 0) AS daily_sales
    FROM dim_date d
    LEFT JOIN stg_orders s ON s.order_date = d.date_key
    GROUP BY d.date_key
)
SELECT
    order_date,
    daily_sales,
    ROUND(
        AVG(daily_sales) OVER (
            ORDER BY order_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2
    ) AS moving_avg_7day
FROM calendar_sales
ORDER BY order_date;

-- Preview:
-- SELECT * FROM vw_7day_moving_avg LIMIT 15;
