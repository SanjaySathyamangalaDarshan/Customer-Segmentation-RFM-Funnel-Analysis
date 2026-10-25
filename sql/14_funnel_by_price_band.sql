-- =====================================================================
-- Funnel Breakdown by Price Band
-- Description: Categorizes event items into price tiers to analyze 
--              how product pricing impacts cart and purchase conversion.
-- =====================================================================

SELECT percentile_cont(ARRAY[0.1, 0.25, 0.5, 0.75, 0.9, 0.99])
         WITHIN GROUP (ORDER BY price) AS price_percentiles
FROM clean_events
WHERE bot_status = 'not_suspected_bot';
-- Results: 30.86, 60.49, 163.73, 358.57, 743.64, 1741.34

DROP TABLE IF EXISTS user_price_stages;

CREATE TABLE user_price_stages AS
SELECT user_id,
  CASE WHEN price < 65  THEN '1. Under 65'
       WHEN price < 165 THEN '2. 65 to 164.99'
       WHEN price < 360 THEN '3. 165 to 359.99'
       ELSE '4. 360 and above' END AS price_band,
  BOOL_OR(event_type = 'view') AS had_view,
  BOOL_OR(event_type = 'cart') AS had_cart,
  BOOL_OR(event_type = 'purchase') AS had_purchase
FROM clean_events
WHERE bot_status = 'not_suspected_bot'
GROUP BY 1, 2;

DROP VIEW IF EXISTS v_funnel_by_price_band;

CREATE VIEW v_funnel_by_price_band AS
SELECT price_band,
  COUNT(*) FILTER (WHERE had_view) AS viewers,
  COUNT(*) FILTER (WHERE had_view AND had_cart) AS carters,
  COUNT(*) FILTER (WHERE had_view AND had_cart AND had_purchase) AS cart_buyers,
  COUNT(*) FILTER (WHERE had_view AND had_purchase) AS purchasers,
  ROUND(100.0 * COUNT(*) FILTER (WHERE had_view AND had_cart) / NULLIF(COUNT(*) FILTER (WHERE had_view), 0), 2) AS view_to_cart_pct,
  ROUND(100.0 * COUNT(*) FILTER (WHERE had_view AND had_cart AND had_purchase) / NULLIF(COUNT(*) FILTER (WHERE had_view AND had_cart), 0), 2) AS cart_to_purchase_pct,
  ROUND(100.0 * COUNT(*) FILTER (WHERE had_view AND had_cart AND NOT had_purchase) / NULLIF(COUNT(*) FILTER (WHERE had_view AND had_cart), 0), 2) AS cart_abandon_pct,
  ROUND(100.0 * COUNT(*) FILTER (WHERE had_view AND had_purchase) / NULLIF(COUNT(*) FILTER (WHERE had_view), 0), 2) AS overall_conversion_pct
FROM user_price_stages
GROUP BY price_band;

SELECT * FROM v_funnel_by_price_band ORDER BY price_band;

-- Results: | price_band | viewers | carters | cart_buyers | purchasers | view_to_cart_pct | cart_to_purchase_pct | cart_abandon_pct | overall_conversion_pct |
--          | 1. Under 65 | 1356149 | 61285 | 32540 | 97192 | 4.52 | 53.10 | 46.90 | 7.17 |
--          | 2. 65 to 164.99 | 1525505 | 103537 | 61990 | 114867 | 6.79 | 59.87 | 40.13 | 7.53 |
--          | 3. 165 to 359.99 | 1545276 | 120924 | 70884 | 117919 | 7.83 | 58.62 | 41.38 | 7.63 |
--          | 4. 360 and above | 1484552 | 108667 | 60829 | 95246 | 7.32 | 55.98 | 44.02 | 6.42 |

-- Findings: 1. Cheap items rarely reach the cart. Under 65, view-to-cart is only 4.52%, against 6.79% to 7.83% in the middle bands.
--              Mid-priced carts convert best. Cart-to-purchase peaks at 59.87% (65 to 164.99) and 58.62% (165 to 359.99). The cheapest band is the lowest at 53.10%.
--              The top band converts worst overall. At 360 and above, overall conversion is 6.42%, against 7.17% to 7.63% elsewhere. Its cart abandonment is 44.02%, second highest after the cheapest band (46.90%).
--           2. Where the recoverable carts are (carters minus cart buyers, so users who carted in a band and never bought there): Under 65: about 28,700, 65 to 164.99: about 41,500, 165 to 359.99: about 50,000, 360 and above: about 47,800
--              The two highest bands hold the largest abandoned carts, and each of those carts is worth more. That is a useful input for our recoverable-revenue estimate.

-- Conditions: 1. A user can appear in several bands, so don't add the rows. The viewer total is about 5.9M against 3.02M real users.
--             2. "Bought without a cart event" here means within that band. A cart in another band wouldn't count.