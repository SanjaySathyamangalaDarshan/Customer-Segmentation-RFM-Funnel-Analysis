# Data Dictionary: E-commerce Clean Events Table (`clean_events`)

This document defines the schema, data types, and business transformation rules applied to the staging table during Phase 1 data cleaning.

| Column Name | Data Type | Description & Transformation Rule |
| :--- | :--- | :--- |
| `event_time` | Timestamp | Exact UTC timestamp when the user interaction occurred (October 2019 dataset window). |
| `event_type` | Varchar | The action performed by the user. Categorized into `view`, `cart`, and `purchase`. |
| `product_id` | Integer | Unique identifier for the specific product item. |
| `category_id` | BigInt | Unique identifier for the product category hierarchy. |
| `category_code` | Varchar | Hierarchical category string. Missing values were imputed via `COALESCE(category_code, 'uncategorized')`. |
| `brand` | Varchar | Manufacturer or brand name. Missing values were imputed via `COALESCE(brand, 'unknown')`. |
| `price` | Numeric | Product price at the time of the event in USD. Rows with zero or negative prices were filtered out. |
| `user_id` | BigInt | Unique identifier for the customer/user account. |
| `user_session` | UUID / Varchar | Unique identifier representing a continuous browsing session for a user. |
| `bot_status` | Varchar | Behavioral classification flag. Labeled as `'suspected_bot'` for users exceeding the extreme-tail event threshold (>368 events) with zero commercial intent (`cart`/`purchase` = 0); otherwise labeled `'not_suspected_bot'`. |

### `purchase_clean`
Pre-filtered transaction ledger containing valid human purchase events, retaining the full event schema from `clean_events`.

| Column Name | Data Type | Description & Transformation Rule |
| :--- | :--- | :--- |
| `user_id` | BigInt / Varchar | Unique identifier for the customer. |
| `event_time` | Timestamp | Exact UTC timestamp when the purchase event occurred. |
| `product_id` | Integer / Varchar | Unique identifier of the purchased product item. |
| `price` | Numeric | Monetary value/price of the product at the time of purchase. |
| `user_session` | Varchar / UUID | Unique session identifier associated with the user's checkout session. |
| *[Inherited Columns]* | *[Various]* | Retains all remaining schema columns from `clean_events` (e.g., `category_code`, `brand`) pre-filtered for valid human purchases. |

---

### `rfm_base`
Intermediate aggregation table holding raw, un-scored customer metrics calculated dynamically relative to the dataset snapshot reference date (`MAX(event_time) + 1 day`).

| Column Name | Data Type | Description & Transformation Rule |
| :--- | :--- | :--- |
| `user_id` | BigInt / Varchar | Unique customer identifier (Primary Key for aggregations). |
| `recency_days` | Integer | Days elapsed between the user's last purchase date (`MAX(event_time)::date`) and the dynamic snapshot date (`ref_date` derived as `MAX(event_time) + 1 day`). |
| `frequency` | Integer | Count of distinct checkout sessions (`COUNT(DISTINCT user_session)`) to accurately represent discrete purchasing visits rather than individual row counts. |
| `monetary` | Numeric | Total cumulative spend across all valid purchase transactions per user, rounded to 2 decimal places (`ROUND(SUM(price), 2)`). |

---

### `rfm_scores`
Final analytical scoring table containing granular RFM quantile/fixed-band scores, wholesale outlier isolation flags, and concatenated 3-digit RFM cells.

| Column Name | Data Type | Description & Transformation Rule |
| :--- | :--- | :--- |
| `user_id` | BigInt / Varchar | Unique customer identifier (Primary Key). |
| `recency_days` | Integer | Days since last purchase. |
| `frequency` | Integer | Count of distinct purchase sessions. |
| `monetary` | Numeric | Cumulative purchase spend. |
| `customer_segment_type` | Varchar | Flag distinguishing `'Retail'` customers from extreme right-tail `'Wholesaler'` accounts (isolated via the 99.9th percentile monetary threshold). |
| `r_score` | Integer | Recency score (1 to 5; 5 = most recent) assigned via fixed business-logic bands ($\le 3$, $\le 7$, $\le 14$, $\le 21$, $>21$ days) to prevent tie-splitting. |
| `f_score` | Integer | Frequency score (1 to 5; 5 = highest visits) assigned via fixed business-logic bands ($1$, $2$, $3$, $4\text{--}5$, $>5$ sessions) to account for the heavy 67.8% one-time buyer skew. |
| `m_score` | Integer | Monetary score (1 to 5; 5 = highest spenders) assigned via `NTILE(5)` quintiles partitioned by `customer_segment_type` (forced to $5$ for wholesalers). |
| `rfm_cell` | Varchar | Concatenated string of scores (e.g., `'555'`, `'111'`) or `'Wholesale'` for key accounts. |


### `rfm_segments`
Customer-level analytical dataset mapping granular RFM metrics, quintile/band scores, and assigned marketing personas.

| Column Name | Data Type | Description & Transformation Rule |
| :--- | :--- | :--- |
| `user_id` | BigInt | Unique identifier for the customer account. |
| `recency_days` | Integer | Days between the customer's most recent purchase and the analysis snapshot date. |
| `frequency` | Integer | Count of distinct shopping sessions resulting in a purchase (`COUNT(DISTINCT user_session)`). |
| `monetary` | Numeric | Total monetary spend in USD across all completed purchases. |
| `customer_segment_type` | Varchar | Classification flag identifying outlier accounts (e.g., `'Wholesaler'`) vs standard retail accounts. |
| `r_score` | Integer | Assigned Recency quintile score (1 to 5, where 5 is most recent). |
| `f_score` | Integer | Assigned Frequency band score based on discrete purchase session thresholds. |
| `m_score` | Integer | Assigned Monetary quintile score (1 to 5, calculated across non-wholesaler accounts). |
| `rfm_cell` | Varchar | Concatenated score string representing full RFM profile (e.g., `'555'`, `'111'`). |
| `customer_segment` | Varchar | High-level marketing persona assigned via top-down decision rules (`Champions`, `Loyal Customers`, `New customers`, `Potential Loyalists`, `Cannot Lose Them`, `At Risk`, `Hibernating`, `Wholesale Key Accounts`, `General Customers`). |

---

### `v_rfm_dashboard_summary` (View)
Pre-aggregated summary view designed for high-performance consumption by BI reporting tools (Power BI / Tableau).

| Column Name | Data Type | Description & Transformation Rule |
| :--- | :--- | :--- |
| `customer_segment` | Varchar | High-level customer persona category. |
| `total_customers` | BigInt | Total count of unique users assigned to the segment (`COUNT(user_id)`). |
| `pct_customers` | Numeric | Percentage of the total customer base represented by the segment (`ROUND(COUNT * 100.0 / SUM, 2)`). |
| `total_revenue` | Numeric | Aggregate monetary spend generated by all customers in the segment (`SUM(monetary)`). |
| `pct_revenue` | Numeric | Percentage of total business revenue contributed by the segment. |
| `avg_monetary_spend` | Numeric | Average revenue generated per customer within the segment (`AVG(monetary)`). |
| `avg_recency_days` | Numeric | Average recency in days for customers in the segment (`AVG(recency_days)`). |
| `avg_frequency` | Numeric | Average number of purchase sessions per customer in the segment (`AVG(frequency)`). |