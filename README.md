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

## 5-Day Plan

| Day | Focus | Key deliverables |
|---|---|---|
| 1 | Project setup & data foundation | Folder structure, dataset, SQLite DB, schema, sanity checks |
| 2 | Running totals & moving averages | `vw_daily_sales_running_total`, `vw_7day_moving_avg`, `vw_monthly_running_total` |
| 3 | YoY / MoM growth with `LAG` | `vw_mom_growth`, `vw_yoy_growth` (per category & region) |
| 4 | Ranking & Top-N per category | `vw_top5_products_per_category`, `vw_customer_percentile_rank` |
| 5 | Gap-and-island purchase streaks | `vw_customer_purchase_streaks`, final view bundle + docs |

## Project structure
```
sales-funnel-timeseries-sql/
├── README.md
├── data/
│   ├── generate_data.py        # synthetic data generator
│   ├── raw/
│   │   └── superstore.csv      # generated dataset (16k+ rows)
│   └── processed/              # (reserved for later exports)
├── database/
│   └── superstore.db           # SQLite database (built by 03_load_data.py)
├── sql/
│   ├── 01_setup/
│   │   ├── 01_create_schema.sql
│   │   ├── 02_create_dim_date.sql
│   │   ├── 03_load_data.py     # builds DB + loads CSV + populates dim_date
│   │   └── 04_sanity_checks.sql
│   ├── 02_running_totals/      # Day 2
│   ├── 03_growth/              # Day 3
│   ├── 04_ranking/             # Day 4
│   └── 05_streaks/             # Day 5
├── docs/                       # ER diagram / notes (added as project grows)
└── outputs/                    # exported query results, screenshots, etc.
```

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
  and sporadic one-off buyers — needed for the Day 5 gap-and-island streak
  analysis to have real signal
- 3 categories / 13 sub-categories / 34 products, 4 regions

If you'd rather use the real Kaggle Superstore dataset, drop the CSV into
`data/raw/superstore.csv` with matching column names (or adjust the loader)
and re-run `sql/01_setup/03_load_data.py`.

## How to reproduce Day 1

```bash
cd sales-funnel-timeseries-sql
python3 data/generate_data.py          # regenerate data/raw/superstore.csv
python3 sql/01_setup/03_load_data.py   # rebuild database/superstore.db
```

Then run `sql/01_setup/04_sanity_checks.sql` against `database/superstore.db`
with any SQLite client (DB Browser for SQLite, `sqlite3` CLI, or Python's
`sqlite3` module) to confirm the load.

## Day 1 sanity-check results (for reference)

- 16,156 line items across 6,453 orders, 220 customers
- Date range: 2022-01-02 → 2025-12-27
- No NULLs in key columns
- Sales by category: Technology ≈ $13.3M, Furniture ≈ $10.4M, Office Supplies ≈ $1.4M
- Clear seasonality: Nov/Dec months run noticeably higher than the summer months
- Top loyal customers active in 44–47 of the 48 months — good streak material for Day 5
