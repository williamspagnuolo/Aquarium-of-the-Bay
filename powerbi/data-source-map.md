# Power BI Data Source Map

**Document Owner:** Data Engineering  
**Last Updated:** August 2026

---

# Overview

This document maps Power BI dashboard metrics to the underlying BigQuery reporting views.

Rather than querying normalized warehouse tables directly, dashboard visuals consume curated reporting views that encapsulate business logic and KPI definitions.

This mapping serves as a reference for report development, troubleshooting, and future maintenance.

---

# Revenue Reporting

| Dashboard Metric | BigQuery View |
|-----------------|---------------|
| Monthly Revenue by Ticket Type | `vw_monthly_revenue_by_ticket_type` |
| Revenue by Sales Channel | `vw_revenue_by_sales_channel` |
| Average Daily Revenue | `vw_average_daily_revenue` |
| Median Daily Revenue | `vw_median_daily_revenue` |
| Revenue per Visitor | `vw_total_revenue_per_visitor` |

---

# Attendance Reporting

| Dashboard Metric | BigQuery View |
|-----------------|---------------|
| Monthly Headcount by Ticket Type | `vw_monthly_headcount_by_ticket_type` |
| Visitor Count by Sales Channel | `vw_visitor_count_by_sales_channel` |
| Yesterday's Tickets Sold | `vw_yesterdays_tickets_sold` |
| Seven Day Headcount | `vw_seven_day_headcount` |
| Thirty Day Headcount | `vw_thirty_day_headcount` |

---

# Transaction Reporting

| Dashboard Metric | BigQuery View |
|-----------------|---------------|
| Average Daily Transactions | `vw_transactions_daily_average` |
| Median Daily Transactions | `vw_transactions_daily_median` |
| Average Transaction Value | `vw_transactions_value_average` |
| Median Transaction Value | `vw_transactions_value_median` |
| Refund / Void Rate | `vw_refund_void_rate` |

---

# Membership Reporting

| Dashboard Metric | BigQuery View |
|-----------------|---------------|
| Membership Summary | `vw_membership_summary` |
| Membership Details | `vw_membership_tabular` |

---

# Reporting Principles

Every Power BI visual should retrieve business metrics from approved reporting views rather than normalized warehouse tables.

Advantages include:

- Centralized business logic
- Consistent KPI definitions
- Simplified report development
- Easier maintenance
- Alignment with the Aquarium Analytics Assistant

---

# Troubleshooting

When dashboard values appear incorrect:

1. Execute the underlying reporting view in BigQuery.
2. Compare results with Power BI.
3. Verify the reporting year boundaries.
4. Confirm dataset refresh completion.
5. Review upstream transformation and validation logs.

Since business logic is centralized in BigQuery, discrepancies should be investigated within the reporting views before modifying Power BI.