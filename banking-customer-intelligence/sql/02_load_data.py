"""
02_load_data.py
===============
Loads CSV data into the banking_dwh analytics star schema.

Order matters:
  1. dim_date      (no dependencies)
  2. dim_category  (no dependencies)
  3. dim_customer  (no dependencies)
  4. fact_transaction (depends on all three dimensions above)

Usage
-----
    python sql/02_load_data.py
"""

import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
from datetime import date, timedelta

# ── Connection ──────────────────────────────────────────────
conn = psycopg2.connect(
    host="localhost",
    port=5432,
    database="banking_dwh",
    user="postgres",
    password="admin123"
)
cur = conn.cursor()
print("Connected to banking_dwh")

# ── 1. dim_date ─────────────────────────────────────────────
# Generate every date from 2022-01-01 to 2026-12-31
print("Loading dim_date...")
start = date(2022, 1, 1)
end   = date(2026, 12, 31)
dates = []
d = start
while d <= end:
    dates.append((
        int(d.strftime("%Y%m%d")),   # date_key e.g. 20240115
        d,                            # full_date
        d.year,                       # year
        (d.month - 1) // 3 + 1,      # quarter
        d.month,                      # month
        d.strftime("%B"),             # month_name
        int(d.strftime("%W")),        # week
        d.day,                        # day_of_month
        d.isoweekday(),               # day_of_week (1=Mon, 7=Sun)
        d.strftime("%A"),             # day_name
        d.isoweekday() >= 6           # is_weekend
    ))
    d += timedelta(days=1)

execute_values(cur, """
    INSERT INTO analytics.dim_date
        (date_key, full_date, year, quarter, month, month_name,
         week, day_of_month, day_of_week, day_name, is_weekend)
    VALUES %s
    ON CONFLICT (date_key) DO NOTHING
""", dates)
print(f"  Inserted {len(dates):,} date rows")

# ── 2. dim_category ─────────────────────────────────────────
print("Loading dim_category...")
categories = [
    ("Groceries",       "Spending"),
    ("Dining",          "Spending"),
    ("Utilities",       "Spending"),
    ("Travel",          "Spending"),
    ("Healthcare",      "Spending"),
    ("Entertainment",   "Spending"),
    ("Transfer",        "Transfer"),
    ("ATM Withdrawal",  "Transfer"),
    ("Payroll",         "Income"),
    ("Fees",            "Spending"),
]
execute_values(cur, """
    INSERT INTO analytics.dim_category (category_name, category_group)
    VALUES %s
    ON CONFLICT (category_name) DO NOTHING
""", categories)
print(f"  Inserted {len(categories)} category rows")

# ── 3. dim_customer ─────────────────────────────────────────
print("Loading dim_customer...")
customers = pd.read_csv("data/raw/customers.csv", parse_dates=["Account_Created_Date"])

# Derive a simple income-based segment since our CSV has raw income
def segment(income):
    if income < 30000:   return "Mass Market"
    if income < 75000:   return "Mass Affluent"
    if income < 150000:  return "Affluent"
    return "High Net Worth"

customer_rows = []
for _, r in customers.iterrows():
    customer_rows.append((
        int(r["Customer_ID"]),
        str(r["Account_Number"]),
        str(r["Customer_Name"]),
        int(r["Age"]) if pd.notna(r["Age"]) else None,
        str(r["Employment_Status"]) if pd.notna(r.get("Employment_Status","")) else None,
        segment(float(r["Annual_Income"])),
        int(r["Credit_Score"]) if pd.notna(r["Credit_Score"]) else None,
        str(r["Credit_Tier"]) if pd.notna(r.get("Credit_Tier","")) else None,
        float(r["Annual_Income"]) if pd.notna(r["Annual_Income"]) else None,
        bool(r["Has_Active_Loan"]) if pd.notna(r.get("Has_Active_Loan","")) else None,
        float(r["Mortgage_Balance"]) if pd.notna(r.get("Mortgage_Balance",0)) else 0,
        bool(r["Overdraft_Protection"]) if pd.notna(r.get("Overdraft_Protection","")) else None,
        bool(r["Is_Online_Banking_Active"]) if pd.notna(r.get("Is_Online_Banking_Active","")) else None,
        float(r["Risk_Score"]) if pd.notna(r.get("Risk_Score",0)) else None,
        str(r["Account_Type"]) if pd.notna(r.get("Account_Type","")) else None,
        r["Account_Created_Date"].date() if pd.notna(r["Account_Created_Date"]) else None,
        float(r["Current_Balance"]) if pd.notna(r.get("Current_Balance",0)) else None,
    ))

execute_values(cur, """
    INSERT INTO analytics.dim_customer
        (customer_id, account_number, customer_name, age, employment_status,
         segment, credit_score, credit_tier, annual_income, has_active_loan,
         mortgage_balance, overdraft_protection, is_online_banking,
         risk_score, account_type, account_created_date, current_balance)
    VALUES %s
    ON CONFLICT (customer_id) DO NOTHING
""", customer_rows)
print(f"  Inserted {len(customer_rows):,} customer rows")

# ── 4. fact_transaction ─────────────────────────────────────
print("Loading fact_transaction (1.4M rows — takes ~30 seconds)...")
txns = pd.read_csv("data/raw/transactions.csv", parse_dates=["txn_date"])

# Build lookup dictionaries so we can swap natural keys for surrogate keys
cur.execute("SELECT customer_id, customer_key FROM analytics.dim_customer")
cust_map = {row[0]: row[1] for row in cur.fetchall()}

cur.execute("SELECT category_name, category_key FROM analytics.dim_category")
cat_map = {row[0]: row[1] for row in cur.fetchall()}

fact_rows = []
skipped = 0
for _, r in txns.iterrows():
    ckey = cust_map.get(int(r["customer_id"]))
    catkey = cat_map.get(str(r["category"]))
    date_key = int(r["txn_date"].strftime("%Y%m%d"))
    if ckey is None or catkey is None:
        skipped += 1
        continue
    fact_rows.append((
        int(r["transaction_id"]),
        date_key,
        ckey,
        catkey,
        float(r["amount"]),
        str(r["channel"]),
        r["txn_date"].date(),
    ))

# Insert in batches of 10,000 for speed
batch_size = 10_000
for i in range(0, len(fact_rows), batch_size):
    execute_values(cur, """
        INSERT INTO analytics.fact_transaction
            (transaction_id, date_key, customer_key, category_key,
             amount, channel, txn_date)
        VALUES %s
        ON CONFLICT DO NOTHING
    """, fact_rows[i:i+batch_size])
    if i % 100_000 == 0 and i > 0:
        print(f"  ...{i:,} rows inserted")

conn.commit()
print(f"  Inserted {len(fact_rows):,} transaction rows ({skipped} skipped)")
print("\nAll done. Your star schema is loaded.")
cur.close()
conn.close()