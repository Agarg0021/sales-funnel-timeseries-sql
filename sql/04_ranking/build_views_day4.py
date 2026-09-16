"""
build_views_day4.py
--------------------
Creates/refreshes all Day 4 views (Top-N ranking & percentile) in
database/superstore.db.

Run from the project root:
    python3 sql/04_ranking/build_views_day4.py
"""

import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB_PATH = ROOT / "database" / "superstore.db"
VIEW_FILES = [
    "01_vw_top5_products_per_category.sql",
    "02_vw_customer_percentile_rank.sql",
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
    