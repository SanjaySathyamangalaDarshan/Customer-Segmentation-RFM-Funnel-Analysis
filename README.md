# Customer Segmentation (RFM) & Funnel Drop-off Analysis (E-Commerce)

## Business Context & Problem Statement

**Business Question:**
A multi-category online electronics and appliances store operates with a limited retention budget. Which user segments generate the most revenue, and at which funnel stage (`view` → `cart` → `purchase`) and within which product categories are we losing the most valuable users?

**Primary Goal:**
Recommend **one specific user segment to target** and **one funnel stage to optimize**, with an estimated recoverable revenue figure based on stated assumptions, to guide retention spending.

## Dataset

- **Source:** eCommerce behavior data from multi category store (Kaggle, by Michael Kechinov), provided by REES46 Marketing Platform.
- **Period:** October 2019 (one month).
- **Size:** 42.4M raw event records.
- **Structure:** One row = one event (a user acting on a product at a specific time). Event types include `view`, `cart`, and `purchase`; any others are documented during data profiling.

## Scope & Data Limitations

- **Temporal window:** The data covers strictly one month. Activity before this period is not visible, so "new" users may include returning customers, and true long-term purchase frequency is understated.
- **Segment handling:** Users who never completed a purchase are excluded from standard RFM scoring (they have no Monetary value) but are kept in the funnel analysis as a distinct "Never Purchased" group.
- **Financial metric:** Recommendations are evaluated on gross revenue impact only, because product costs and profit margins are not present in the event data.

## Tools

PostgreSQL (SQL: CTEs, window functions) · Excel (pivot cross-check) · Power BI (dashboard)

## Project Structure

```
/docs       Messy-Middle log, data dictionary
/powerbi    Dashboard (.pbix) and screenshots
/sql        SQL scripts, run in order
```
The raw dataset is not tored in this repo becuase of its size. Download it from the source linked above.

## Messy-Middle Log

See `docs/messy_middle_log.md` for assumptions, mistakes caught, and trade-offs made during the analysis.