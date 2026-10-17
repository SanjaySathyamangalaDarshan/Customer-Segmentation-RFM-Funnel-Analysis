-- ===========================================================================================================
-- Translating granular R, F, M scores and wholesaler flags into actionable, human-readable customer personas.
-- ===========================================================================================================

DROP TABLE IF EXISTS rfm_segments CASCADE;--(CASCADE removes table and also remove relationships, views etc)

CREATE TABLE rfm_segments AS
SELECT 
    user_id,
    recency_days,
    frequency,
    monetary,
    customer_segment_type,
    r_score,
    f_score,
    m_score,
    rfm_cell,
    CASE 
        -- 1. Wholesalers (Isolated via outlier rules)
        WHEN customer_segment_type = 'Wholesaler' THEN 'Wholesale Key Accounts'
        
        -- 2. High Recency, Frequency, and Monetary are marked as champions
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        
        -- 3. Good past engagement and spend users are marked as Loyal Customers
        WHEN f_score >= 3 AND m_score >= 3 AND r_score >= 3 THEN 'Loyal Customers'

        --4. Potential Loyalists (R>=4, F<=3) mixes first time buyers with repeated buyers, has our 68% of buyers has F = 1 adding New Customer is needed
        WHEN r_score >= 4 AND f_score = 1 THEN 'New Customers'
        
        -- 4. Recent buyers with moderate frequency are flagged as Potential Loyalists
        WHEN r_score >= 4 AND f_score <= 3 THEN 'Potential Loyalists'

        -- 5. High spenders/frequent buyers who haven't visited recently we cannot be loosing them
        WHEN r_score <= 1 AND f_score >= 4 AND m_score >= 4 THEN 'Cannot Lose Them'
        
        -- 6. Used to spend/buy often, but long time since last purchase are placed at risk so that they are handeled carefully
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'At Risk'
        
        -- 7. Low recency, low frequency users are given with a tag of Hibernating
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
        
        -- 8. Default fallback for remaining medium/low segments
        ELSE 'General Customers'
    END AS customer_segment
FROM rfm_scores;

-- Mandatory Indexing for optimizing the query
CREATE INDEX idx_rfm_segments_persona ON rfm_segments(customer_segment);
CREATE INDEX idx_rfm_segments_user ON rfm_segments(user_id);

-- Quick validation check to Inspect customer distribution across segments
SELECT 
    customer_segment,
    COUNT(DISTINCT user_id) AS customer_count,
    ROUND(COUNT(DISTINCT user_id) * 100.0 / SUM(COUNT(DISTINCT user_id)) OVER(), 2) AS pct_of_total_customers,
    ROUND(SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER (), 1) AS pct_revenue,
    ROUND(SUM(monetary), 2) AS total_segment_revenue,
    ROUND(AVG(monetary), 2) AS avg_customer_spend
FROM rfm_segments
GROUP BY customer_segment
ORDER BY total_segment_revenue DESC;
-- Results: segment / buyers / % of buyers / % of revenue / avg spend
--   Hibernating            / 156,045 / 44.95 / 23.8 /    351
--   Champions              /  13,955 /  4.02 / 20.9 /  3,445
--   Loyal Customers        /  20,491 /  5.90 / 15.0 /  1,685
--   General Customers      /  74,039 / 21.33 / 12.0 /    374
--   At Risk                /  11,087 /  3.19 /  7.9 /  1,631
--   New Customers          /  50,793 / 14.63 /  6.8 /    307
--   Wholesale Key Accounts /     348 /  0.10 /  6.3 / 41,920
--   Potential Loyalists    /  18,584 /  5.35 /  5.1 /    635
--   Cannot Lose Them       /   1,776 /  0.51 /  2.1 /  2,675

-- KEY FINDINGS:
-- 1. The biggest segment is not the best place to spend retention budget.
--    1.1 Hibernating (R <= 2, F <= 2) is the largest segment: 45% of buyers,
--        23.8% of revenue. But it means 1-2 purchases, with the last one at
--        least 15 days before the end of the data. Because the data covers
--        only one month, early-month buyers may simply not have bought again
--        yet. This is a window artifact, not proof of lost customers.
--    1.2 At Risk and Cannot Lose Them (3+ purchase sessions, high spend, gone
--        quiet) are a stronger warning sign. Avg spend per buyer: Hibernating
--        351 vs At Risk 1,631 vs Cannot Lose Them 2,675.
-- 2. With a limited budget, return per contact matters. Hibernating would
--    mean contacting 156,045 buyers; At Risk + Cannot Lose Them is 12,863
--    buyers holding 9.9% of revenue.
-- NOTE: This is a hypothesis to test with the funnel analysis. Cost per
-- contact is assumed equal across segments (no cost data in the dataset).
