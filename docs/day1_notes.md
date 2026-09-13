# Day 1 Notes

## What was built
- Full project folder structure (see README.md)
- Synthetic Superstore-style dataset (16,156 rows / 6,453 orders / 220 customers)
- SQLite database (`database/superstore.db`) with:
  - `stg_orders` staging table + indexes on (order_date), (customer_id, order_date),
    (category, order_date), (region, order_date) — these match the PARTITION BY /
    ORDER BY patterns the Day 2-5 window functions will use
  - `dim_date` calendar dimension
- Sanity checks confirming clean data, expected seasonality, and enough
  repeat-customer signal for the Day 5 streak analysis

## Design decisions
- SQLite chosen for zero-setup portability; all window functions used in this
  project (SUM/AVG OVER, LAG, ROW_NUMBER, RANK, PERCENT_RANK) are supported
  natively in SQLite 3.25+.
- Indexes added up front on the exact partition/order columns the later
  window-function views will use, to keep dashboard queries fast.
- Data generation seeded (`random.seed(42)`) for reproducibility.

## Next: Day 2
Build `sql/02_running_totals/`:
- `vw_daily_sales_running_total` — SUM(sales) OVER (ORDER BY order_date ROWS UNBOUNDED PRECEDING)
- `vw_7day_moving_avg` — AVG(sales) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
- `vw_monthly_running_total` — per category, using dim_date.year_month
