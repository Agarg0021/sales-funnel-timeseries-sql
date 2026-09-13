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

