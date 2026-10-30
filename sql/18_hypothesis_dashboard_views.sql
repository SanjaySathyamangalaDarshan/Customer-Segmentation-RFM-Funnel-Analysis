-- =========================================================================================================================
-- Hard-coded results from 16_hypothesis_test_activity.sql and 17_hypothesis_test_revenue.sql, so Power BI can chart them.
-- At Risk and Hibernating values are copied from the query outputs.
-- Cart abandoners per-contact values are calculated: average cart item price (324.07) x response rate = 6.48, 16.20, 32.41.
-- =========================================================================================================================


DROP VIEW IF EXISTS v_hypothesis_pools;
CREATE VIEW v_hypothesis_pools AS
SELECT * FROM (VALUES
  ('At Risk + Cannot Lose Them'::text, 12863,  420.94, 8.42, 21.05, 42.09,  270730),
  ('Cart abandoners'::text,            134320, 324.07, 6.48, 16.20, 32.41, 2176487),
  ('Hibernating'::text,                156045, 300.53, 6.01, 15.03, 30.05, 2344830)
) AS t(pool, users, avg_value, per_contact_2pct, per_contact_5pct, per_contact_10pct, total_5pct);


DROP VIEW IF EXISTS v_hypothesis_activity;
CREATE VIEW v_hypothesis_activity AS
SELECT * FROM (VALUES
  ('At Risk + Cannot Lose Them'::text, 41.1, 5.0, 12863),
  ('Hibernating'::text,                38.1, 3.4, 156045)
) AS t(grp, pct_browsed, pct_carted, buyers);

-- Limitations: These both views contains fixed values, not live query.