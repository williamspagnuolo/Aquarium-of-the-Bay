# SQL Organization

**Document Owner:** Data Engineering  
**Last Updated:** August 2026  
**Related Documents:**
- ../docs/DATA_MODEL.md
- ../docs/DATA_QUALITY.md
- ../docs/POWERBI_REPORTING.md
- ../docs/OPERATIONS.md

---

# Overview

This directory contains all SQL used throughout the Aquarium Data Engineering Platform.

The SQL has been organized by functional purpose rather than execution order. This separation improves maintainability, simplifies troubleshooting, and clearly distinguishes between warehouse transformations, validation logic, reporting views, and AI-specific semantic views.

```
sql/
├── transformations/
├── validation/
├── reporting_views/
├── ai_views/
└── README.md
```

Each directory represents a different stage of the analytics platform.

---

# SQL Workflow

The SQL components are executed in the following logical order.

```
Rocket Rez API

        │

        ▼

Transformation SQL

        │

        ▼

Validation SQL

        │

        ▼

Reporting Views

        │

        ├────────► Power BI

        │

        └────────► AI Views

                        │

                        ▼

           Aquarium Analytics Assistant
```

---

# transformations/

## Purpose

Transformation queries convert nested Rocket Rez JSON into a normalized relational warehouse.

These scripts create and refresh the core warehouse tables used throughout the platform.

Examples include:

- orders
- line_items
- primary_contact
- event

Typical operations include:

- UNNEST()
- JOINs
- Window functions
- Surrogate key generation
- Deduplication
- Type casting
- Data normalization

These queries represent the core ELT layer of the platform.

---

# validation/

## Purpose

Validation queries verify warehouse integrity following transformation.

Examples include:

- Duplicate detection
- Primary key validation
- Foreign key validation
- Null value checks
- Financial reconciliation
- Business rule validation

Validation results determine whether refreshed data is suitable for downstream reporting.

Failures are recorded in the audit log before reports are refreshed.

---

# reporting_views/

## Purpose

Reporting views provide the semantic layer consumed by Power BI.

Rather than allowing Power BI to query normalized warehouse tables directly, business logic is centralized within these views.

Examples include:

Revenue

- Monthly Revenue by Ticket Type
- Revenue by Sales Channel
- Daily Revenue

Attendance

- Monthly Headcount
- Visitor Counts
- Rolling Headcount

Transactions

- Transaction Counts
- Transaction Value
- Refund/Void Rate

Memberships

- Membership Summary
- Membership Details

Each reporting object is stored in two forms:

- View Definition (`CREATE OR REPLACE VIEW`)
- Query Only (`SELECT` statement)

The query-only versions simplify development, testing, and code review.

---

# ai_views/

## Purpose

AI reporting views provide a controlled semantic layer for the Aquarium Analytics Assistant.

These views differ from reporting views because they are optimized for SQL generation by Gemini.

Characteristics include:

- Simplified joins
- Masked sensitive information
- Approved business columns
- Consistent naming
- Reduced SQL complexity

Whenever possible, AI reporting views mirror Power BI reporting metrics to ensure both interfaces return consistent business answers.

---

# archival/

## Purpose

Contains SQL used to preserve historical reporting states.

The quarterly dashboard snapshot script materializes all approved Power BI reporting views into permanent BigQuery tables at the end of each calendar quarter.

This allows historical dashboard results to remain reproducible even after live views or underlying source data change.

---

# SQL Development Standards

The following conventions are used throughout the repository.

## Formatting

- Uppercase SQL keywords
- Descriptive aliases
- Consistent indentation
- One logical clause per line

---

## Naming

Warehouse Tables

```
orders
line_items
primary_contact
event
```

Reporting Views

```
vw_monthly_revenue_by_ticket_type
```

AI Views

```
vw_orders
vw_line_items
```

---

## Business Logic

Business calculations should exist in only one location.

Avoid duplicating logic across:

- Power BI
- AI prompts
- Ad hoc SQL

Instead, create or update a reporting view.

---

# Date Handling

Transaction reporting uses:

```sql
DATE(created_date, "America/Los_Angeles")
```

Attendance reporting uses scheduled event dates.

Annual reporting views intentionally use fixed yearly reporting windows.

Rolling operational reports remain dynamic.

---

# Testing SQL

Before deploying changes:

1. Execute the query in BigQuery.
2. Validate row counts.
3. Compare totals with existing reports.
4. Verify duplicate handling.
5. Confirm expected NULL behavior.
6. Review validation queries.
7. Refresh reporting views.

---

# Deployment

SQL changes typically follow this sequence.

```
Develop

        │

        ▼

BigQuery Testing

        │

        ▼

Validation

        │

        ▼

Update Production View

        │

        ▼

Refresh Power BI

        │

        ▼

Verify AI Responses
```

---

# Guiding Principles

The SQL layer follows several design principles.

- Normalize once.
- Validate before publishing.
- Centralize business logic.
- Keep Power BI simple.
- Keep AI consistent.
- Preserve historical data.
- Prefer reusable reporting views.
- Document major business rules.

These principles help ensure that every reporting tool built on top of the warehouse returns consistent, trusted business metrics while remaining maintainable for future engineers.