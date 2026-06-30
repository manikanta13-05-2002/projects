\pset pager off

WITH customer_cohorts AS (
    SELECT
        customer_key,
        DATE_TRUNC('month', MIN(txn_date))::DATE AS cohort_month
    FROM analytics.fact_transaction
    GROUP BY customer_key
),

-- Only count a customer as active if they had 3+ transactions that month
monthly_active AS (
    SELECT
        customer_key,
        DATE_TRUNC('month', txn_date)::DATE AS activity_month,
        COUNT(*) AS txn_count
    FROM analytics.fact_transaction
    GROUP BY customer_key, DATE_TRUNC('month', txn_date)::DATE
    HAVING COUNT(*) >= 3
),

cohort_activity AS (
    SELECT
        c.cohort_month,
        (EXTRACT(YEAR FROM a.activity_month) - EXTRACT(YEAR FROM c.cohort_month)) * 12
        + (EXTRACT(MONTH FROM a.activity_month) - EXTRACT(MONTH FROM c.cohort_month))
        AS months_since_join,
        COUNT(DISTINCT a.customer_key) AS active_customers
    FROM customer_cohorts c
    JOIN monthly_active a USING (customer_key)
    GROUP BY c.cohort_month, a.activity_month
),

cohort_sizes AS (
    SELECT cohort_month, COUNT(*) AS cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
)

SELECT
    ca.cohort_month,
    cs.cohort_size                                          AS total_customers,
    ca.months_since_join                                    AS month_number,
    ca.active_customers,
    ROUND(ca.active_customers * 100.0 / cs.cohort_size, 1) AS retention_pct
FROM cohort_activity ca
JOIN cohort_sizes cs USING (cohort_month)
WHERE ca.months_since_join BETWEEN 0 AND 12
  AND ca.cohort_month BETWEEN '2022-06-01' AND '2025-06-01'
ORDER BY ca.cohort_month, ca.months_since_join;