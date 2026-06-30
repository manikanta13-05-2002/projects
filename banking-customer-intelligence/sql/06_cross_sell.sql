\pset pager off

-- ============================================================
-- CROSS-SELL OPPORTUNITIES
-- ============================================================
-- Finds customers who:
--   1. Do NOT currently have an active loan
--   2. Have a credit score above 650 (qualify for a loan)
--   3. Have an annual income above $30,000
--   4. Are Active (not churned or at risk)
--   5. Have been a customer for at least 6 months (established)
--
-- These are the highest-probability loan conversion targets.
-- A community bank relationship manager can approach these
-- customers directly with a pre-qualified offer.
-- ============================================================

WITH customer_activity AS (
    -- Get each customer's last transaction date
    SELECT
        customer_key,
        MAX(txn_date)   AS last_txn_date,
        COUNT(*)        AS total_transactions
    FROM analytics.fact_transaction
    GROUP BY customer_key
),

churn_status AS (
    -- Tag each customer's current status
    SELECT
        customer_key,
        CASE
            WHEN CURRENT_DATE - last_txn_date >= 90 THEN 'Churned'
            WHEN CURRENT_DATE - last_txn_date >= 60 THEN 'At Risk'
            WHEN CURRENT_DATE - last_txn_date >= 30 THEN 'Slipping'
            ELSE 'Active'
        END AS status
    FROM customer_activity
),

qualified_customers AS (
    SELECT
        c.customer_key,
        c.customer_id,
        c.customer_name,
        c.credit_score,
        c.credit_tier,
        c.annual_income,
        c.segment,
        c.account_created_date,
        c.has_active_loan,
        cs.status,
        -- How long have they been a customer in months
        (EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.account_created_date)) * 12
        + EXTRACT(MONTH FROM AGE(CURRENT_DATE, c.account_created_date)))
        ::INT                               AS tenure_months,
        -- Estimate monthly spend from transactions
        ROUND(ca.total_transactions::NUMERIC
              / GREATEST(
                  (EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.account_created_date)) * 12
                  + EXTRACT(MONTH FROM AGE(CURRENT_DATE, c.account_created_date))),
                  1
                ), 1)                       AS avg_monthly_transactions
    FROM analytics.dim_customer c
    JOIN customer_activity ca  USING (customer_key)
    JOIN churn_status cs       USING (customer_key)
)

SELECT
    customer_id,
    customer_name,
    credit_score,
    credit_tier,
    ROUND(annual_income::NUMERIC, 0)        AS annual_income,
    segment,
    tenure_months,
    avg_monthly_transactions,
    status,
    -- Assign a priority tier for the relationship manager
    CASE
        WHEN credit_score >= 750
         AND annual_income >= 75000         THEN 'Priority 1 — Pre-Approve Now'
        WHEN credit_score >= 700
         AND annual_income >= 50000         THEN 'Priority 2 — Strong Candidate'
        WHEN credit_score >= 650
         AND annual_income >= 30000         THEN 'Priority 3 — Standard Offer'
        ELSE                                     'Monitor'
    END                                     AS cross_sell_priority
FROM qualified_customers
WHERE has_active_loan = FALSE
  AND credit_score    >= 650
  AND annual_income   >= 30000
  AND status          = 'Active'
  AND tenure_months   >= 6
ORDER BY credit_score DESC, annual_income DESC;