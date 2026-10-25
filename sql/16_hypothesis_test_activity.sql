-- ==========================================================================================================
-- Hypothesis Testing - Segment Activity Recency
-- Description: It checks how many At Risk + Cannot Lose Them buyers still browsed or 
--              carted in the last 14 days of the data (Oct 18 to 31), against Hibernating and everyone else. 
--              Buyers with recency of 15 days or more last purchased on or before Oct 17, so any recent 
--              activity for them is browsing without buying
-- ===========================================================================================================

WITH recent AS (
  SELECT user_id,
         BOOL_OR(event_type IN ('view', 'cart')) AS browsed,
         BOOL_OR(event_type = 'cart')            AS carted
  FROM clean_events
  WHERE bot_status = 'not_suspected_bot'
    AND event_time >= '2019-10-18'
  GROUP BY user_id
)
SELECT CASE WHEN s.customer_segment IN ('At Risk', 'Cannot Lose Them')
            THEN 'At Risk + Cannot Lose Them'
            WHEN s.customer_segment = 'Hibernating' THEN 'Hibernating'
            ELSE 'Other buyers' END AS grp,
       COUNT(*) AS buyers,
       COUNT(*) FILTER (WHERE r.browsed) AS browsed_recently,
       ROUND(100.0 * COUNT(*) FILTER (WHERE r.browsed) / COUNT(*), 1) AS pct_browsed,
       ROUND(100.0 * COUNT(*) FILTER (WHERE r.carted)  / COUNT(*), 1) AS pct_carted
FROM rfm_segments s
LEFT JOIN recent r ON s.user_id = r.user_id
GROUP BY 1
ORDER BY 1;
-- Results: | grp | buyers | browsed_recently | pct_browsed | pct_carted |
--          | At Risk + Cannot Lose Them | 12,863 | 5,289 | 41.1% | 5.0% |
--          | Hibernating | 156,045 | 59,381 | 38.1% | 3.4% |
--          | Other buyers | 178,210 | 177,744 | 99.7% | 59.0% |
-- Findings: 
-- 1. The "little recent browsing" condition did not trigger. 41.1% of At Risk +
--    Cannot Lose Them buyers (5,289 of 12,863) viewed or carted since Oct 18.
-- 2. The edge over Hibernating is small. Browsing: 41.1% vs 38.1% (+3.0 points).
--    Carting: 5.0% vs 3.4% (+1.6 points, about 1.5 times higher).
-- 3. Most buyers in both groups were silent: about 58.9% of At Risk + Cannot Lose
--    Them and 61.9% of Hibernating showed no activity in the last 14 days.
-- 4. "Other buyers" (99.7%) is not a comparison group: they purchased recently,
--    so their activity is mostly part of buying.
-- 5. Interpretation: weak support for the hypothesis. The case for targeting
--    At Risk + Cannot Lose Them has to rest on value per contact (Test 2).
-- Limitations: a 14-day window only. Activity is any view or cart event, not
-- necessarily a sign the buyer will purchase again. There is no contact or
-- response data in the dataset.
