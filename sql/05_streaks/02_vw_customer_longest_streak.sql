-- =============================================================================
-- 02_vw_customer_longest_streak.sql
-- Each customer's single LONGEST consecutive-month purchase streak.
--
-- Technique: ROW_NUMBER() OVER (PARTITION BY customer ORDER BY streak_length DESC)
--   - This reuses vw_customer_purchase_streaks (every streak for every
--     customer) and just picks the #1 longest streak per customer, the
--     same ROW_NUMBER + PARTITION BY pattern from the Day 4 Top-N view,
--     applied here to streaks instead of products.
--   - Ties (two equally-long streaks for the same customer) are broken by
--     taking the more RECENT one (ORDER BY streak_length_months DESC,
--     streak_end_month DESC), since "most recent long streak" is usually
--     the more actionable one for a re-engagement dashboard.
-- =============================================================================

DROP VIEW IF EXISTS vw_customer_longest_streak;

CREATE VIEW vw_customer_longest_streak AS
WITH ranked_streaks AS (
    SELECT
        customer_id,
        customer_name,
        streak_start_month,
        streak_end_month,
        streak_length_months,
        is_current_streak,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY streak_length_months DESC, streak_end_month DESC
        ) AS streak_rank
    FROM vw_customer_purchase_streaks
)
SELECT
    customer_id,
    customer_name,
    streak_start_month,
    streak_end_month,
    streak_length_months,
    is_current_streak
FROM ranked_streaks
WHERE streak_rank = 1
ORDER BY streak_length_months DESC;

-- Preview:
-- Top 10 longest all-time streaks, store-wide:
-- SELECT * FROM vw_customer_longest_streak ORDER BY streak_length_months DESC LIMIT 10;
--
-- Customers whose longest streak is also their CURRENT one (still active):
-- SELECT * FROM vw_customer_longest_streak WHERE is_current_streak = 1
--   ORDER BY streak_length_months DESC;