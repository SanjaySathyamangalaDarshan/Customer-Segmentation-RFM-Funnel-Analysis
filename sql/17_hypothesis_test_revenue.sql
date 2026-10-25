-- =====================================================================================================================================
-- Hypothesis Testing - Test 2: Value per Contact & Recoverable Revenue
-- Description: It uses average order value (total spend ÷ purchases), because a win-back is one more order, not a whole month's spend. 
-- That's more careful than the average-spend figure we used in an earlier illustration.
-- =====================================================================================================================================

WITH grp AS (
  SELECT CASE WHEN customer_segment IN ('At Risk', 'Cannot Lose Them')
              THEN 'At Risk + Cannot Lose Them' ELSE 'Hibernating' END AS grp,
         monetary, frequency
  FROM rfm_segments
  WHERE customer_segment IN ('At Risk', 'Cannot Lose Them', 'Hibernating')
)
SELECT grp,
  COUNT(*) AS buyers,
-- total money divided by total orders, which gives the value of one order. I didn't use the average spend per buyer, because a win-back is one more order, not another month's worth of spending.
  ROUND(SUM(monetary) / SUM(frequency), 2) AS avg_order_value,
  ROUND(0.02 * SUM(monetary) / SUM(frequency), 2) AS per_contact_2pct,
  ROUND(0.05 * SUM(monetary) / SUM(frequency), 2) AS per_contact_5pct,
  ROUND(0.10 * SUM(monetary) / SUM(frequency), 2) AS per_contact_10pct,
-- At Risk + Cannot Lose Them: average order value is 420.94.
--	•	Say if we email 100 of them and 5 place an order. Revenue is 5 * 420.94 = 2,104.70.
--	•	Divide by the 100 emails: 21.05 per email. That's our per_contact_5pct.
--	•	Hibernating: 5 * 300.53 = 1,502.65, divided by 100 emails is 15.03 per email.
--      per_contact is the average revenue each email earns, counting the 95 people who ignored it. The 2%, 5%, and 10% columns do the same sum with 2, 5, or 10 responders out of 100.
  ROUND(0.05 * COUNT(*) * SUM(monetary) / SUM(frequency)) AS total_5pct
--  what we would expect if we contacted everyone in the group and 5% came back.
FROM grp
GROUP BY grp;
-- Result: | grp | buyers | avg_order_value | per_contact_2pct | per_contact_5pct | per_contact_10pct | total_5pct |
--         | At Risk + Cannot Lose Them | 12,863 | 420.94 | 8.42 | 21.05 | 42.09 | 270730 |
--         | Hibernating | 156,045 | 300.53 | 6.01 | 15.03 | 30.05 | 2344830 |
-- Findings:
-- 1. Average order value: At Risk + Cannot Lose Them 420.94 vs Hibernating 300.53,
--    so about 1.4 times higher per order.
-- 2. At equal response rates, each contact is worth about 40% more for At Risk +
--    Cannot Lose Them: 8.42 vs 6.01 (2%), 21.05 vs 15.03 (5%), 42.09 vs 30.05 (10%).
-- 3. With the same number of contacts (12,863, the size of the At Risk group) at a
--    5% response rate: about 270,700 vs about 193,300.
-- 4. In total, Hibernating holds more recoverable revenue (about 2.34M vs 270,730
--    at 5%), because it has about 12 times more buyers. The advantage only applies
--    under a limited contact budget.
-- 5. Break-even: Hibernating would need a response rate about 1.4 times higher
--    (7.0% against 5.0%) to match At Risk per contact.
-- 6. Interpretation: partial support. At Risk + Cannot Lose Them is better per
--    contact, but by a margin a modest response-rate difference could erase.
-- Limitations: response rates are assumptions (no contact data); cost per contact
-- is not included; order values come from one month; some Hibernating buyers may
-- return anyway, so revenue from them would not all be incremental. An A/B test
-- would measure the real response rates.


-- This estimates the recoverable revenue from stage lever (cart abandoners)
SELECT COUNT(DISTINCT c.user_id) AS abandoners,
       ROUND(AVG(c.price), 2)    AS avg_cart_item_price,
       ROUND(0.02 * COUNT(DISTINCT c.user_id) * AVG(c.price)) AS total_2pct,
       ROUND(0.05 * COUNT(DISTINCT c.user_id) * AVG(c.price)) AS total_5pct,
       ROUND(0.10 * COUNT(DISTINCT c.user_id) * AVG(c.price)) AS total_10pct
-- 134,320 users added something to the cart and never bought.
-- Average cart item price is 324.07.
-- 2% case: if 2% respond, that's about 2,686 people (134,320 × 0.02). Each buys one item at the average price: 2,686 × 324.07 is about 870,595. That's total_2pct.
-- 5% case: about 6,716 people × 324.07 is about 2,176,487. That's total_5pct.
-- 10% case: about 13,432 people × 324.07 is about 4,352,973. That's total_10pct.
FROM clean_events c
JOIN user_stages u ON c.user_id = u.user_id
WHERE c.event_type = 'cart'
  AND c.bot_status = 'not_suspected_bot'
  AND u.had_cart AND NOT u.had_purchase;
-- Result: | abandoners | avg_cart_item_price | total_2pct | total_5pct | total_10pct |
--         | 134320 | 324.07 | 870595 | 2176487 | 4352973 |
-- Findings (stage lever: cart abandoners):
-- 1. 134,320 users carted and never purchased in October. Average cart item
--    price: 324.07.
-- 2. Recovered revenue at 2%, 5%, and 10%: 870,595 / 2,176,487 / 4,352,973.
--    Per contact at 5%: about 16.20.
-- 3. At a 5% response rate, per contact: At Risk + Cannot Lose Them 21.05, cart
--    abandoners 16.20, Hibernating 15.03. In total at 5%: 270,730 vs 2.18M vs
--    2.34M.
-- 4. Cart abandoners and buyers are separate groups, so these totals do not
--    overlap with the segment totals.
-- Limitations: average is per cart event, not per user or basket; recovery rates
-- are assumptions; abandoners may respond differently from dormant buyers.