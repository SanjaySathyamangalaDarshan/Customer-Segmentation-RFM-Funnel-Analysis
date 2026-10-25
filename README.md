# Customer Segmentation (RFM) & Funnel Drop-off Analysis (E-Commerce)

> **Status:** Analysis complete (SQL funnel, RFM segmentation, hypothesis test). Excel cross-check, Power BI dashboard, and final recommendation are in progress.

## Business Context & Problem Statement

**Business Question:**
A multi-category online electronics and appliances store operates with a limited retention budget. Which user segments generate the most revenue, and at which funnel stage (`view` → `cart` → `purchase`) and within which product categories are we losing the most valuable users?

**Primary Goal:**
Recommend **one specific user segment to target** and **one funnel stage to optimize**, with an estimated recoverable revenue figure based on stated assumptions, to guide retention spending.

## Core Project Hypothesis

**Hypothesis:** At Risk and Cannot Lose Them buyers are a higher-value, more efficient retention target per contact than Hibernating buyers. Hibernating is the largest segment, but it may partly reflect the one-month data window.

**Status:** Tested. Verdict: **partly supported**. At Risk + Cannot Lose Them are worth about 1.4 times more per contact than Hibernating at equal response rates, but a small response-rate difference could erase the advantage. Full evidence: [`docs/hypothesis_verdict.md`](docs/hypothesis_verdict.md).

### Hypothesis Verdict

I tested whether our high-value slipping customers (*At Risk* and *Cannot Lose Them*) showed higher browsing recency and greater value per contact than dormant *Hibernating* users. While activity recency was surprisingly close across both cohorts, the target segment delivered a 40.1% higher average order value (420.94 vs. 300.53) and superior revenue per touchpoint, revealing a massive trade-off against a site-wide cart-abandonment pool of 134,320 users. However, historical event logs cannot reveal true customer intent or actual email response rates, meaning the true effectiveness of these win-back strategies must be validated through live A/B testing.

## Key Findings (so far)

- **Funnel:** 3,020,723 viewers, 336,961 carted, 202,739 bought via the cart. 41.6% of buyers have no cart event, so the strict funnel shows 6.71% conversion while about 11.5% of viewers actually bought.
- **Segments:** Hibernating is the largest segment (45% of buyers, 23.8% of revenue) but partly reflects the one-month window. Champions are 4% of buyers and 20.9% of revenue. 348 wholesale-like accounts bring 6.3% of revenue.
- **Two recovery levers:** At Risk + Cannot Lose Them (12,863 buyers) are the best target per contact, and 134,320 cart abandoners hold about 2.2M at a 5% recovery rate.
- **Final recommendation:** to be added after the dashboard.

## Dataset

- **Source:** eCommerce behavior data from multi category store (Kaggle, by Michael Kechinov), provided by REES46 Marketing Platform.
- **Period:** October 2019 (one month).
- **Size:** 42.4M raw event records.
- **Structure:** One row = one event (a user acting on a product at a specific time). Event types include `view`, `cart`, and `purchase`; any others are documented during data profiling.

## Scope & Data Limitations

- **Temporal window:** The data covers strictly one month. Activity before this period is not visible, so "new" users may include returning customers, and true long-term purchase frequency is understated.
- **Segment handling:** Users who never completed a purchase are excluded from standard RFM scoring (they have no Monetary value) but are kept in the funnel analysis as a distinct "Never Purchased" group.
- **Financial metric:** Recommendations are evaluated on gross revenue impact only, because product costs and profit margins are not present in the event data.
- **Category data:** A large share of events has no category code. These are labelled `uncategorized` and form the largest group (about 1.5M viewers), so category-level findings cover only the rest of the store.
- **Cart tracking:** 41.6% of buyers have no cart event, and apparel has no cart events at all. The data can't say why (a buy-now path, carts created before October, or tracking gaps), so both the strict funnel and the user-path breakdown are reported.
- **Device and channel:** The dataset has no device or channel columns, so the funnel is split by product category instead.

## Tools

PostgreSQL (SQL: CTEs, window functions) · Excel (pivot cross-check) · Power BI (dashboard)

## Project Structure

```
/docs       Messy-Middle log, data dictionary, hypothesis verdict
/powerbi    Dashboard (.pbix) and screenshots
/sql        SQL scripts, run in order
```
The raw dataset is not stored in this repo becuase of its size. Download it from the link (https://www.kaggle.com/datasets/mkechinov/ecommerce-behavior-data-from-multi-category-store?select=2019-Oct.csv)

## Messy-Middle Log

See [`docs/messy_middle_log.md`](docs/messy_middle_log.md) for assumptions, mistakes caught, and trade-offs made during the analysis.

