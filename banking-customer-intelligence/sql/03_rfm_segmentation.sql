-- ============================================================
-- RFM SEGMENTATION
-- ============================================================
-- RFM stands for Recency, Frequency, Monetary.
-- It scores every customer on three dimensions:
--   R = how recently did they transact? (higher = more recent = better)
--   F = how many transactions did they make? (higher = more engaged)
--   M = how much did they spend in total? (higher = more valuable)
--
-- We use NTILE(5) to split customers into 5 equal buckets
-- on each dimension (5 = best, 1 = worst).
-- Combined score → segment label a business can act on.
-- ============================================================

WITH spending AS (
    -- Only count spending (negative amounts) not income/payroll
    SELECT
        customer_key,
        MAX(txn_date)                   AS last_txn_date,
        COUNT(*)                        AS frequency,
        SUM(ABS(amount))                AS monetary
    FROM analytics.fact_transaction
    WHERE amount < 0
    GROUP BY customer_key
),

recency AS (
    SELECT
        customer_key,
        last_txn_date,
        frequency,
        monetary,
        -- Days since last transaction (lower days = more recent = better)
        CURRENT_DATE - last_txn_date    AS days_since_last_txn
    FROM spending
),

rfm_scores AS (
    SELECT
        customer_key,
        last_txn_date,
        days_since_last_txn,
        frequency,
        ROUND(monetary, 2)              AS monetary,
        -- NTILE(5) splits into 5 equal buckets
        -- Recency: fewer days = better = higher score, so we reverse it
        6 - NTILE(5) OVER (ORDER BY days_since_last_txn ASC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)                 AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)                  AS m_score
    FROM recency
),

rfm_combined AS (
    SELECT
        *,
        r_score + f_score + m_score     AS rfm_total
    FROM rfm_scores
)

SELECT
    c.customer_id,
    c.customer_name,
    c.segment,
    c.credit_tier,
    r.last_txn_date,
    r.days_since_last_txn,
    r.frequency,
    r.monetary,
    r.r_score,
    r.f_score,
    r.m_score,
    r.rfm_total,
    -- Translate score into a business-friendly label
    CASE
        WHEN r.rfm_total >= 13 THEN 'Champions'
        WHEN r.rfm_total >= 10 THEN 'Loyal Customers'
        WHEN r.rfm_total >= 7  THEN 'Potential Loyalists'
        WHEN r.r_score >= 4
         AND r.rfm_total < 7   THEN 'New Customers'
        WHEN r.r_score <= 2
         AND r.rfm_total >= 7  THEN 'At Risk'
        WHEN r.r_score <= 2
         AND r.rfm_total < 7   THEN 'Lost'
        ELSE                        'Needs Attention'
    END                             AS rfm_segment
FROM rfm_combined r
JOIN analytics.dim_customer c USING (customer_key)
ORDER BY r.rfm_total DESC;