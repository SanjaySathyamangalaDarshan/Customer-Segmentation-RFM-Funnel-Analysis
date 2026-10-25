-- =====================================================================
-- Purchase Path Breakdown by RFM Segment & Sizing
-- Description: Maps how buyers in each RFM segment completed their 
--              purchases (cart vs. direct buy-now) and captures 
--              the total non-purchaser population size.
-- =====================================================================

DROP VIEW IF EXISTS v_segment_purchase_path;

CREATE VIEW v_segment_purchase_path AS
SELECT s.customer_segment,
       COUNT(*) AS buyers,
       COUNT(*) FILTER (WHERE u.had_cart) AS bought_via_cart,
       COUNT(*) FILTER (WHERE NOT u.had_cart) AS bought_without_cart,
       ROUND(100.0 * COUNT(*) FILTER (WHERE NOT u.had_cart) / COUNT(*), 1) AS pct_skip_cart
FROM rfm_segments s
JOIN user_stages u ON s.user_id = u.user_id
GROUP BY s.customer_segment;

SELECT * FROM v_segment_purchase_path ORDER BY buyers DESC;
-- Result: | customer_segment | buyers | bought_via_cart | bought_without_cart | pct_skip_cart |
--         | Hibernating | 156045 | 78530 | 77515 | 49.7 |
--         | General Customers | 74039 | 46418 | 27621 | 37.3 |
--         | New customers | 50793 | 25873 | 24920 | 49.1 |
--         | Loyal Customers | 20491 | 16878 | 3613 | 17.6 |
--         | Potential Loyalists | 18584 | 12313 | 6271 | 33.7 |
--         | Champions | 13955 | 12374 | 1581 | 11.3 |
--         | At Risk | 11087 | 8587 | 2500 | 22.5 |
--         | Cannot Lose Them | 1776 | 1447 | 329 | 18.5 |
--         | Wholesale Key Accounts | 348 | 342 | 6 | 1.7 |
-- Findings: 1. Cart-skipping is mostly a one-time-buyer pattern. About half of Hibernating and New buyers bought without a cart event, while the repeat segments rarely do. Together they make up about 71% of all no-cart buyers (102,435 of 144,356).
--	         2.	Our target segments use the cart. About 78% of At Risk and Cannot Lose Them buyers (10,034 of 12,863) bought through the cart. Cart-based tools such as reminders or saved-cart emails can reach them, which fits your hypothesis. It's still only a hint: this shows how they bought before, and Test 1 checks whether they're active now.
--	         3.	Wholesale accounts almost always use the cart (342 of 348), which fits planned business purchases and supports handling them through account management.
-- Conditions: "bought via cart" means the user had a cart event at any time in October, not necessarily for the same product or session.

-- ==========================
-- FINDING OUT NON-PURCHASERS
-- ==========================

SELECT COALESCE(s.customer_segment, 'Never Purchased') AS segment,
       COUNT(*) AS users
FROM user_stages u
LEFT JOIN rfm_segments s ON u.user_id = s.user_id
GROUP BY 1
ORDER BY users DESC;
-- Results: | segment | users |
--          | Never Purchased | 2673767 |
--          | Hibernating | 156045 |
--          | General Customers | 74039 |
--          | New customers | 50793 |
--          | Loyal Customers | 20491 |
--          | Potential Loyalists | 18584 |
--          | Champions | 13955 |
--          | At Risk | 11087 |
--          | Cannot Lose Them | 1776 |
--          | Wholesale Key Accounts | 348 |
-- Findings: 1. 2,673,767 Never Purchased plus the 347,118 buyers gives 3,020,885 users in user_stages.
--	         2.	Each buyer segment matches our earlier tables (Hibernating 156,045, General 74,039, and so on).
--           3.	That total is 162 more than our 3,020,723 viewers. Those 162 users have no view event: 64 are buyers who purchased without a view (the check I ran earlier), and the other 98 are Never Purchased users with a cart event but no view. 
--           4. It means 88.5% of all users never bought in October, and 11.5% did. The Never Purchased group is about 7.7 times the size of the whole buyer base. Most of it is browsing with no purchase, and the cart abandoners (134,222) are the part with clear intent.

