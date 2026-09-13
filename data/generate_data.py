"""
generate_data.py
-----------------
Generates a synthetic Superstore-style retail dataset for the
Sales Funnel / Time-Series SQL Window Functions project.

Why synthetic: no network access in this environment to pull the real
Kaggle "Sample Superstore" file, so we build one with the same schema
and realistic patterns:
  - 4 years of daily order activity (seasonality: Nov/Dec spike, summer dip)
  - Repeat customers with real consecutive-month purchase streaks
    (needed later for the gap-and-island streak analysis)
  - Category/Sub-Category/Region structure matching the real Superstore schema
  - Sales, Quantity, Discount, Profit with realistic relationships

Output: data/raw/superstore.csv
"""

import csv
import random
from datetime import date, timedelta

random.seed(42)

# ---------------------------------------------------------------------------
# Reference data
# ---------------------------------------------------------------------------
REGIONS = ["East", "West", "Central", "South"]

STATES_BY_REGION = {
    "East": ["New York", "Pennsylvania", "New Jersey", "Massachusetts", "Virginia"],
    "West": ["California", "Washington", "Oregon", "Nevada", "Arizona"],
    "Central": ["Texas", "Illinois", "Ohio", "Michigan", "Wisconsin"],
    "South": ["Florida", "Georgia", "North Carolina", "Tennessee", "Alabama"],
}

CITIES_BY_STATE = {
    "New York": ["New York City", "Buffalo", "Albany"],
    "Pennsylvania": ["Philadelphia", "Pittsburgh"],
    "New Jersey": ["Newark", "Jersey City"],
    "Massachusetts": ["Boston", "Worcester"],
    "Virginia": ["Richmond", "Norfolk"],
    "California": ["Los Angeles", "San Francisco", "San Diego"],
    "Washington": ["Seattle", "Spokane"],
    "Oregon": ["Portland", "Eugene"],
    "Nevada": ["Las Vegas", "Reno"],
    "Arizona": ["Phoenix", "Tucson"],
    "Texas": ["Houston", "Dallas", "Austin"],
    "Illinois": ["Chicago", "Springfield"],
    "Ohio": ["Columbus", "Cleveland"],
    "Michigan": ["Detroit", "Ann Arbor"],
    "Wisconsin": ["Milwaukee", "Madison"],
    "Florida": ["Miami", "Orlando", "Tampa"],
    "Georgia": ["Atlanta", "Savannah"],
    "North Carolina": ["Charlotte", "Raleigh"],
    "Tennessee": ["Nashville", "Memphis"],
    "Alabama": ["Birmingham", "Montgomery"],
}

CATEGORY_TREE = {
    "Furniture": ["Chairs", "Tables", "Bookcases", "Furnishings"],
    "Office Supplies": ["Binders", "Paper", "Storage", "Art", "Labels"],
    "Technology": ["Phones", "Machines", "Accessories", "Copiers"],
}

PRODUCT_NAME_PARTS = {
    "Chairs": ["Executive Chair", "Mesh Task Chair", "Stacking Chair", "Recliner"],
    "Tables": ["Conference Table", "Round Table", "Standing Desk", "Side Table"],
    "Bookcases": ["5-Shelf Bookcase", "Corner Bookcase", "Ladder Shelf"],
    "Furnishings": ["Desk Lamp", "Wall Clock", "Filing Tray"],
    "Binders": ["3-Ring Binder", "Report Cover", "View Binder"],
    "Paper": ["Copy Paper Ream", "Legal Pad", "Sticky Notes"],
    "Storage": ["File Cabinet", "Storage Box", "Locking Drawer"],
    "Art": ["Marker Set", "Sketch Pad", "Push Pins"],
    "Labels": ["Address Labels", "Shipping Labels"],
    "Phones": ["Smartphone X", "Cordless Phone", "Headset Pro"],
    "Machines": ["Laser Printer", "Label Maker", "Shredder"],
    "Accessories": ["Wireless Mouse", "USB Hub", "Laptop Stand"],
    "Copiers": ["Desktop Copier", "Office Copier XL"],
}

SEGMENTS = ["Consumer", "Corporate", "Home Office"]
SHIP_MODES = ["Standard Class", "Second Class", "First Class", "Same Day"]

FIRST_NAMES = ["James", "Mary", "Robert", "Patricia", "John", "Jennifer", "Michael",
               "Linda", "David", "Elizabeth", "William", "Barbara", "Richard", "Susan",
               "Joseph", "Jessica", "Thomas", "Sarah", "Charles", "Karen", "Priya",
               "Amit", "Wei", "Yuki", "Carlos", "Sofia", "Ahmed", "Fatima"]
LAST_NAMES = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller",
              "Davis", "Rodriguez", "Martinez", "Wilson", "Anderson", "Taylor",
              "Thomas", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson"]

# ---------------------------------------------------------------------------
# Build a customer pool. Some customers are "loyal repeaters" (buy most months
# for a stretch -> creates real streaks). Others are one-off / sporadic buyers.
# ---------------------------------------------------------------------------
NUM_CUSTOMERS = 220
customers = []
for i in range(NUM_CUSTOMERS):
    fname = random.choice(FIRST_NAMES)
    lname = random.choice(LAST_NAMES)
    region = random.choice(REGIONS)
    state = random.choice(STATES_BY_REGION[region])
    city = random.choice(CITIES_BY_STATE[state])
    customers.append({
        "customer_id": f"CU-{10000+i}",
        "customer_name": f"{fname} {lname}",
        "segment": random.choice(SEGMENTS),
        "region": region,
        "state": state,
        "city": city,
        # loyalty_score drives how often / how consecutively they order
        "loyalty_score": random.random(),
    })

# Build product catalog
products = []
pid = 1
for category, subcats in CATEGORY_TREE.items():
    for subcat in subcats:
        for name in PRODUCT_NAME_PARTS[subcat]:
            base_price = {
                "Furniture": random.uniform(80, 900),
                "Office Supplies": random.uniform(3, 120),
                "Technology": random.uniform(30, 1500),
            }[category]
            products.append({
                "product_id": f"PR-{1000+pid}",
                "product_name": name,
                "category": category,
                "sub_category": subcat,
                "base_price": round(base_price, 2),
            })
            pid += 1

# ---------------------------------------------------------------------------
# Seasonality weight by month (retail-like: Nov/Dec spike, summer dip)
# ---------------------------------------------------------------------------
MONTH_WEIGHT = {1: 0.8, 2: 0.75, 3: 0.9, 4: 0.95, 5: 1.0, 6: 0.9,
                7: 0.85, 8: 0.9, 9: 1.0, 10: 1.15, 11: 1.5, 12: 1.7}

START_DATE = date(2022, 1, 1)
END_DATE = date(2025, 12, 31)

rows = []
order_row_id = 1
order_counter = 1

# For each customer, decide which months they're "active" in, biasing
# toward consecutive runs for higher loyalty_score customers.
all_months = []
d = date(START_DATE.year, START_DATE.month, 1)
while d <= END_DATE:
    all_months.append(d)
    # advance one month
    if d.month == 12:
        d = date(d.year + 1, 1, 1)
    else:
        d = date(d.year, d.month + 1, 1)

for cust in customers:
    loyalty = cust["loyalty_score"]
    active_months = []
    streak_mode = loyalty > 0.55  # loyal customers buy in consecutive-month runs
    i = 0
    while i < len(all_months):
        if streak_mode and random.random() < (0.15 + loyalty * 0.3):
            run_len = random.randint(3, 10)
            for j in range(i, min(i + run_len, len(all_months))):
                active_months.append(all_months[j])
            i += run_len
        else:
            if random.random() < (0.08 + loyalty * 0.15):
                active_months.append(all_months[i])
            i += 1

    for month_start in active_months:
        # 1-3 orders in an active month
        num_orders = random.choices([1, 2, 3], weights=[0.7, 0.25, 0.05])[0]
        for _ in range(num_orders):
            day = random.randint(1, 27)
            order_date = date(month_start.year, month_start.month, day)
            ship_delay = random.randint(1, 7)
            ship_date = order_date + timedelta(days=ship_delay)
            order_id = f"ORD-{order_date.year}-{order_counter}"
            order_counter += 1

            num_line_items = random.randint(1, 4)
            for _ in range(num_line_items):
                product = random.choice(products)
                weight = MONTH_WEIGHT[order_date.month]
                quantity = random.randint(1, 6)
                discount = random.choice([0, 0, 0, 0.1, 0.15, 0.2, 0.3, 0.4])
                unit_price = product["base_price"]
                sales = round(unit_price * quantity * weight * (1 - discount * 0.3), 2)
                margin_rate = random.uniform(-0.05, 0.35)
                profit = round(sales * margin_rate, 2)

                rows.append({
                    "row_id": order_row_id,
                    "order_id": order_id,
                    "order_date": order_date.isoformat(),
                    "ship_date": ship_date.isoformat(),
                    "ship_mode": random.choice(SHIP_MODES),
                    "customer_id": cust["customer_id"],
                    "customer_name": cust["customer_name"],
                    "segment": cust["segment"],
                    "region": cust["region"],
                    "state": cust["state"],
                    "city": cust["city"],
                    "product_id": product["product_id"],
                    "product_name": product["product_name"],
                    "category": product["category"],
                    "sub_category": product["sub_category"],
                    "sales": sales,
                    "quantity": quantity,
                    "discount": discount,
                    "profit": profit,
                })
                order_row_id += 1

# Sort by order_date for a natural, readable CSV
rows.sort(key=lambda r: (r["order_date"], r["order_id"], r["row_id"]))
for idx, r in enumerate(rows, start=1):
    r["row_id"] = idx

OUT_PATH = "/home/claude/sales-funnel-timeseries-sql/data/raw/superstore.csv"
fieldnames = ["row_id", "order_id", "order_date", "ship_date", "ship_mode",
              "customer_id", "customer_name", "segment", "region", "state", "city",
              "product_id", "product_name", "category", "sub_category",
              "sales", "quantity", "discount", "profit"]

with open(OUT_PATH, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

print(f"Generated {len(rows)} rows across {order_counter-1} orders "
      f"for {NUM_CUSTOMERS} customers -> {OUT_PATH}")
