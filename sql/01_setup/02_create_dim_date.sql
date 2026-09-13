-- =============================================================================
-- 02_create_dim_date.sql
-- A simple calendar/date dimension. Not strictly required by SQLite's date
-- functions, but useful for dashboard tools (Tableau/Power BI/Metabase) that
-- expect a proper date dimension to join against, and makes MoM/YoY joins in
-- Day 3 more explicit and portable to Postgres/MySQL later.
-- =============================================================================

DROP TABLE IF EXISTS dim_date;

CREATE TABLE dim_date (
    date_key        DATE PRIMARY KEY,
    year            INTEGER,
    month           INTEGER,
    month_name      TEXT,
    year_month      TEXT,   -- 'YYYY-MM', handy for MoM grouping
    quarter         INTEGER,
    day_of_month    INTEGER,
    day_of_week     INTEGER  -- 0=Sunday ... 6=Saturday (SQLite convention)
);

-- Populated in 03_load_data.py using a Python date-range loop (simplest,
-- most portable way to seed a calendar table in SQLite, which has no
-- native generate_series).
