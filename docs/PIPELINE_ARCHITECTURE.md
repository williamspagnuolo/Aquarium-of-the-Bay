# Pipeline Architecture

## Overview

The Aquarium Data Engineering Platform is an end-to-end analytics pipeline built on Google Cloud Platform that automates the ingestion, transformation, validation, and reporting of ticketing data from the Rocket Rez reservation system.

The platform was designed to provide a reliable, maintainable, and scalable analytics environment that minimizes manual intervention while ensuring reporting consistency across Power BI dashboards and the Aquarium Analytics Assistant.

At a high level, the platform performs the following operations:

1. Retrieves ticketing data from the Rocket Rez REST API.
2. Stores the raw API response in BigQuery.
3. Archives historical API responses.
4. Normalizes nested JSON into relational tables.
5. Performs data quality validation.
6. Creates trusted reporting views.
7. Serves Power BI dashboards.
8. Serves the Gemini-powered Analytics Assistant.

---

# High-Level Architecture

```
                        Rocket Rez API
                               │
                               │
                               ▼
                     Cloud Run Ingestion Service
                               │
                               ▼
                      BigQuery raw_data table
                               │
                               ▼
                  BigQuery raw_data_history table
                               │
                               ▼
               Google Cloud Workflow Orchestration
                               │
          ┌──────────────┬──────────────┬──────────────┬──────────────┐
          ▼              ▼              ▼              ▼
       orders      line_items    primary_contact      event
          │              │              │              │
          └──────────────┴──────────────┴──────────────┘
                               │
                               ▼
                     Data Validation Layer
                               │
                               ▼
                          audit_log
                               │
                               ▼
                  Trusted Reporting Views
                               │
                ┌──────────────┴──────────────┐
                ▼                             ▼
          Power BI Reports            AI Reporting Views
                                              │
                                              ▼
                               Streamlit + Gemini Analytics Assistant
```

---

# Pipeline Components

## 1. Rocket Rez API

The source system for the platform is Rocket Rez, which provides ticketing and reservation data through a REST API.

The ingestion service requests data using configurable date ranges and pagination.

Typical request parameters include:

- `startDate`
- `endDate`
- `pageIndex`
- `pageSize`

The API returns nested JSON containing:

- Orders
- Line Items
- Events
- Contacts
- Memberships
- Questions
- Payments
- Additional nested entities

The API returns timestamps in UTC while date filtering occurs using the Rocket Rez company timezone.

---

## 2. Cloud Run Ingestion

The ingestion service is implemented as a containerized Python application deployed to Google Cloud Run.

Responsibilities include:

- Authenticating with the Rocket Rez API
- Retrieving paginated API responses
- Handling API retries
- Loading raw JSON into BigQuery
- Logging execution status

The ingestion code is located in:

```
ingestion/
```

A separate notebook is included for manual historical backfills:

```
ingestion/main_backfill.ipynb
```

This notebook allows engineers to recover missing data by executing historical API requests for specific date ranges without modifying the automated pipeline.

---

## 3. Raw Data Storage

The ingestion service first loads each API response into:

```
rocket_rez_data.raw_data
```

This table represents the latest successful ingestion and is overwritten during each execution.

To preserve historical API responses, every ingestion is also appended into:

```
rocket_rez_data.raw_data_history
```

The history table serves several purposes:

- Historical reporting
- Auditability
- Data recovery
- Reprocessing
- Change tracking

Without the history table, changes made within Rocket Rez could permanently overwrite historical event information.

---

# Why raw_data_history Exists

Rocket Rez always returns the latest version of an order.

If an event is modified after purchase, the API no longer exposes the previous version.

Maintaining a historical append-only table allows the platform to preserve the original event information used for reporting and analysis.

---

## 4. Workflow Orchestration

Google Cloud Workflows orchestrates the transformation pipeline.

After ingestion completes successfully, the workflow executes a sequence of SQL transformations that normalize the nested JSON into relational tables.

The workflow performs:

1. Orders transformation
2. Line Item transformation
3. Primary Contact transformation
4. Event transformation
5. Validation
6. Audit logging

The workflow definition is located in:

```
orchestration/workflow.yaml
```

Separating orchestration from transformation logic simplifies maintenance while allowing individual pipeline stages to be rerun independently if necessary.

---

## 5. Relational Data Warehouse

The normalized warehouse consists of four primary reporting tables.

### orders

One row per Rocket Rez order.

Contains:

- order metadata
- transaction totals
- sales office
- salesperson
- timestamps
- status

Primary key:

```
order_id
```

---

### line_items

One row per purchased line item.

Contains:

- ticket products
- memberships
- retail items
- quantities
- prices
- discounts

References:

```
orders.order_id
```

---

### primary_contact

One row per order.

Contains customer information associated with the order.

Personally identifiable information is masked before becoming available to the AI reporting layer.

---

### event

One row per scheduled event.

Contains:

- event dates
- schedules
- visit times
- event metadata

This table enables reporting by visit date rather than purchase date.

---

## 6. Data Validation

Following transformation, validation queries verify the integrity of the warehouse.

Examples include:

- Duplicate primary keys
- Missing foreign keys
- Invalid timestamps
- Financial reconciliation
- Unexpected null values
- Duplicate business keys

Validation results are written to:

```
audit_log
```

Pipeline failures are surfaced immediately so data issues can be investigated before affecting downstream reporting.

---

## 7. Reporting Layer

Power BI connects exclusively to reporting views rather than directly querying normalized warehouse tables.

This provides several benefits:

- Centralized business logic
- Consistent KPI definitions
- Simplified Power BI models
- Reduced duplication
- Easier maintenance

Examples include:

- Monthly revenue
- Visitor counts
- Membership reporting
- Sales channel reporting
- Transaction metrics

The SQL definitions are stored in:

```
sql/reporting_views/
```

---

## 8. AI Reporting Layer

The Aquarium Analytics Assistant uses a separate semantic layer built specifically for natural language querying.

Rather than exposing raw warehouse tables, the assistant queries approved AI views located in:

```
rocket_rez_ai
```

These views:

- Mask personally identifiable information
- Restrict available columns
- Simplify joins
- Encourage consistent SQL generation
- Mirror trusted Power BI metrics whenever possible

This approach ensures that AI-generated answers remain consistent with production dashboard values.

---

# Security Architecture

Multiple layers of security protect the reporting environment.

## Identity

Access to the Analytics Assistant is controlled using Google Cloud Identity-Aware Proxy (IAP).

Only approved users can access the application.

---

## Data Access

The Cloud Run service account has read access only to approved AI reporting views.

The application cannot directly query protected source tables.

---

## SQL Validation

All SQL generated by Gemini is validated before execution.

The validator restricts:

- datasets
- views
- SQL operations

Only read-only queries against approved reporting views are permitted.

---

## Privacy

Customer personally identifiable information is excluded or masked before becoming available to the AI assistant.

Examples include:

- masked email addresses
- masked phone numbers
- removed names
- removed street addresses

---

# Operational Workflow

The platform executes in the following order:

1. Cloud Scheduler triggers the workflow.
2. Cloud Run retrieves Rocket Rez data.
3. Raw data is stored in BigQuery.
4. Historical archive is updated.
5. Warehouse tables are refreshed.
6. Validation executes.
7. Audit log is updated.
8. Reporting views automatically reflect refreshed data.
9. Power BI refreshes.
10. The Analytics Assistant immediately begins using the updated reporting layer.

---

# Repository Structure

```
ingestion/
    Cloud Run ingestion service
    Manual backfill notebook

orchestration/
    Google Cloud Workflow

sql/
    transformations/
    validation/
    reporting_views/
    ai_views/

powerbi/
    Power BI documentation

ai_assistant/
    Streamlit application
    Gemini integration
    SQL validator
    Deployment documentation

docs/
    Engineering documentation
```

---

# Design Goals

The platform was designed around several engineering principles:

- Automated daily operation
- Idempotent ingestion
- Separation of ingestion, transformation, and reporting
- Centralized business logic
- Consistent reporting across Power BI and AI
- Layered security
- Maintainability
- Recoverability through manual backfill
- Clear operational documentation

These principles allow the platform to support both traditional business intelligence reporting and conversational analytics while maintaining consistent business definitions across both interfaces.