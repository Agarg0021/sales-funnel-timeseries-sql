-- =============================================================================
-- 01_create_schema.sql
-- Project: Sales Funnel / Time-Series Analysis with Window Functions
-- Day 1: Core staging table for the Superstore-style dataset
-- =============================================================================

DROP TABLE IF EXISTS stg_orders;

CREATE TABLE stg_orders (
    row_id          INTEGER PRIMARY KEY,
    order_id        TEXT NOT NULL,
    order_date      DATE NOT NULL,
    ship_date       DATE,
    ship_mode       TEXT,
    customer_id     TEXT NOT NULL,
    customer_name   TEXT,
    segment         TEXT,
    region          TEXT,
    state           TEXT,
    city            TEXT,
    product_id      TEXT,
    product_name    TEXT,
    category        TEXT,
    sub_category    TEXT,
    sales           REAL,
    quantity        INTEGER,
    discount        REAL,
    profit          REAL
);

-- Indexes to keep the window-function queries (Days 2-5) fast:
-- most of them PARTITION BY category/customer and ORDER BY order_date.
CREATE INDEX idx_stg_orders_date        ON stg_orders(order_date);
CREATE INDEX idx_stg_orders_customer    ON stg_orders(customer_id, order_date);
CREATE INDEX idx_stg_orders_category    ON stg_orders(category, order_date);
CREATE INDEX idx_stg_orders_region      ON stg_orders(region, order_date);
