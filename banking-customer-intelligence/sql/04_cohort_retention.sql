\pset pager off

-- ============================================================
-- COHORT RETENTION ANALYSIS
-- ============================================================
-- Step 1: Assign each customer to their acquisition cohort
--         (the month they made their first transaction)
-- Step 2: For each subsequent month, check if they transacted
-- Step 3: Calculate retention % vs the cohort's starting size
-- ============================================================

WITH customer_cohorts AS (
    -- Find the first transaction month for each customer
    -- This is their cohort month
    SELECT
        customer_key,
        DATE_TRUNC('month', MIN(txn_date))::DATE AS cohort_month
    FROM analytics.fact_transaction
    GROUP BY customer_key
),

customer_activity AS (
    -- Find every month each customer was active
    SELECT DISTINCT
        customer_key,
        DATE_TRUNC('month', txn_date)::DATE AS activity_month
    FROM analytics.fact_transaction
),

cohort_activity AS (
    -- Join cohort month to activity months
    -- Calculate how many months after joining each activity month is
    SELECT
        c.cohort_month,
        a.activity_month,
        -- Month number since joining (0 = first month, 1 = second month etc)
        (EXTRACT(YEAR FROM a.activity_month) - EXTRACT(YEAR FROM c.cohort_month)) * 12
        + (EXTRACT(MONTH FROM a.activity_month) - EXTRACT(MONTH FROM c.cohort_month))
        AS months_since_join,
        COUNT(DISTINCT a.customer_key) AS active_customers
    FROM customer_cohorts c
    JOIN customer_activity a USING (customer_key)
    GROUP BY c.cohort_month, a.activity_month
),

cohort_sizes AS (
    -- How many customers joined in each cohort month
    SELECT cohort_month, COUNT(*) AS cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
)

SELECT
    ca.cohort_month,
    cs.cohort_size                          AS total_customers,
    ca.months_since_join                    AS month_number,
    ca.active_customers,
    -- Retention percentage
    ROUND(ca.active_customers * 100.0
          / cs.cohort_size, 1)              AS retention_pct
FROM cohort_activity ca
JOIN cohort_sizes cs USING (cohort_month)
WHERE ca.months_since_join BETWEEN 0 AND 12
  AND ca.cohort_month >= '2022-06-01'
  AND ca.cohort_month <= '2025-06-01'
ORDER BY ca.cohort_month, ca.months_since_join;