# Aquarium of the Bay Analytics Platform

## Overview

This repository contains the reporting and analytics layer for the Aquarium of the Bay Analytics Platform.

The platform transforms operational ticketing data from the Rocket Rez reservation system into analytics-ready datasets that power executive dashboards in Power BI through a centralized semantic reporting layer implemented with BigQuery views. The same reporting layer also provides trusted data for the Aquarium Analytics Assistant, ensuring consistency between traditional dashboards and conversational analytics.

---

## Platform Highlights

- Fully automated cloud-based ELT pipeline
- Historical data preservation with append-only archive
- Normalized BigQuery data warehouse
- Centralized semantic reporting layer using BigQuery views
- Automated data quality validation
- Power BI executive dashboards
- Gemini-powered natural language analytics
- Secure deployment using Cloud Run and Identity-Aware Proxy (IAP)

---

# Core Technologies

- Google Cloud Platform (GCP)
- BigQuery
- Cloud Run
- Cloud Workflows
- SQL (GoogleSQL)
- Power BI
- GitHub

---

# Architecture

The analytics platform is built as an end-to-end ELT pipeline on Google Cloud Platform. Data is extracted from the Rocket Rez API, transformed into a normalized BigQuery warehouse, validated for quality, and exposed through reporting views that power both Power BI dashboards and AI-driven analytics.

```text
                     Rocket Rez API
                            │
                            ▼
                  Cloud Run Ingestion Job
                            │
                            ▼
                     BigQuery raw_data
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
     raw_data_history          BigQuery Transformation Pipeline
 (Historical Archive)                    │
                                         ▼
                              ┌─────────────────────────┐
                              │ orders                  │
                              │ line_items              │
                              │ primary_contact         │
                              │ event                   │
                              └─────────────────────────┘
                                         │
                                         ▼
                              Data Quality Validation
                                         │
                        ┌────────────────┴────────────────┐
                        ▼                                 ▼
              Analytics Reporting Views           AI Reporting Views
                        │                                 │
                        ▼                                 ▼
               Power BI Dashboards      Aquarium Analytics Assistant
                        │
                        ▼
                 Business Stakeholders
```

---

# Engineering Decisions

The platform includes Architecture Decision Records (ADRs) documenting the rationale behind key design choices.

| ADR | Description |
|-----|-------------|
| ADR-001 | Preserve historical API responses using `raw_data_history` |
| ADR-002 | Standardize transaction reporting using Pacific Time |
| ADR-003 | Centralize business logic in BigQuery reporting views |
| ADR-004 | Restrict AI queries to approved reporting views |

---

# Pipeline Overview

The platform follows a layered architecture designed to separate ingestion, transformation, validation, and reporting.

## 1. Data Extraction

A scheduled Cloud Run service retrieves transactional data from the Rocket Rez REST API and loads the most recent snapshot into the `raw_data` table.

This table represents the latest operational state of the source system.

---

## 2. Historical Archive

Before transformations occur, records are merged into `raw_data_history`.

Unlike `raw_data`, this table preserves **each version of an order** using the combination of **Order ID** and **Modified Date** as the business key.

This allows the platform to:

- Preserve historical event information
- Reproduce historical reports
- Recover from pipeline failures
- Audit changes over time

---

## 3. Data Transformation

The nested Rocket Rez JSON payload is normalized into four core warehouse tables:

- **orders** – One record per transaction
- **line_items** – Purchased tickets, memberships, products, and packages
- **primary_contact** – Customer information
- **event** – Scheduled visit information

This normalized design simplifies reporting while preserving relationships between business entities.

---

# Data Validation

Every transformation stage includes automated validation before data is considered analytics-ready.

Validation includes:

- Primary key uniqueness
- Duplicate detection
- Referential integrity
- Financial reconciliation
- Status validation
- Required field validation
- Surrogate key validation

Validation results are written to an audit table, and critical failures halt the pipeline before reporting views are refreshed.

This validation layer ensures that only trusted, internally consistent data is exposed to downstream reporting tools.

---

# Reporting Layer

Power BI does not query transactional warehouse tables directly.

Instead, dashboards consume curated BigQuery reporting views that:

- Centralize business logic
- Simplify report development
- Improve query performance
- Provide consistent KPI definitions
- Isolate reports from warehouse schema changes

Each reporting object in this repository is stored in two forms.

### View Definition

Contains the complete `CREATE OR REPLACE VIEW` statement used in production.

### Query Only

Contains only the `SELECT` statement, making the business logic easier to read, review, and test.

---

# Available Reporting Views

The reporting layer currently includes views for:

## Revenue

- Monthly Revenue by Ticket Type
- Revenue by Sales Channel
- Average Daily Revenue
- Median Daily Revenue
- Total Revenue per Visitor

## Transactions

- Average Daily Transactions
- Median Daily Transactions
- Average Transaction Value
- Median Transaction Value
- Refund / Void Rate

## Attendance

- Monthly Headcount by Ticket Type
- Visitor Count by Sales Channel
- Yesterday's Tickets Sold
- Seven Day Headcount
- Thirty Day Headcount

## Memberships

- Membership Summary
- Membership Tabular

---

# Power BI

Power BI connects directly to approved reporting views in BigQuery rather than normalized warehouse tables.

This architecture provides:

- Minimal transformation within Power BI
- Centralized SQL maintenance
- Consistent KPI definitions
- Faster report development
- Improved maintainability

Business logic is implemented once within BigQuery, allowing every dashboard to consume the same trusted metrics.

---

# Date Handling

One of the key architectural decisions within the platform is the consistent use of the Aquarium's local timezone.

Revenue and transaction reporting use:

```sql
DATE(created_date, "America/Los_Angeles")
```

instead of UTC.

Attendance reporting uses scheduled event dates rather than purchase dates.

Most annual reporting views intentionally use fixed yearly reporting windows (for example, January 1 through December 31). These windows are updated once each year after financial reporting has closed, preserving historical dashboard consistency.

Rolling operational reports (Yesterday, Last 7 Days, Last 30 Days) remain fully dynamic.

---

# Repository Structure

```text
.
├── ai_assistant/
│   ├── README.md
│   ├── DEPLOYMENT.md
│   ├── app.py
│   ├── schema_context.py
│   ├── sql_validator.py
│   └── ...
│
├── ingestion/
│   ├── main.py
│   ├── main_backfill.ipynb
│   └── ...
│
├── orchestration/
│   └── workflow.yaml
│
├── sql/
│   ├── transformations/
│   ├── validation/
│   ├── reporting_views/
│   └── ai_views/
│
├── powerbi/
│
├── docs/
│   ├── PIPELINE_ARCHITECTURE.md
│   ├── DATA_MODEL.md
│   ├── DATA_QUALITY.md
│   ├── POWERBI_REPORTING.md
│   ├── OPERATIONS.md
│   ├── PROJECT_HISTORY.md
│   └── decisions/
│       ├── ADR-001-raw-data-history.md
│       ├── ADR-002-pacific-time-reporting.md
│       ├── ADR-003-reporting-views.md
│       └── ADR-004-ai-reporting-layer.md
│
└── README.md
```

---

# Repository Documentation

The repository includes comprehensive engineering documentation covering every major component of the platform.

| Document | Description |
|----------|-------------|
| `PIPELINE_ARCHITECTURE.md` | End-to-end cloud architecture and data flow |
| `DATA_MODEL.md` | Warehouse schema and normalization strategy |
| `DATA_QUALITY.md` | Validation framework and quality controls |
| `POWERBI_REPORTING.md` | Reporting architecture and semantic reporting layer |
| `OPERATIONS.md` | Operational procedures, deployment, and maintenance |
| `PROJECT_HISTORY.md` | Evolution of the platform over time |
| `docs/decisions/` | Architecture Decision Records (ADRs) |
| `ai_assistant/README.md` | Aquarium Analytics Assistant architecture |
| `ai_assistant/DEPLOYMENT.md` | AI deployment procedures |

---

# Repository Creator

**William Spagnuolo**

Data Science Intern  
Aquarium of the Bay
October 2025 - August 2026

M.S. Data Science  
University of San Francisco
