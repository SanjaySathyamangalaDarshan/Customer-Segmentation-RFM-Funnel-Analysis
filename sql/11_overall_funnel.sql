-- ==========================================================================
-- Overall funnel and user paths
-- Definition: user-based funnel, stages nested (view, then cart, then purchase),
-- suspected bots excluded. Also includes a validation check and a user-path
-- breakdown, because 41.6% of buyers skip the cart event.
-- ==========================================================================

-- I could have used the clean_events table, but I created a summary table so that Instead of Having Hundered of rows per user,
-- this broke down each users to exactly 1 row indicating whether they have performed each of three funnel action.

DROP TABLE IF EXISTS user_stages;

CREATE TABLE user_stages AS
SELECT user_id,
  BOOL_OR(event_type = 'view')     AS had_view,
  BOOL_OR(event_type = 'cart')     AS had_cart,
  BOOL_OR(event_type = 'purchase') AS had_purchase
FROM clean_events
WHERE bot_status = 'not_suspected_bot'
GROUP BY user_id;

CREATE INDEX idx_user_stages_user ON user_stages(user_id);

DROP VIEW IF EXISTS v_overall_funnel;   

CREATE VIEW v_overall_funnel AS
WITH f AS (
  SELECT
    COUNT(*) FILTER (WHERE had_view)                              AS viewers,
    COUNT(*) FILTER (WHERE had_view AND had_cart)                 AS carters,
    COUNT(*) FILTER (WHERE had_view AND had_cart AND had_purchase) AS purchasers
  FROM user_stages
)
SELECT '1. View' AS funnel_stage, viewers AS users,
       100.0 AS pct_of_start, 100.0 AS pct_of_previous, 0.0 AS drop_off_pct
FROM f
UNION ALL
SELECT '2. Cart', carters,
       ROUND(carters * 100.0 / viewers, 2), ROUND(carters * 100.0 / viewers, 2),
       ROUND(100.0 - carters * 100.0 / viewers, 2)
FROM f
UNION ALL
SELECT '3. Purchase (via cart)', purchasers,
       ROUND(purchasers * 100.0 / viewers, 2), ROUND(purchasers * 100.0 / carters, 2),
       ROUND(100.0 - purchasers * 100.0 / carters, 2)
FROM f;

SELECT * FROM v_overall_funnel;

-- Results: funnel_stage / users / pct_of_start / pct_of_previous / drop_off_pct
--            1.View / 3020723 / 100.0 / 100.0 / 0.0
--            2.Cart / 336961 / 11.15 / 11.15 / 88.85
--            3.Purchase (via cart) / 202739 / 6.71 / 60.17 / 39.83

SELECT
  COUNT(*) FILTER (WHERE had_purchase)                      AS purchasers_all,
  COUNT(*) FILTER (WHERE had_purchase AND had_cart)         AS purchasers_with_cart,
  COUNT(*) FILTER (WHERE had_purchase AND NOT had_cart)     AS purchase_without_cart,
  COUNT(*) FILTER (WHERE had_purchase AND NOT had_view)     AS purchase_without_view,
  COUNT(*) FILTER (WHERE had_cart AND NOT had_view)         AS cart_without_view
FROM user_stages; 
-- Results: purchasers_all: 347118, purchasers_with_cart: 202762, purchase_without_cart: 144356, purchase_without_view: 64, cart_without_view: 121

SELECT
  CASE WHEN had_purchase AND had_cart     THEN '3a. Cart, then purchase'
       WHEN had_purchase AND NOT had_cart THEN '3b. Purchase without cart'
       WHEN had_cart AND NOT had_purchase THEN '2. Cart abandoned (no purchase)'
       ELSE '1. Viewed only' END AS user_path,
  COUNT(*) AS users,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_viewers
FROM user_stages
WHERE had_view
GROUP BY 1
ORDER BY 1;
-- Results: user_path / users / pct_of_viewers
--          1.Viewed only / 2539447 / 84.07
--          2.Cart abandoned (no purchase) / 134222 / 4.44
--          3a.Cart, then purchase / 202739 / 6.71
--          3b.Purchase without cart / 144315 / 4.78
-- FINDINGS
-- 1. Funnel analysis query(user-based, nested stages, bots excluded): 3,020,723 viewers,
--    336,961 carted (11.15%), 202,739 purchased via cart (60.17% of cart users).
-- 2. Wrong assumption caught: 347,118 users bought (matches RFM), not 202,739.
--    144,356 buyers (41.6%) have no cart event, and nearly all of them viewed a
--    product. About 11.5% of viewers buy, not 6.71%.
-- 3. User paths (above written query) (viewers): 84.07% viewed only, 4.44% abandoned cart (134,222
--    users, 39.8% of cart users), 6.71% cart then purchase, 4.78% purchase
--    without cart.
-- 4. Cart abandoners are the clearest recoverable group at this stage.
-- LIMITATION: the data can't say why many buyers skip the cart (buy-now button,
-- tracking gap, or carts created before October).

-- Todays Findings:
-- At first I thaught every users goes view, cart, purchase, And expected buyers pass through the cart before purchasing.
-- Then I found the strict funnel counts 202,739 purchasers, but the RFM table has 347,118 buyers. 144,356 buyers (41.6%) have no cart event, and nearly all of them did view a product (only 64 purchased with no view).
-- This matters because the strict funnel understates purchasers and conversion. About 11.5% of viewers buy, not 6.71%.
-- Then I reported both the strict funnel and a user-path breakdown. Cart abandoners (134,222 users) are the clearest recoverable group.
