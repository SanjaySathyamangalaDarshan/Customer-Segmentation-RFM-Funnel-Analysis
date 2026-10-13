-- ====================================================================================================================================================================
-- When working with over 42.4 million rows, full table scans for GROUP BY, JOIN, and WHERE clauses will start to lag as we write more complex RFM and funnel queries.
-- SO ADDING INDEXES WILL SPPED UP OUR PROCESS
-- ====================================================================================================================================================================


-- Index for fast event filtering (Funnel analysis)
CREATE INDEX IF NOT EXISTS idx_raw_events_event_type 
ON raw_events (event_type);

-- Index for user-level aggregations (RFM analysis & unique users)
CREATE INDEX IF NOT EXISTS idx_raw_events_user_id 
ON raw_events (user_id);

-- Index for session-level analysis
CREATE INDEX IF NOT EXISTS idx_raw_events_user_session 
ON raw_events (user_session);

-- Index for temporal/recency filtering
CREATE INDEX IF NOT EXISTS idx_raw_events_event_time 
ON raw_events (event_time);



