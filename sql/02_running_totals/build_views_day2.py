"""
build_views_day2.py
--------------------
Creates/refreshes all Day 2 views (running totals & moving averages) in
database/superstore.db.

Run from the project root:
    python3 sql/02_running_totals/build_views_day2.py
"""

import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB_PATH = ROOT / "database" / "superstore.db"
VIEW_FILES = [
    "01_vw_daily_sales_running_total.sql",
    "02_vw_7day_moving_avg.sql",
    "03_vw_monthly_running_total.sql",
]


def main():
    conn = sqlite3.connect(DB_PATH)
    for fname in VIEW_FILES:
        path = Path(__file__).resolve().parent / fname
        conn.executescript(path.read_text())
        print(f"Built view from {fname}")
    conn.commit()

    views = [r[0] for r in conn.execute(
        "SELECT name FROM sqlite_master WHERE type='view' ORDER BY name"
    ).fetchall()]
    print("\nViews now in database:", views)
    conn.close()


if __name__ == "__main__":
    main()
