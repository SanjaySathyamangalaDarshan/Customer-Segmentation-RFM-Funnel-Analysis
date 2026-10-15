-- ====================================================================
-- Building Purchase Clean Table for RFM Segmentation
-- ====================================================================


-- NOTE: Instead of scanning 42+ million rows and constantly filter out view, cart, and suspected_bot rows every single time, a purchase_clean table shrinks the working dataset down to only valid transactions. So that our query runs fast.

DROP TABLE IF EXISTS purchase_clean;

CREATE TABLE purchase_clean AS
SELECT *
FROM clean_events
WHERE event_type = 'purchase'
  AND bot_status = 'not_suspected_bot';

-- Creating Indexes is very much required to speed up the process
CREATE INDEX idx_purchase_clean_user_id ON purchase_clean(user_id);
CREATE INDEX idx_purchase_clean_time ON purchase_clean(event_time);

-- Here I wrote a Validation query to see the valid purchase records and unique paying customers.
SELECT 
    COUNT(*) AS total_purchase_rows,
    COUNT(DISTINCT user_id) AS unique_paying_customers,
    COUNT(DISTINCT user_session) AS purchase_session,
    ROUND(SUM(price),2) AS total_revenue,
    MIN(event_time)::DATE AS first_purchase,
    MAX(event_time)::DATE AS last_purchase
FROM purchase_clean;
--Results: total valid purchases: 742773, unique paying customers: 347118, purchase_session: 629560, 
--         total_revenue: 229933212.63, first_purchase was on: 2019-10-01, last purchase was on: 2019-10-31

