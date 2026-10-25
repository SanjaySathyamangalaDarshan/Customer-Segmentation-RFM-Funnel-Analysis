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

---

### `user_stages` (Staging Table)
User-level behavioral summary table grouping unique human shoppers (`bot_status = 'not_suspected_bot'`) to condense raw multi-click event logs into single-row indicator flags.

| Column Name | Data Type | Description & Transformation Rule |
| :--- | :--- | :--- |
| `user_id` | BigInt | Unique identifier for the customer/user account. |
| `had_view` | Boolean | Boolean flag (`BOOL_OR`) indicating whether the user performed at least one `view` event. |
| `had_cart` | Boolean | Boolean flag (`BOOL_OR`) indicating whether the user performed at least one `cart` event. |
| `had_purchase` | Boolean | Boolean flag (`BOOL_OR`) indicating whether the user performed at least one `purchase` event. |

---

### `v_overall_funnel` (Database View)
Aggregates unique user volume across sequential e-commerce funnel stages (`view` , `cart` , `purchase via cart`), calculating conversion and drop-off rates.

| Column Name | Data Type | Description & Transformation Rule |
| :--- | :--- | :--- |
| `funnel_stage` | Varchar | Descriptive name of the funnel progression step (`1. View`, `2. Cart`, `3. Purchase (via cart)`). |
| `users` | BigInt | Total unique human users reaching that specific funnel stage. |
| `pct_of_start` | Numeric | Conversion percentage relative to the initial viewer base (`100.0` baseline). |
| `pct_of_previous` | Numeric | Conversion percentage relative to the immediately preceding funnel stage. |
| `drop_off_pct` | Numeric | Percentage of users lost at the transition from the previous stage. |

---

### `v_user_paths` (Database View)
Classifies every unique viewer into distinct behavioral pathways to uncover cart-skip behaviors (e.g., instant/direct checkouts bypassing the cart event).

| Column Name | Data Type | Description & Transformation Rule |
| :--- | :--- | :--- |
| `user_path` | Varchar | Categorized behavioral trajectory: `1. Viewed only`, `2. Cart abandoned (no purchase)`, `3a. Cart, then purchase`, or `3b. Purchase without cart`. |
| `users` | BigInt | Total unique users falling into that specific behavioral path category. |
| `pct_of_viewers` | Numeric | Percentage proportion of each user path relative to all unique viewers. |
---

### `user_category_stages` (Table)
Aggregates user-level event stages per product category to enable multi-dimensional funnel analysis.

| Column Name | Data Type | Description & Transformation Rule |
| :--- | :--- | :--- |
| `user_id` | BigInt | Unique identifier for the customer account. |
| `category_code` | Varchar | Hierarchical category string (missing values imputed as `'uncategorized'`). |
| `had_view` | Boolean | `TRUE` if the user performed at least one `view` event in this category. Derived via `BOOL_OR(event_type = 'view')`. |
| `had_cart` | Boolean | `TRUE` if the user performed at least one `cart` event in this category. Derived via `BOOL_OR(event_type = 'cart')`. |
| `had_purchase` | Boolean | `TRUE` if the user performed at least one `purchase` event in this category. Derived via `BOOL_OR(event_type = 'purchase')`. |


---

### `v_funnel_by_category` (Database View)
Provides category-level conversion metrics, stage-by-stage drop-off rates, and cart-abandonment percentages.

| Column Name | Data Type | Description & Transformation Rule |
| :--- | :--- | :--- |
| `category_code` | Varchar | Product category group. Filtered to categories with $\ge 1,000$ viewers to eliminate low-sample noise. |
| `viewers` | BigInt | Count of unique users viewing products in this category (`COUNT(*) FILTER (WHERE had_view)`). |
| `carters` | BigInt | Count of unique users adding items to cart in this category (`had_view AND had_cart`). |
| `cart_buyers` | BigInt | Count of unique users who carted and completed a purchase in this category (`had_view AND had_cart AND had_purchase`). |
| `purchasers` | BigInt | Total unique purchasers in this category (`had_view AND had_purchase`), including direct buy-now users. |
| `view_to_cart_pct` | Numeric | Conversion rate from View to Cart stage: `ROUND(100.0 * carters / viewers, 2)`. |
| `cart_to_purchase_pct` | Numeric | Conversion rate from Cart to Purchase stage: `ROUND(100.0 * cart_buyers / carters, 2)`. Evaluates to `NULL` for categories with 0 carters. |
| `cart_abandon_pct` | Numeric | Percentage of carters who abandoned without purchasing in this category: `ROUND(100.0 * (carters - cart_buyers) / carters, 2)`. |
| `overall_conversion_pct` | Numeric | Overall conversion rate from View to Purchase stage: `ROUND(100.0 * purchasers / viewers, 2)`. |

---

### `user_price_stages` (Table)
Groups user interactions into data-driven price bands anchored on historical price percentiles 

| Column Name | Data Type | Description & Transformation Rule |
| :--- | :--- | :--- |
| `user_id` | BigInt | Unique identifier for the customer account. |
| `price_band` | Varchar | Categorical price band: `'1. Under 65'`, `'2. 65 to 164.99'`, `'3. 165 to 359.99'`, or `'4. 360 and above'`. |
| `had_view` | Boolean | `TRUE` if the user performed a `view` event on an item within this price band. |
| `had_cart` | Boolean | `TRUE` if the user performed a `cart` event on an item within this price band. |
| `had_purchase` | Boolean | `TRUE` if the user performed a `purchase` event on an item within this price band. |

---

### `v_funnel_by_price_band` (Database View)
Aggregates stage conversion rates and cart abandonment volumes grouped by price band.

| Column Name | Data Type | Description & Transformation Rule |
| :--- | :--- | :--- |
| `price_band` | Varchar | Price tier identifier. |
| `viewers` | BigInt | Count of unique users viewing items in this price band. |
| `carters` | BigInt | Count of unique users adding items to cart in this price band. |
| `cart_buyers` | BigInt | Count of unique users who carted and purchased within this price band. |
| `purchasers` | BigInt | Total unique purchasers within this price band. |
| `view_to_cart_pct` | Numeric | Percentage of viewers adding items to cart in this price band. |
| `cart_to_purchase_pct` | Numeric | Percentage of carters completing a purchase within this price band. |
| `cart_abandon_pct` | Numeric | Abandonment rate for users who carted within this price band. |
| `overall_conversion_pct` | Numeric | Net conversion rate from view to purchase within this price band. |

---

### `v_segment_purchase_path` (Database View)
Maps purchase path mechanics (cart vs. direct buy-now) across customer loyalty segments by joining `rfm_segments` with `user_stages`.

| Column Name | Data Type | Description & Transformation Rule |
| :--- | :--- | :--- |
| `customer_segment` | Varchar | RFM segment label (e.g., `'Hibernating'`, `'Champions'`, `'At Risk'`). |
| `buyers` | BigInt | Total count of distinct purchasing customers in this RFM segment. |
| `bought_via_cart` | BigInt | Count of buyers who had at least one cart event (`COUNT(*) FILTER (WHERE u.had_cart)`). |
| `bought_without_cart` | BigInt | Count of buyers who purchased directly without a cart event (`COUNT(*) FILTER (WHERE NOT u.had_cart)`). |
| `pct_skip_cart` | Numeric | Percentage of buyers who skipped the cart: `ROUND(100.0 * bought_without_cart / buyers, 1)`. |

---

### Total Population Sizing 
Quantifies the complete user population, bridging active RFM buyer segments with non-purchasing visitors.

| Column / Segment Name | Data Type | Description & Sizing Context |
| :--- | :--- | :--- |
| `segment` | Varchar | Segment classification. Non-purchasing users are labeled as `'Never Purchased'` via `COALESCE(s.customer_segment, 'Never Purchased')`. |
| `users` | BigInt | Total distinct user count per segment. |

> 