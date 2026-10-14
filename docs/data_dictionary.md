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