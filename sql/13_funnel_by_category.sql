-- =====================================================================
-- Funnel Breakdown by Product Category 
-- Description: Evaluates unique viewers, carters, purchasers, and 
--              conversion rates grouped by product category.
-- =====================================================================

DROP TABLE IF EXISTS user_category_stages;

CREATE TABLE user_category_stages AS
SELECT user_id,
       category_code, 
       BOOL_OR(event_type = 'view')     AS had_view,
       BOOL_OR(event_type = 'cart')     AS had_cart,
       BOOL_OR(event_type = 'purchase') AS had_purchase
FROM clean_events
WHERE bot_status = 'not_suspected_bot'
GROUP BY user_id, category_code;

DROP VIEW IF EXISTS v_funnel_by_category;

CREATE VIEW v_funnel_by_category AS
SELECT
  category_code,
  COUNT(*) FILTER (WHERE had_view) AS viewers,
  COUNT(*) FILTER (WHERE had_view AND had_cart) AS carters,
  COUNT(*) FILTER (WHERE had_view AND had_cart AND had_purchase) AS cart_buyers,
  COUNT(*) FILTER (WHERE had_view AND had_purchase) AS purchasers,
  ROUND(100.0 * COUNT(*) FILTER (WHERE had_view AND had_cart) / NULLIF(COUNT(*) FILTER (WHERE had_view), 0), 2) AS view_to_cart_pct,
  ROUND(100.0 * COUNT(*) FILTER (WHERE had_view AND had_cart AND had_purchase) / NULLIF(COUNT(*) FILTER (WHERE had_view AND had_cart), 0), 2) AS cart_to_purchase_pct,
  ROUND(100.0 * COUNT(*) FILTER (WHERE had_view AND had_cart AND NOT had_purchase) / NULLIF(COUNT(*) FILTER (WHERE had_view AND had_cart), 0), 2) AS cart_abandon_pct,
  ROUND(100.0 * COUNT(*) FILTER (WHERE had_view AND had_purchase)  / NULLIF(COUNT(*) FILTER (WHERE had_view), 0), 2) AS overall_conversion_pct
FROM user_category_stages
GROUP BY category_code
-- I filtered out those category that had less than 1000 views because a category with 20 viewers and 4 buyers shows a 20% conversion rate. One more buyer would move it to 25%.
-- But a category with 100000 viewers shifts by a fraction of percent when few user changes. Without this filter tiny categories would land at top or bottom of ranking.
-- I choose 1000 because its a judgement call not a rule to strictly use 1000 as we have 3 million viewers 1000 is about 0.03% of them so only tiny categories are removed.
HAVING COUNT(*) FILTER (WHERE had_view) >= 1000;

SELECT * FROM v_funnel_by_category ORDER BY viewers DESC LIMIT 15;

-- Results | category_code | viewers | carters | cart_buyers | purchasers | view_to_cart_pct | cart_to_purchase_pct | cart_abandon_pct | overall_conversion_pct |
--         | uncategorized | 1512983 | 51785 | 27196 | 104880 | 3.42 | 52.52 | 47.48 | 6.93 |
--         | electronics.smartphone | 1299600 | 198215 | 121899 | 160364 | 15.25 | 61.50 | 38.50 | 12.34 |
--         | electronics.audio.headphone | 213743 | 22468 | 12000 | 18818 | 10.51 | 53.41 | 46.59 | 8.80 |
--         | electronics.clocks | 211606 | 9473 | 4962 | 10744 | 4.48 | 52.38 | 47.62 | 5.08 |
--         | electronics.video.tv | 169835 | 16658 | 8911 | 13470 | 9.81 | 53.49 | 46.51 | 7.93 |
--         | appliances.kitchen.washer | 131909 | 9943 | 5297 | 10475 | 7.54 | 53.27 | 46.73 | 7.94 |
--         | appliances.kitchen.refrigerators | 131447 | 6473 | 3138 | 7655 | 4.92 | 48.48 | 51.52 | 5.82 |
--         | computers.notebook | 129027 | 7470 | 3927 | 9181 | 5.79 | 52.57 | 47.43 | 7.12 |
--         | apparel.shoes | 126534 | 0 | 0 | 2757 | 0.00 | NULL | NULL | 2.18 |
--         | appliances.environment.vacuum | 119771 | 8523 | 4935 | 9187 | 7.12 | 57.90 | 42.10 | 7.67 |
--         | apparel.shoes.keds | 91476 | 0 | 0 | 1951 | 0.00 | NULL | NULL | 2.13 |
--         | auto.accessories.player | 80347 | 757 | 407 | 3243 | 0.94 | 53.76 | 46.24 | 4.04 |
--         | furniture.bedroom.bed | 78765 | 482 | 236 | 1549 | 0.61 | 48.96 | 51.04 | 1.97 |
--         | computers.desktop | 71671 | 1805 | 809 | 2204 | 2.52 | 44.82 | 55.18 | 3.08 |
--         | electronics.tablet | 58628 | 4097 | 2226 | 3445 | 6.99 | 54.33 | 45.67 | 5.88 |

-- Findings: 
-- 1. Apparel has no cart events at all. `apparel.shoes` (126,534 viewers) and `apparel.shoes.keds` (91,476) show 0 carters but thousands of purchasers. Either the store has a buy-now path or cart tracking is missing for apparel. This explains part of the 41.6% of buyers who skip the cart.
-- 2. Cart-to-purchase is steady at 52 to 54% in most categories. The exceptions are smartphones (61.5%, the best) and desktops (44.8%), refrigerators (48.5%), and beds (49.0%). A cart-stage problem isn't specific to one category.
-- 3. View-to-cart varies a lot. Smartphones convert best at 15.25%, then headphones (10.5%) and TVs (9.8%). Clocks (4.5%), uncategorized (3.4%), auto accessories (0.9%), and beds (0.6%) are much lower.
-- 4. Smartphones carry the store. 1.3M viewers and 160,364 purchasers, with 12.34% overall conversion. About 76,000 smartphone carters didn't buy a smartphone, the largest abandonment pool in absolute terms even though their rate is the lowest (38.5%).
-- 5. "Uncategorized" is the biggest group (1.5M viewers). Its view-to-cart is only 3.42%, but 104,880 purchasers bought against just 27,196 carters, so most of its buyers skipped the cart. That's the missing category data.

WITH nocart AS (
  SELECT user_id FROM user_stages WHERE had_purchase AND NOT had_cart
), 
apparel AS (
  SELECT DISTINCT user_id FROM user_category_stages
  WHERE had_purchase AND category_code LIKE 'apparel%'
)
SELECT COUNT(*) AS nocart_buyers,
       COUNT(*) FILTER (WHERE a.user_id IS NOT NULL) AS also_bought_apparel
FROM nocart n LEFT JOIN apparel a USING (user_id);
-- Results: nocart_buyers: 144356, also_bought_apparel: 3464
-- Findings: -- 6. Only 3,464 of 144,356 no-cart buyers (2.4%) bought apparel, so apparel does not explain the no-cart group.