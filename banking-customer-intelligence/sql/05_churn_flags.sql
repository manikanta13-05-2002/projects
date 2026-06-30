\pset pager off

-- ============================================================
-- CHURN FLAGS
-- ============================================================
-- Definition: A customer is "at risk" if they have had
-- NO transactions in the last 60 days.
-- "Churned" = no transactions in the last 90 days.
--
-- Why these thresholds?
-- 60 days of silence at a primary bank account is unusual.
-- 90 days means they have almost certainly moved elsewhere.
-- A community bank can act on the 60-day signal personally
-- before the customer is fully gone.
-- ============================================================

WITH last_activity AS (
    SELECT
        customer_key,
        MAX(txn_date)                       AS last_txn_date,
        COUNT(*)                            AS total_transactions,
        SUM(ABS(amount))  FILTER
            (WHERE amount < 0)              AS total_spend,
        MIN(txn_date)                       AS first_txn_date
    FROM analytics.fact_transaction
    GROUP BY customer_key
),

churn_flags AS (
    SELECT
        customer_key,
        last_txn_date,
        first_txn_date,
        total_transactions,
        ROUND(total_spend::NUMERIC, 2)      AS total_spend,
        CURRENT_DATE - last_txn_date        AS days_since_last_txn,
        CASE
            WHEN CURRENT_DATE - last_txn_date >= 90 THEN 'Churned'
            WHEN CURRENT_DATE - last_txn_date >= 60 THEN 'At Risk'
            WHEN CURRENT_DATE - last_txn_date >= 30 THEN 'Slipping'
            ELSE 'Active'
        END                                 AS churn_status
    FROM last_activity
)

SELECT
    c.customer_id,
    c.customer_name,
    c.segment,
    c.credit_tier,
    c.annual_income,
    cf.last_txn_date,
    cf.days_since_last_txn,
    cf.total_transactions,
    cf.total_spend,
    cf.churn_status
FROM churn_flags cf
JOIN analytics.dim_customer c USING (customer_key)
ORDER BY cf.days_since_last_txn DESC;