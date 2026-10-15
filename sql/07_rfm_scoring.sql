-- ====================================================================
-- Day 7: Advanced RFM Scoring with Wholesale Outlier Isolation
-- ====================================================================
-- Points to Note before moving further
-- 1. Earlier with grouping users we got raw number or RFM score for each user whcih cannot be used for perfect ranking.
-- 2. So i created a new file name rfm scoring where I converted these raw numbers to score so that they can be easily flagged.
-- 3. Later what I found was based on the rfm base table most of the users have high spending like 118K to 265k in a month
--    which I believed could probably be a wholesaler or a B2B platform and rest users have few hundreds of spending.
--    Without flagging these top buyers segment totals and charts will be skewed
-- 4. So I used PERCENTILE_CONT() to flag those high buyers Instead of removing them as we did earlier to flag bots.


DROP TABLE IF EXISTS rfm_scores;

CREATE TABLE rfm_scores AS
WITH outlier_thresholds AS (
    -- Isolated wholesalers/ B2B like buyers with bulk order
    SELECT PERCENTILE_CONT(0.999) WITHIN GROUP (ORDER BY monetary) AS p999_monetary
    FROM rfm_base
),
flagged_base AS (
    SELECT
        b.*,
        CASE WHEN b.monetary >= t.p999_monetary THEN 'Wholesaler'
             ELSE 'Retail' END AS customer_segment_type
    FROM rfm_base b
    CROSS JOIN outlier_thresholds t
),
scored AS (
    SELECT
        user_id, recency_days, frequency, monetary, customer_segment_type,

        -- Used case when Instead of Ntile he problem is ties, Recency only takes 31 values (1 to 31 days), and many buyers share each day.
	    --	NTILE would again split people with the same recency into different scores.
	    --	Fixed bands also have a business meaning: "bought in the last 3 days" is easy to explain, while "the top 20% by recency" shifts with the data.
        CASE WHEN recency_days <= 3  THEN 5
             WHEN recency_days <= 7  THEN 4
             WHEN recency_days <= 14 THEN 3
             WHEN recency_days <= 21 THEN 2
             ELSE 1 END AS r_score,

        -- 67.8% of buyers have Frequency = 1, NTILE(5) must cut buyers into five equal groups of 20% each. 
        -- Since 68% of people have the same value, it would split identical buyers across scores 1, 2, 3, and 4 purely by sort order.
	    -- Two buyers who each bought once could get different F scores. That is meaningless.
        CASE WHEN frequency = 1  THEN 1
             WHEN frequency = 2  THEN 2
             WHEN frequency = 3  THEN 3
             WHEN frequency <= 5 THEN 4
             ELSE 5 END AS f_score,

        -- Monetary: quintiles within each customer type, low spend = 1, we used NTILE because few buyers share same price
        NTILE(5) OVER (PARTITION BY customer_segment_type
                       ORDER BY monetary ASC, user_id) AS m_ntile
    FROM flagged_base
)
SELECT
    user_id, recency_days, frequency, monetary, customer_segment_type,
    r_score,
    f_score,
    -- Here Case When is used so that Wholesalers get score 5 And rest others the same score
    CASE WHEN customer_segment_type = 'Wholesaler' THEN 5
         ELSE m_ntile END AS m_score,
    -- I Used this so that rfm cell is combination of three scores instead of 5-1-4 we get 514
    CASE WHEN customer_segment_type = 'Wholesaler' THEN 'Wholesale'
         ELSE CAST(r_score AS VARCHAR) || CAST(f_score AS VARCHAR)
              || CAST(m_ntile AS VARCHAR) END AS rfm_cell
FROM scored;

CREATE INDEX idx_rfm_scores_cell ON rfm_scores(rfm_cell);
CREATE INDEX idx_rfm_scores_segment ON rfm_scores(customer_segment_type);

-- Certain mandatory checks
SELECT COUNT(*) FROM rfm_scores;
-- Result : Row Count: 347,118

-- 2. Wholesalers vs retail
SELECT customer_segment_type, COUNT(*) AS buyers, ROUND(SUM(monetary)) AS revenue
FROM rfm_scores GROUP BY 1;
-- Results: customer segment / Count / revenue
--          Retail / 346770 / 215344945
--          Wholesaler / 348 / 14588268

-- 3. Direction check: R = 5 should have the smallest day values
SELECT r_score, MIN(recency_days), MAX(recency_days), COUNT(*)
FROM rfm_scores GROUP BY 1 ORDER BY 1;
-- Results: r_score / min / max / count
--          1 / 22 / 31 / 86510
--          2 / 15 / 21 / 83466
--          3 / 8 / 14 / 85439
--          4 / 4 / 7 / 51115
--          5 / 1 / 3 / 40588

-- 4. F and M distributions
SELECT f_score, COUNT(*) FROM rfm_scores GROUP BY 1 ORDER BY 1;
-- Results : f_score / count
--            1 / 235461
--            2 / 60952
--            3 / 21918
--            4 / 15766
--            5 / 13021
SELECT m_score, COUNT(*) FROM rfm_scores GROUP BY 1 ORDER BY 1;
-- Results : m_score / count
--            1 / 69354
--            2 / 69354
--            3 / 69354
--            4 / 69354
--            5 / 69702