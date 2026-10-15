-- ========================================================================
-- Calculated Raw RFM(Recency,Frequency and Monetary) Base Metrics per User
-- ========================================================================

CREATE TABLE rfm_base AS
WITH ref AS (
-- Instead of Hardcoring Date I used dynamic Date range so that any changes in dataset it updates automatically
  SELECT (MAX(event_time)::date + 1) AS ref_date 
  FROM purchase_clean
)
SELECT
  p.user_id,
  (SELECT ref_date FROM ref) - MAX(p.event_time)::date AS recency_days,
-- Use of Distinct user session so that If a user buys 3 items in a single checkout session, it represents 1 purchase transaction/session, not 3 independent frequency events.
  COUNT(DISTINCT p.user_session) AS frequency,
  ROUND(SUM(p.price), 2) AS monetary
FROM purchase_clean p
GROUP BY p.user_id;

-- Ran a quick diagnosis 
SELECT
  COUNT(*) AS buyers,
  MIN(recency_days) AS min_r, 
  MAX(recency_days) AS max_r,
  MAX(frequency) AS max_f,
  ROUND(COUNT(*) FILTER (WHERE frequency = 1) * 100.0/ COUNT(*), 1) AS pct_frequency_1,
  MAX(monetary) AS max_m
FROM rfm_base;
-- Results: Buyers: 347118, 
--          Minimum recency days = 1, Maximum recency days = 31
--          Maximum frequency: 152
--          Percentage of frequency with 1: 67.8 As it is one month data 67.8% of people bought only once
--          Maximum monetary: 265569.52

SELECT * 
FROM rfm_base 
ORDER BY monetary DESC 
LIMIT 10;