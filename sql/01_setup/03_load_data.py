"""
03_load_data.py
----------------
Day 1 loader:
  1. (Re)creates the SQLite database
  2. Runs 01_create_schema.sql and 02_create_dim_date.sql
  3. Loads data/raw/superstore.csv into stg_orders
  4. Populates dim_date for the full date range in the data

Run from the project root:
    python3 sql/01_setup/03_load_data.py
"""

import csv
import sqlite3
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB_PATH = ROOT / "database" / "superstore.db"
CSV_PATH = ROOT / "data" / "raw" / "superstore.csv"
SCHEMA_SQL = ROOT / "sql" / "01_setup" / "01_create_schema.sql"
DIM_DATE_SQL = ROOT / "sql" / "01_setup" / "02_create_dim_date.sql"

MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July",
               "August", "September", "October", "November", "December"]


def run_sql_file(conn, path: Path):
    with open(path, "r", encoding="utf-8") as f:
        conn.executescript(f.read())


def load_orders(conn):
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        rows = [
            (
                int(r["row_id"]), r["order_id"], r["order_date"], r["ship_date"],
                r["ship_mode"], r["customer_id"], r["customer_name"], r["segment"],
                r["region"], r["state"], r["city"], r["product_id"], r["product_name"],
                r["category"], r["sub_category"], float(r["sales"]), int(r["quantity"]),
                float(r["discount"]), float(r["profit"]),
            )
            for r in reader
        ]

    conn.executemany(
        """INSERT INTO stg_orders
           (row_id, order_id, order_date, ship_date, ship_mode, customer_id,
            customer_name, segment, region, state, city, product_id, product_name,
            category, sub_category, sales, quantity, discount, profit)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        rows,
    )
    conn.commit()
    return len(rows)


def populate_dim_date(conn):
    cur = conn.execute("SELECT MIN(order_date), MAX(order_date) FROM stg_orders")
    min_d, max_d = cur.fetchone()
    start = date.fromisoformat(min_d)
    end = date.fromisoformat(max_d)

    rows = []
    d = start
    while d <= end:
        rows.append((
            d.isoformat(), d.year, d.month, MONTH_NAMES[d.month - 1],
            f"{d.year:04d}-{d.month:02d}", (d.month - 1) // 3 + 1,
            d.day, (d.weekday() + 1) % 7,  # convert Mon=0..Sun=6 -> Sun=0..Sat=6
        ))
        d += timedelta(days=1)

    conn.executemany(
        """INSERT INTO dim_date
           (date_key, year, month, month_name, year_month, quarter, day_of_month, day_of_week)
           VALUES (?,?,?,?,?,?,?,?)""",
        rows,
    )
    conn.commit()
    return len(rows)


def main():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    if DB_PATH.exists():
        DB_PATH.unlink()

    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = ON;")

    run_sql_file(conn, SCHEMA_SQL)
    run_sql_file(conn, DIM_DATE_SQL)

    n_orders = load_orders(conn)
    n_dates = populate_dim_date(conn)

    print(f"Loaded {n_orders} rows into stg_orders")
    print(f"Populated {n_dates} rows into dim_date")
    print(f"Database written to: {DB_PATH}")

    conn.close()


if __name__ == "__main__":
    main()
