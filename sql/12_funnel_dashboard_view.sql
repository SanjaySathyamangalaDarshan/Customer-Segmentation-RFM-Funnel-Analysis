-- ========================================
-- Created user path view
-- ========================================

DROP VIEW IF EXISTS v_user_paths;
CREATE VIEW v_user_paths AS
SELECT
  CASE WHEN had_purchase AND had_cart     THEN '3a. Cart, then purchase'
       WHEN had_purchase AND NOT had_cart THEN '3b. Purchase without cart'
       WHEN had_cart AND NOT had_purchase THEN '2. Cart abandoned (no purchase)'
       ELSE '1. Viewed only' END AS user_path,
  COUNT(*) AS users,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_viewers
FROM user_stages
WHERE had_view
GROUP BY 1;