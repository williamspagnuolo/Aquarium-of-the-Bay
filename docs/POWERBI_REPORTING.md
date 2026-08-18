# Power BI Reporting

**Document Owner:** Data Engineering  
**Last Updated:** August 2026  
**Related Documents:**
- PIPELINE_ARCHITECTURE.md
- DATA_MODEL.md
- DATA_QUALITY.md
- OPERATIONS.md
- ../ai_assistant/README.md

---

# Overview

The Aquarium reporting environment is built around a centralized reporting layer implemented in Google BigQuery.

Rather than allowing Power BI to query normalized warehouse tables directly, all dashboard visuals consume approved reporting views that encapsulate business logic, calculations, filtering rules, and reporting definitions.

This architecture provides a single source of truth for business metrics while simplifying report development and reducing duplicated logic across dashboards.

The same reporting layer also serves as the foundation for the Aquarium Analytics Assistant, ensuring that conversational analytics and traditional dashboard reporting produce consistent results.

---

# Reporting Architecture

```
                    Rocket Rez API
                           │
                           ▼
                    Cloud Run Ingestion
                           │
                           ▼
                 BigQuery Warehouse Tables
                           │
                           ▼
                 BigQuery Reporting Views
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
        Power BI Dashboard      AI Reporting Views
                                          │
                                          ▼
                          Aquarium Analytics Assistant
```

The reporting layer acts as the semantic boundary between the warehouse and reporting tools.

Neither Power BI nor the Analytics Assistant performs business calculations directly against normalized warehouse tables.

---

# Why Reporting Views?

Centralizing reporting logic within BigQuery provides several advantages.

## Consistent Business Definitions

Business rules are implemented once.

Examples include:

- Revenue calculations
- Visitor counts
- Membership reporting
- Ticket categorization
- Status filtering
- Date handling

Every downstream consumer receives identical results.

---

## Simplified Dashboards

Power BI visuals require minimal transformation.

Most visuals simply aggregate or display pre-defined metrics rather than recreating complex SQL logic inside Power Query or DAX.

Benefits include:

- Simpler report maintenance
- Faster development
- Easier onboarding
- Lower risk of inconsistent calculations

---

## Reusable Business Logic

Reporting views are reusable across multiple consumers.

Current consumers include:

- Power BI
- Aquarium Analytics Assistant
- BigQuery SQL
- Future reporting tools

Business rules therefore exist in one location rather than being duplicated across applications.

---

# Reporting Layers

The reporting environment consists of two logical layers.

```
Warehouse Tables

        │

        ▼

Reporting Views

        │

        ├────────► Power BI

        │

        └────────► AI Reporting Views

                        │

                        ▼

               Analytics Assistant
```

The reporting views remain the authoritative source for business metrics.

---

# Reporting Categories

The reporting layer is organized into several functional categories.

---

## Revenue Reporting

Purpose:

Track revenue generated through ticket sales.

Representative views include:

- vw_monthly_revenue_by_ticket_type
- vw_revenue_by_sales_channel
- vw_average_daily_revenue
- vw_median_daily_revenue
- vw_total_revenue_per_visitor

These views calculate revenue using approved ticket line items while excluding cancelled, voided, and returned transactions.

---

## Attendance Reporting

Purpose:

Measure guest visitation.

Representative views include:

- vw_monthly_headcount_by_ticket_type
- vw_visitor_count_by_sales_channel
- vw_thirty_day_headcount
- vw_yesterdays_tickets_sold

Attendance metrics are based on scheduled visit dates rather than purchase dates.

---

## Transaction Reporting

Purpose:

Measure purchasing behavior.

Representative views include:

- vw_transactions_daily_average
- vw_transactions_daily_median
- vw_transactions_value_average
- vw_transactions_value_median
- vw_refund_void_rate

These metrics support operational and financial reporting.

---

## Membership Reporting

Purpose:

Track Aquarium membership activity.

Representative views include:

- vw_membership_summary
- vw_membership_tabular

These views distinguish between:

- New memberships
- Renewals
- Membership revenue

Volunteer and employee memberships are excluded from revenue reporting.

---

# Business Rules

Every reporting view applies standardized business rules.

Examples include:

- Consistent order status filtering
- Approved ticket categories
- Revenue definitions
- Membership classification
- Sales channel naming
- Timezone handling

Centralizing these rules eliminates discrepancies between reports.

---

# Reporting Year Strategy

Most reporting views are designed as annual reporting snapshots.

The reporting year is intentionally fixed within the SQL definition.

Example:

```
DATE(created_date, "America/Los_Angeles")
    >= DATE '2026-01-01'

DATE(created_date, "America/Los_Angeles")
    < DATE '2027-01-01'
```

At the beginning of each calendar year, these date boundaries are updated to the next reporting year.

Maintaining fixed annual windows preserves historical dashboard consistency throughout the reporting year.

Dynamic operational views (such as yesterday's attendance or rolling thirty-day headcount) continue to use relative dates and do not require annual updates.

---

# Timezone Strategy

Reporting uses two different business dates.

## Transaction Date

Derived from:

```
orders.created_date
```

Converted from UTC into:

```
America/Los_Angeles
```

Used for:

- Revenue
- Transactions
- Membership sales

---

## Visit Date

Derived from:

```
event.schedule.date
```

Used for:

- Attendance
- Headcount
- Operational reporting

Separating transaction and visit dates prevents advance ticket purchases from being attributed to incorrect attendance periods.

---

# Reporting Consistency

One design objective of the platform is that every reporting interface returns the same business answer.

For example:

```
Power BI

Ticket Revenue

↓

$1,334,975.22
```

must match

```
Analytics Assistant

"How much ticket revenue was made in Q1 of 2026?"

↓

$1,334,975.22
```

To achieve this consistency, the Analytics Assistant is instructed to use reporting views whenever an equivalent metric exists rather than reconstructing calculations from warehouse tables.

---

# Power BI Data Model

Power BI connects only to approved reporting views.

```
BigQuery Warehouse

        │

        ▼

Reporting Views

        │

        ▼

Power BI Semantic Model

        │

        ▼

Dashboard Visuals
```

This minimizes Power BI transformations while ensuring all dashboards consume standardized business metrics.

---

# AI Alignment

The reporting layer also serves as the semantic foundation for conversational analytics.

The AI assistant has access to AI-specific views that either:

- mirror reporting views, or
- safely expose warehouse data after masking sensitive information.

Whenever possible, the AI assistant is instructed to answer business questions using trusted reporting views to ensure alignment with Power BI.

---

# Benefits

The reporting architecture provides several operational advantages.

- Centralized business logic
- Consistent KPI definitions
- Reduced Power BI complexity
- Easier report maintenance
- Faster dashboard development
- Trusted conversational analytics
- Improved data governance
- Simplified onboarding for future engineers

---

# Reporting Principles

The reporting layer was designed around the following principles.

- Compute business logic once.
- Expose trusted metrics through views.
- Keep Power BI simple.
- Keep AI consistent with dashboards.
- Separate transactional data from reporting logic.
- Standardize business definitions.
- Preserve historical reporting accuracy.

These principles allow Power BI and the Aquarium Analytics Assistant to operate from the same trusted reporting layer while minimizing duplicated logic and improving long-term maintainability.