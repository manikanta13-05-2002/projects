\pset pager off
\pset tuples_only off

WITH spending AS (
    SELECT customer_key, MAX(txn_date) AS last_txn_date,
           COUNT(*) AS frequency, SUM(ABS(amount)) AS monetary
    FROM analytics.fact_transaction WHERE amount < 0
    GROUP BY customer_key
),
rfm_scores AS (
    SELECT customer_key,
           6 - NTILE(5) OVER (ORDER BY (CURRENT_DATE - last_txn_date) ASC) AS r_score,
           NTILE(5) OVER (ORDER BY frequency ASC)  AS f_score,
           NTILE(5) OVER (ORDER BY monetary ASC)   AS m_score
    FROM spending
),
labeled AS (
    SELECT
        CASE
            WHEN r_score + f_score + m_score >= 13 THEN 'Champions'
            WHEN r_score + f_score + m_score >= 10 THEN 'Loyal Customers'
            WHEN r_score + f_score + m_score >= 7  THEN 'Potential Loyalists'
            WHEN r_score >= 4 AND r_score + f_score + m_score < 7 THEN 'New Customers'
            WHEN r_score <= 2 AND r_score + f_score + m_score >= 7 THEN 'At Risk'
            WHEN r_score <= 2 AND r_score + f_score + m_score < 7  THEN 'Lost'
            ELSE 'Needs Attention'
        END AS rfm_segment
    FROM rfm_scores
)
SELECT
    rfm_segment,
    COUNT(*)                                            AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct
FROM labeled
GROUP BY rfm_segment
ORDER BY customers DESC;