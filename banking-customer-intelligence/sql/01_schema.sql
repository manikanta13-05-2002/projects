-- ============================================================
-- BANKING CUSTOMER INTELLIGENCE — STAR SCHEMA
-- Run this file in: psql -U postgres -d banking_dwh
-- ============================================================

-- ============================================================
-- DIMENSION: DATE
-- Why: Every fact table joins to this so you can slice by
-- year, month, quarter, day of week without doing date math
-- in every query.
-- ============================================================
CREATE TABLE analytics.dim_date (
    date_key        INT PRIMARY KEY,        -- format YYYYMMDD e.g. 20240115
    full_date       DATE NOT NULL,
    year            INT NOT NULL,
    quarter         INT NOT NULL,
    month           INT NOT NULL,
    month_name      VARCHAR(10) NOT NULL,
    week            INT NOT NULL,
    day_of_month    INT NOT NULL,
    day_of_week     INT NOT NULL,
    day_name        VARCHAR(10) NOT NULL,
    is_weekend      BOOLEAN NOT NULL
);

-- ============================================================
-- DIMENSION: CUSTOMER
-- Why: Central context table — every transaction links back
-- to a customer so we can slice by segment, credit tier etc.
-- ============================================================
CREATE TABLE analytics.dim_customer (
    customer_key            SERIAL PRIMARY KEY,
    customer_id             INT NOT NULL UNIQUE,  -- from your CSV
    account_number          VARCHAR(30),
    customer_name           VARCHAR(100),
    age                     INT,
    employment_status       VARCHAR(30),
    segment                 VARCHAR(30),          -- we derive this from income
    credit_score            INT,
    credit_tier             VARCHAR(20),
    annual_income           NUMERIC(12,2),
    has_active_loan         BOOLEAN,
    mortgage_balance        NUMERIC(12,2),
    overdraft_protection    BOOLEAN,
    is_online_banking       BOOLEAN,
    risk_score              NUMERIC(5,2),
    account_type            VARCHAR(30),
    account_created_date    DATE,
    current_balance         NUMERIC(12,2)
);

-- ============================================================
-- DIMENSION: TRANSACTION CATEGORY
-- Why: Lets you group and filter transactions by type
-- without storing the string repeatedly in the fact table.
-- ============================================================
CREATE TABLE analytics.dim_category (
    category_key    SERIAL PRIMARY KEY,
    category_name   VARCHAR(50) NOT NULL UNIQUE,
    category_group  VARCHAR(30)   -- e.g. 'Spending', 'Income', 'Transfer'
);

-- ============================================================
-- FACT: TRANSACTION
-- Why: The core event table. One row per transaction.
-- Grain = one bank transaction on one day for one customer.
-- All measures (amount) and foreign keys to dimensions live here.
-- ============================================================
CREATE TABLE analytics.fact_transaction (
    transaction_key     BIGSERIAL PRIMARY KEY,
    transaction_id      INT NOT NULL,
    date_key            INT REFERENCES analytics.dim_date(date_key),
    customer_key        INT REFERENCES analytics.dim_customer(customer_key),
    category_key        INT REFERENCES analytics.dim_category(category_key),
    amount              NUMERIC(12,2) NOT NULL,
    channel             VARCHAR(20),
    txn_date            DATE NOT NULL
);

-- ============================================================
-- INDEXES
-- Why: The fact table will have 1.4M rows. Without indexes,
-- every join scans the whole table. Indexes on foreign keys
-- make joins instant — this is how you get that query speed
-- improvement story (like your Accenture 25% reduction).
-- ============================================================
CREATE INDEX idx_fact_txn_date_key     ON analytics.fact_transaction(date_key);
CREATE INDEX idx_fact_txn_customer_key ON analytics.fact_transaction(customer_key);
CREATE INDEX idx_fact_txn_category_key ON analytics.fact_transaction(category_key);
CREATE INDEX idx_fact_txn_txn_date     ON analytics.fact_transaction(txn_date);