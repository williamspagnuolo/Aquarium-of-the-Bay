# Power BI Reporting

**Document Owner:** Data Engineering  
**Last Updated:** August 2026  
**Related Documents:**
- ../docs/PIPELINE_ARCHITECTURE.md
- ../docs/DATA_MODEL.md
- ../docs/POWERBI_REPORTING.md

---

# Overview

This directory documents the Power BI reporting layer for the Aquarium Data Engineering Platform.

Power BI serves as the primary business intelligence tool used to visualize operational and financial metrics derived from the Rocket Rez reservation system.

Rather than querying normalized warehouse tables directly, Power BI connects exclusively to approved reporting views in BigQuery. This architecture centralizes business logic within the data warehouse, ensuring that all dashboards use consistent calculations and KPI definitions.

The same reporting views also serve as the foundation for the Aquarium Analytics Assistant, allowing conversational analytics to return answers that align with executive dashboards whenever equivalent reporting views exist.

---

# Reporting Architecture

```
Rocket Rez API

        │

        ▼

Cloud Run Ingestion

        │

        ▼

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

---

# Reporting Philosophy

Business logic is intentionally implemented within BigQuery rather than Power BI.

This approach provides several benefits:

- Centralized business rules
- Consistent KPI definitions
- Reduced Power BI complexity
- Easier maintenance
- Faster dashboard development
- Simplified onboarding for future engineers

Power BI is therefore responsible for visualization rather than business calculations.

---

# Dashboard Categories

The current reporting environment includes dashboards covering:

## Revenue

- Revenue by Ticket Type
- Revenue by Sales Channel
- Daily Revenue
- Revenue per Visitor

---

## Attendance

- Visitor Counts
- Daily Headcount
- Monthly Headcount
- Attendance by Ticket Type

---

## Transactions

- Daily Transactions
- Transaction Value
- Refund/Void Rate

---

## Memberships

- Membership Sales
- Membership Revenue
- Membership Renewals

---

# Data Sources

Each dashboard visual consumes one or more approved BigQuery reporting views.

The relationship between Power BI reports and their underlying data sources is documented in:

```
DATA_SOURCE_MAP.md
```

---

# Annual Maintenance

Most reporting views represent a fixed reporting year.

Near the beginning of each calendar year:

- Update reporting year boundaries within annual views.
- Refresh Power BI datasets.
- Validate January reporting.
- Verify dashboard totals against Rocket Rez.

Rolling operational reports (Yesterday, Last 7 Days, Last 30 Days) remain dynamic and do not require annual modification.

---

# Relationship to the AI Assistant

The Aquarium Analytics Assistant has been designed to mirror Power BI whenever possible.

When an equivalent reporting view exists, the assistant is instructed to query the reporting layer instead of reconstructing calculations from warehouse tables.

This approach ensures that business users receive consistent answers regardless of whether information is accessed through Power BI or conversational analytics.