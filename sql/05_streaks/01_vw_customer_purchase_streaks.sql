-- =============================================================================
-- 01_vw_customer_purchase_streaks.sql
-- Every consecutive-month purchase streak ("island") for every customer.
--
-- Technique: classic gap-and-island via a "group id" trick:
--   1. active_months: one row per (customer, month) they placed an order in,
--      converted to a single incrementing integer `month_index` (year*12 +
--      month) so consecutive calendar months are consecutive integers —
--      this is what makes the arithmetic below work across year boundaries
--      (Dec 2023 -> Jan 2024 is month_index N -> N+1, same as any other
--      adjacent pair).
--   2. row_num: ROW_NUMBER() OVER (PARTITION BY customer ORDER BY month_index)
--      gives each of a customer's active months a simple 1, 2, 3... position.
--   3. island_id = month_index - row_num. This is the trick: within one
--      unbroken run of consecutive months, month_index increases by 1 every
--      row and row_num ALSO increases by 1 every row, so their difference
--      stays constant. The moment there's a gap (a month with no purchase),
--      month_index jumps by more than 1 while row_num still only increases
--      by 1 -- so island_id changes, marking the start of a new streak.
--   4. Group by (customer, island_id) and aggregate MIN/MAX/COUNT to get
--      each streak's start month, end month, and length.
--
-- is_current_streak flags whether a streak's end month is the most recent
-- month in the whole dataset -- i.e. this customer is *still* active right
-- up to the end of the data, not just historically loyal.
-- =============================================================================

DROP VIEW IF EXISTS vw_customer_purchase_streaks;

CREATE VIEW vw_customer_purchase_streaks AS
WITH active_months AS (
    SELECT DISTINCT
        customer_id,
        customer_name,
        strftime('%Y-%m', order_date) AS year_month,
        CAST(strftime('%Y', order_date) AS INTEGER) * 12
            + CAST(strftime('%m', order_date) AS INTEGER) AS month_index
    FROM stg_orders
),
numbered AS (
    SELECT
        customer_id,
        customer_name,
        year_month,
        month_index,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY month_index
        ) AS row_num
    FROM active_months
),
islands AS (
    SELECT
        customer_id,
        customer_name,
        year_month,
        month_index,
        month_index - row_num AS island_id   -- constant within one streak
    FROM numbered
),
streaks AS (
    SELECT
        customer_id,
        customer_name,
        island_id,
        MIN(year_month)   AS streak_start_month,
        MAX(year_month)   AS streak_end_month,
        COUNT(*)          AS streak_length_months
    FROM islands
    GROUP BY customer_id, customer_name, island_id
),
max_month AS (
    SELECT MAX(strftime('%Y-%m', order_date)) AS latest_month FROM stg_orders
)
SELECT
    s.customer_id,
    s.customer_name,
    s.streak_start_month,
    s.streak_end_month,
    s.streak_length_months,
    (s.streak_end_month = m.latest_month) AS is_current_streak
FROM streaks s
CROSS JOIN max_month m
ORDER BY s.customer_id, s.streak_start_month;

-- Preview:
-- All streaks for one customer, longest first:
-- SELECT * FROM vw_customer_purchase_streaks WHERE customer_id = 'CU-10005'
--   ORDER BY streak_length_months DESC;
--
-- Every currently-active streak of 6+ months, longest first:
-- SELECT * FROM vw_customer_purchase_streaks
--   WHERE is_current_streak = 1 AND streak_length_months >= 6
--   ORDER BY streak_length_months DESC;