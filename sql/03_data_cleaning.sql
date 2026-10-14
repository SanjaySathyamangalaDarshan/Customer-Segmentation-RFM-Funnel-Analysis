-- ====================================================================
-- Day 4: Data Cleaning & Anomaly Audits
-- ====================================================================

-- 1. Below Query Helps us to check for Duplicate Rows (if any)
SELECT 
    event_time, event_type, product_id, category_id, category_code, brand, price, user_id, user_session,
    COUNT(*) as duplicate_count
FROM raw_events
GROUP BY 1,2,3,4,5,6,7,8,9
HAVING COUNT(*) > 1;
-- Result : This just gave us rows that are duplicated.

-- 2. Deep-Dive Diagnostic on Exact Duplicates & Double-Clicks


WITH duplicate_analysis AS (
    SELECT 
        event_time, 
        event_type, 
        product_id, 
        category_id, 
        category_code, 
        brand, 
        price, 
        user_id, 
        user_session,
        COUNT(*) AS row_count
    FROM raw_events
    GROUP BY 1,2,3,4,5,6,7,8,9
    HAVING COUNT(*) >  1
)
SELECT 
    COUNT(*) AS total_duplicate_groups,
    SUM(row_count) AS total_rows_involved,
    SUM(row_count - 1) AS exact_redundant_rows_to_remove
FROM duplicate_analysis;
-- Results: Earlier query (1) just showed us the duplicated rows but we had no Idea of how many records are considered as duplicated and which all need to be removed.
--          1. Total Duplicates: 18099 mean, We have 18099 duplicate rows in our table
--          2. Total rows Involved in those duplication : 48319 mean, How many total lines are part of duplication problem.
--          3. The exact redundant rows that need be handeled : 30220 mean, How many exact duplicate copies we need to Handle.
-- Findings: Two identical rows at the same second could be a data glitch, or a user double clicking. For our funnel repeated events could inflate counts so needed to be handled.

-- 3. Statistical Bot Detection
WITH user_activity AS (
    SELECT 
        user_id,
        COUNT(*) AS total_events,
        COUNT(CASE WHEN event_type = 'view' THEN 1 END) AS view_count,
        COUNT(CASE WHEN event_type = 'cart' THEN 1 END) AS cart_count,
        COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS purchase_count
    FROM raw_events
    GROUP BY user_id
),
percentile_calc AS (
    SELECT 
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY total_events) AS p50_median,
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY total_events) AS p90_val,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_events) AS p99_val,
        PERCENTILE_CONT(0.999) WITHIN GROUP (ORDER BY total_events) AS p999_val,
        MAX(total_events) AS max_events
    FROM user_activity
)
SELECT * FROM percentile_calc;
-- Results : p50_median = 4, this says 50% of all users have 4 or fewer events.
--           p90_val = 34, this says 90% of all users have 34 or fewer events.
--           p99_val = 141, this says 99% of all users have 141 or fewer events.
--           p999_val = 368, this says 99.9% of all users have 368 or fewer events.
--           max_events = 7436, this says one user have a 7436 events which is extreme outlier.
-- Findings : Rather than using arbitary thresholds, I used statistical distribution to flag bot users.

-- 4. Check for Anomalous Prices (e.g., zero or negative)
SELECT 
    event_type,
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    COUNT(CASE WHEN price <= 0 THEN 1 END) AS zero_or_negative_prices,
    COUNT(CASE WHEN price IS NULL THEN 1 END) AS null_prices
FROM raw_events
GROUP BY event_type;
-- Results: event_type / min_price / max_price / zero_or_negative / null_prices
--          view / 0.00 / 2574.07 / 68523 / 0
--          cart / 0.00 / 2574.04 / 150 / 0
--          purchase / 0.77 / 2574.07 / 0 / 0
