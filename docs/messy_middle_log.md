# Messy Middle Decision Log

| Date | What I Expected | What I Found | Why It Matters | What I Did |
| :--- | :--- | :--- | :--- | :--- |
| **2026-10-12** | Loading a 5.7 GB CSV into PostgreSQL seamlessly. | High-volume CSV files require batch bulk loading (`COPY` command) to prevent memory crashes. | Large datasets can easily break local SQL tooling if not loaded via efficient command-line utilities. | Created `rfm_funnel_project` DB, bulk-loaded 42.4M rows into `raw_events`, and initialized GitHub repo structure. |