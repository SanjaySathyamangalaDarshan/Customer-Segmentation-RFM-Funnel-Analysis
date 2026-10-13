-- INITIAL DATA PROFILING & QUALITY VALIDATION
-- ==================================================


-- 1. How many events have occurred
SELECT COUNT(*) as total_records
FROM raw_events;
-- Result: 42,448,764 events


-- 2. Distribution of Events Types (Here we get to know event count for specific event_type and their percentage to total)
SELECT event_type,
       COUNT(*) AS event_count,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM raw_events),2) AS pct_of_total
FROM raw_events
GROUP BY event_type
ORDER BY event_count DESC;
-- Result: event_type / event_count / pct_of_total
--          view / 40,779,399 / 96.07
--          cart / 926,516 / 2.18
--          purchase / 742849 / 1.75
-- FINDINGS I GOT HERE : 1. View - Cart Drop-Off: Out of 40.78M view events, only 2.18% progress to the cart. That is a massive 97.82% drop-off from browsing to intent.
--                       2. Cart - Purchase Efficiency: Once an item enters the cart, 80.18% of those cart events convert to a purchase (742.8k purchases vs 926.5k cart additions).
--                       3. Based on these number what I noticed was The primary conversion bottleneck is not checkout friction, but rather getting users from product discovery (view) to adding an item to their cart (cart).


-- 3. We found out earliest date, latest date and number of active days.
SELECT 
    MIN(event_time) :: DATE AS earliest_event,
    MAX(event_time) :: DATE AS latest_event,
    COUNT(DISTINCT DATE(event_time)) AS active_days
FROM raw_events;
-- Result: earliest_event = 2019-10-01, latest_event = 2019-10-31, active_days = 31


-- 4. By below query we got to know Unique Entity Metrics
SELECT 
    COUNT(DISTINCT user_id) AS total_unique_users,
    COUNT(DISTINCT user_session) AS total_sessions,
    COUNT(DISTINCT product_id) AS total_products,
    COUNT(DISTINCT category_code) AS tagged_categories
FROM raw_events;
-- Result: Unique_users = 3,022,290, Distinct_session = 9,244,421, Unique_product = 166,794, tagged_categories = 126


-- 5. Here we used the below query to find out missing Data in every column
SELECT 
    COUNT(*) - COUNT(event_time) AS missing_event_time,
    COUNT(*) - COUNT(event_type) AS missing_event_type,
    COUNT(*) - COUNT(product_id) AS missing_product_id,
    COUNT(*) - COUNT(category_id) AS missing_category_id,
    COUNT(*) - COUNT(category_code) AS missing_category_code,
    COUNT(*) - COUNT(brand) AS missing_brand,
    COUNT(*) - COUNT(price) AS missing_price,
    COUNT(*) - COUNT(user_id) AS missing_user_id,
    COUNT(*) - COUNT(user_session) AS missing_user_session
FROM raw_events;
-- Result Columns / Missing records
--        event_time / 0
--        event_type / 0
--        product_id / 0
--        category_id / 0
--        category_code / 13,515,609
--        brand / 6113009
--        price / 0
--        user_id / 0
--        user_session / 2
-- Key Findings : Primary key and Metrics have 0 missing values. Where category code has 13.5M missing records that need to be handled when building category level  funnel visuals.



