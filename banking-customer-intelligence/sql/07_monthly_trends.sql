\pset pager off

-- ============================================================
-- MONTHLY SPENDING TRENDS
-- ============================================================
-- Shows the bank's overall transaction volume and spending
-- trends month by month. Useful for spotting seasonal patterns,
-- growth trends, and months where activity dropped off.
-- ============================================================

SELECT
    DATE_TRUNC('month', txn_date)::DATE     AS month,
    COUNT(*)                                AS total_transactions,
    COUNT(DISTINCT customer_key)            AS active_customers,
    ROUND(SUM(ABS(amount))
          FILTER (WHERE amount < 0), 2)     AS total_spend,
    ROUND(AVG(ABS(amount))
          FILTER (WHERE amount < 0), 2)     AS avg_transaction_size,
    ROUND(SUM(amount)
          FILTER (WHERE amount > 0), 2)     AS total_income_received,
    COUNT(*) FILTER (WHERE amount < 0)      AS spending_transactions,
    COUNT(*) FILTER (WHERE amount > 0)      AS income_transactions
FROM analytics.fact_transaction
GROUP BY DATE_TRUNC('month', txn_date)
ORDER BY month;