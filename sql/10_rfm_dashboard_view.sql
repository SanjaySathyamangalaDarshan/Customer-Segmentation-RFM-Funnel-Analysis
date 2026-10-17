-- =======================================================================================================================================
-- Created a VIEW so that Instead of connecting to base Table(rfm_segments) connecting to View improves and avoid Decoupling BI dashboards
-- =======================================================================================================================================

DROP VIEW IF EXISTS v_rfm_dashboard_summary;

CREATE VIEW v_rfm_dashboard_summary AS
SELECT 
    customer_segment,
    COUNT(user_id) AS total_customers,
    ROUND(COUNT(user_id) * 100.0 / SUM(COUNT(user_id)) OVER(), 2) AS pct_customers,
    ROUND(SUM(monetary), 2) AS total_revenue,
    ROUND(SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER(), 2) AS pct_revenue,
    ROUND(AVG(monetary), 2) AS avg_monetary_spend,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(frequency), 1) AS avg_frequency
FROM rfm_segments
GROUP BY customer_segment;

-- A clean check.
SELECT * FROM v_rfm_dashboard_summary ORDER BY total_revenue DESC;