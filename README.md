# Sales Funnel / Time-Series Analysis with Window Functions

Dashboard-ready SQL views over a Superstore-style retail dataset, built using
SQL window functions: running totals, moving averages, `PERCENT_RANK`,
`LAG`-based YoY/MoM growth, and gap-and-island consecutive purchase streaks.

## Tech stack
- **Database:** SQLite (`database/superstore.db`) — portable, zero-setup, and
  fully supports the window functions this project needs. Every script is
  written in standard SQL that ports to PostgreSQL/MySQL 8+/Snowflake with
  minimal changes (see notes in each script).
- **Data:** synthetic Superstore-style dataset generated in
  `data/generate_data.py` (see "About the dataset" below).
- **Language:** Python 3 for data generation / loading only. All analysis is
  pure SQL.

## Project structure
sales-funnel-timeseries-sql/
├── README.md
├── data/
│ ├── generate_data.py # synthetic data generator
│ ├── raw/
│ │ └── superstore.csv # generated dataset (16k+ rows)
│ └── processed/ # (reserved for later exports)
├── database/
│ └── superstore.db # SQLite database (built by 03_load_data.py)
├── sql/
│ ├── 01_setup/
│ │ ├── 01_create_schema.sql
│ │ ├── 02_create_dim_date.sql
│ │ ├── 03_load_data.py # builds DB + loads CSV + populates dim_date
│ │ └── 04_sanity_checks.sql
│ ├── 02_running_totals/
│ │ ├── 01_vw_daily_sales_running_total.sql
│ │ ├── 02_vw_7day_moving_avg.sql
│ │ ├── 03_vw_monthly_running_total.sql
│ │ └── build_views_day2.py # creates/refreshes all 3 views at once
│ ├── 03_growth/
│ │ ├── 01_vw_mom_growth.sql
│ │ ├── 02_vw_yoy_growth.sql
│ │ └── build_views_day3.py # creates/refreshes both growth views
│ ├── 04_ranking/
│ │ ├── 01_vw_top5_products_per_category.sql
│ │ ├── 02_vw_customer_percentile_rank.sql
│ │ └── build_views_day4.py # creates/refreshes both ranking views
│ └── 05_streaks/
├── docs/ # ER diagram / notes
└── outputs/ # exported query results, screenshots, etc.

## Schema

**`stg_orders`** — one row per order line item
| column | type | notes |
|---|---|---|
| row_id | INTEGER PK | |
| order_id | TEXT | multiple line items share an order_id |
| order_date | DATE | |
| ship_date | DATE | |
| ship_mode | TEXT | Standard/Second/First Class, Same Day |
| customer_id / customer_name | TEXT | |
| segment | TEXT | Consumer / Corporate / Home Office |
| region / state / city | TEXT | |
| product_id / product_name | TEXT | |
| category / sub_category | TEXT | Furniture, Office Supplies, Technology |
| sales | REAL | |
| quantity | INTEGER | |
| discount | REAL | 0.0–0.4 |
| profit | REAL | can be negative |

**`dim_date`** — one row per calendar day in the data's date range, with
year, month, year_month, quarter, day_of_week — used to make MoM/YoY joins
explicit and to keep this dashboard-ready for BI tools.

## About the dataset

Real network access wasn't available in this environment to pull the actual
Kaggle "Sample Superstore" CSV, so `data/generate_data.py` builds a synthetic
dataset with the **same schema** and realistic properties needed for every
technique in this project:
- 4 full years (2022–2025) of daily order activity
- Nov/Dec seasonal sales spike, summer dip — makes MoM/YoY growth meaningful
- 220 customers with a mix of loyal repeat buyers (consecutive-month runs)
  and sporadic one-off buyers — needed for the gap-and-island streak
  analysis to have real signal
- 3 categories / 13 sub-categories / 34 products, 4 regions

If you'd rather use the real Kaggle Superstore dataset, drop the CSV into
`data/raw/superstore.csv` with matching column names (or adjust the loader)
and re-run `sql/01_setup/03_load_data.py`.

## How to reproduce

```bash
cd sales-funnel-timeseries-sql
python3 data/generate_data.py          # regenerate data/raw/superstore.csv
python3 sql/01_setup/03_load_data.py   # rebuild database/superstore.db
python3 sql/02_running_totals/build_views_day2.py   # running-total views
python3 sql/03_growth/build_views_day3.py           # MoM/YoY growth views
python3 sql/04_ranking/build_views_day4.py          # Top-N / percentile views
```

Then run `sql/01_setup/04_sanity_checks.sql` against `database/superstore.db`
with any SQLite client (DB Browser for SQLite, `sqlite3` CLI, or Python's
`sqlite3` module) to confirm the load.

## Dataset sanity-check results (for reference)

- 16,156 line items across 6,453 orders, 220 customers
- Date range: 2022-01-02 → 2025-12-27
- No NULLs in key columns
- Sales by category: Technology ≈ $13.3M, Furniture ≈ $10.4M, Office Supplies ≈ $1.4M
- Clear seasonality: Nov/Dec months run noticeably higher than the summer months
- Top loyal customers active in 44–47 of the 48 months — good streak material for the gap-and-island analysis

## Running-total & moving-average views (for reference)

| View | Purpose | Key technique |
|---|---|---|
| `vw_daily_sales_running_total` | Store-wide cumulative sales, day by day | `SUM() OVER (ORDER BY order_date ROWS UNBOUNDED PRECEDING)` |
| `vw_7day_moving_avg` | Smoothed daily sales trend (fills gap days with $0 via `dim_date`) | `AVG() OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)` |
| `vw_monthly_running_total` | Cumulative sales per category, month over month | `SUM() OVER (PARTITION BY category ORDER BY year_month)` |

Verified: running totals accumulate monotonically, the moving average window
ramps up correctly for the first 6 days then stabilizes, and the monthly
running total resets independently per category (144 rows = 3 categories ×
48 months).

## MoM / YoY growth views (for reference)

| View | Purpose | Key technique |
|---|---|---|
| `vw_mom_growth` | Month-over-month % growth, by category and by region | `LAG(monthly_sales) OVER (PARTITION BY dimension_type, dimension_value ORDER BY year_month)` |
| `vw_yoy_growth` | Year-over-year % growth (same month, prior year), by category and by region | `LAG(monthly_sales, 12) OVER (PARTITION BY dimension_type, dimension_value ORDER BY year_month)` |

Both views union a `by_category` and `by_region` CTE into one dashboard-ready
view with `dimension_type` / `dimension_value` columns, so a single view can
drive a "Category vs Region" filter instead of needing two separate views.

Verified: 336 rows in each view (3 categories + 4 regions × 48 months); the
first month for every dimension correctly shows `NULL` growth (no prior
period to compare); e.g. Furniture category, Jan 2023 vs Jan 2022 shows
+107.64% YoY growth.

## Ranking & Top-N views (for reference)

| View | Purpose | Key technique |
|---|---|---|
| `vw_top5_products_per_category` | Best-selling 5 products within each category | `ROW_NUMBER() OVER (PARTITION BY category ORDER BY total_sales DESC)` |
| `vw_customer_percentile_rank` | Each customer's spend rank & percentile, store-wide and within their segment | `RANK()` + `PERCENT_RANK() OVER (ORDER BY total_sales)` |

`vw_top5_products_per_category` uses `ROW_NUMBER` (not `RANK`) specifically so
every category returns exactly 5 rows even if two products tie on sales.
`vw_customer_percentile_rank` uses `RANK` (ties share a rank) for the plain
"#N of 220" display, and `PERCENT_RANK` (0.0-1.0) for percentile badges, both
store-wide and re-partitioned by segment.

Verified: every category returns exactly 5 products (15 rows total); the
top store-wide spender (Wei Lee, $292,188.87) correctly sits at percentile
1.0, and the lowest spender (Carlos Martin, $865.41) correctly sits at
percentile 0.0, across all 220 customers.