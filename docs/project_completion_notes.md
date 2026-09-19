# Project Completion Notes

All 5 planned days are complete. 9 dashboard-ready SQL views live in
`database/superstore.db`, built from the SQL/Python files in `sql/`.

## Full view catalog

| # | View | Folder | Key window function |
|---|---|---|---|
| 1 | `vw_daily_sales_running_total` | `02_running_totals` | `SUM() OVER (ORDER BY ... ROWS UNBOUNDED PRECEDING)` |
| 2 | `vw_7day_moving_avg` | `02_running_totals` | `AVG() OVER (... ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)` |
| 3 | `vw_monthly_running_total` | `02_running_totals` | `SUM() OVER (PARTITION BY category ORDER BY year_month)` |
| 4 | `vw_mom_growth` | `03_growth` | `LAG(monthly_sales) OVER (PARTITION BY dimension ...)` |
| 5 | `vw_yoy_growth` | `03_growth` | `LAG(monthly_sales, 12) OVER (PARTITION BY dimension ...)` |
| 6 | `vw_top5_products_per_category` | `04_ranking` | `ROW_NUMBER() OVER (PARTITION BY category ORDER BY total_sales DESC)` |
| 7 | `vw_customer_percentile_rank` | `04_ranking` | `RANK()` + `PERCENT_RANK() OVER (ORDER BY total_sales)` |
| 8 | `vw_customer_purchase_streaks` | `05_streaks` | Gap-and-island: `month_index - ROW_NUMBER() OVER (...)` |
| 9 | `vw_customer_longest_streak` | `05_streaks` | `ROW_NUMBER() OVER (PARTITION BY customer ORDER BY streak_length DESC)` |

## Rebuild everything from scratch

\`\`\`bash
cd sales-funnel-timeseries-sql
python3 data/generate_data.py
python3 sql/01_setup/03_load_data.py
python3 sql/02_running_totals/build_views_day2.py
python3 sql/03_growth/build_views_day3.py
python3 sql/04_ranking/build_views_day4.py
python3 sql/05_streaks/build_views_day5.py
\`\`\`

Confirmed working end-to-end: all 9 views build cleanly in this order against
a freshly regenerated database.

## Design decisions worth remembering

- **SQLite** chosen for zero-setup portability; every script uses standard
  SQL (window functions, CTEs) that ports to Postgres/MySQL 8+/Snowflake
  with minimal changes.
- **`dimension_type` / `dimension_value` pattern** (growth views): unions
  category-level and region-level aggregates into one view instead of two,
  so a single dashboard filter dropdown can switch between them.
- **`ROW_NUMBER` vs `RANK`**: `ROW_NUMBER` used wherever an exact row count
  matters (Top-5 products, longest streak per customer — guarantees no
  more/fewer rows than intended even with ties). `RANK` used only where
  ties should visibly share a position (customer spend rank).
- **Gap-and-island (`month_index - ROW_NUMBER()`)**: the core trick behind
  `vw_customer_purchase_streaks`. Verified against a customer with a real
  gap (CU-10023, skipped Oct 2025) — correctly split into two streaks
  summing to their full active-month count.

## Possible next steps (beyond the original 5-day scope)

- Connect a BI tool (Metabase, Tableau, Power BI) directly to
  `database/superstore.db` to turn these views into an actual dashboard.
- Port schema + views to Postgres for a more production-realistic setup.
- Add a `vw_cohort_retention` view (first-purchase-month cohorts) as a
  natural extension of the streak analysis.