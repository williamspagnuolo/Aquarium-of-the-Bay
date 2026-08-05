# Aquarium of the Bay Analytics Platform

## Overview

This repository contains the reporting layer for the Aquarium of the Bay analytics platform.

The project transforms operational ticketing data from the Rocket Rez reservation system into analytics-ready datasets that power executive dashboards in Power BI and provide a semantic layer for future AI-powered business intelligence applications.

The reporting layer sits on top of a normalized BigQuery data warehouse that is populated through an automated Google Cloud ETL pipeline.

---

# Technology Stack

- Google Cloud Platform (GCP)
- BigQuery
- Cloud Run
- Cloud Workflows
- SQL (GoogleSQL)
- Power BI
- GitHub

---

# Architecture

The analytics platform is built as an end-to-end ELT pipeline on Google Cloud Platform. Data is extracted from the Rocket Rez API, transformed into an analytics-ready data model in BigQuery, validated for quality, and exposed through reporting views that power Power BI dashboards and future AI applications.

```text
Rocket Rez API
       │
       ▼
Cloud Run Ingestion Job
       │
       ▼
BigQuery raw_data
       │
       ├─────────────────────────────┐
       │                             │
       ▼                             ▼
raw_data_history          BigQuery Transformation Pipeline
(Historical Archive)               │
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
                  (Business Rules & Integrity Checks)
                                   │
                                   ▼
                     Analytics Reporting Views
                                   │
                                   ▼
                          Power BI Dashboards
                                   │
                                   ▼
                 Business Users & AI Applications
```

---

# Pipeline Overview

## 1. Data Extraction

A scheduled Cloud Run job retrieves transactional order data from the Rocket Rez REST API and loads the most recent snapshot into the `raw_data` table.

This table represents the latest operational snapshot received from Rocket Rez.

---

## 2. Historical Archive

Before transformations occur, newly received records are merged into `raw_data_history`.

Unlike `raw_data`, this table preserves historical versions of orders by storing every unique combination of:

- Order ID
- Modified Date

This allows historical reporting based on event dates while preserving changes made to orders over time.

---

## 3. Data Transformation

The nested Rocket Rez JSON payload is normalized into a relational schema consisting of four core tables.

### orders

Contains one record per transaction.

Examples:

- Sales office
- Transaction timestamps
- Financial totals
- Status
- Salesperson information

---

### line_items

Contains one record for each ticket, product, membership, or package purchased.

Examples:

- Ticket type
- Quantity
- Revenue
- Discounts
- Taxes

---

### primary_contact

Contains customer information associated with an order.

Personally identifiable information (PII) is separated into its own table to simplify governance and support secure reporting.

---

### event

Contains visit information associated with purchased tickets.

Examples include:

- Visit date
- Event schedule
- Event name
- Start/end time

---

# Data Validation

Each transformation stage includes automated validation rules before data is considered analytics-ready.

Examples include:

- Primary key uniqueness
- Duplicate detection
- Referential integrity
- Financial reconciliation
- Currency normalization
- Status validation
- Required field validation
- Surrogate key validation

Validation results are written to an audit table, and critical failures halt the pipeline to prevent inaccurate reporting.

---

# Reporting Layer

Power BI does not connect directly to the transactional tables.

Instead, dashboards consume curated BigQuery views that:

- encapsulate business logic
- simplify report development
- improve performance
- provide consistent KPI definitions
- isolate Power BI from schema changes

Each reporting view is stored twice in this repository:

## View Definition

Example:

```
vw_membership_tabular.sql
```

Contains the complete

```sql
CREATE OR REPLACE VIEW ...
```

statement used to deploy the view.

---

## Query Only

Example:

```
Membership_Tabular.sql
```

Contains only the SELECT statement.

This makes the business logic easier to review, modify, and test without recreating the view.

---

# Available Reporting Views

Current reporting views include:

## Revenue

- Monthly Revenue by Ticket Type
- Revenue by Sales Channel
- Average Daily Revenue
- Median Daily Revenue
- Total Revenue per Visitor

---

## Transactions

- Average Daily Transactions
- Median Daily Transactions
- Average Transaction Value
- Median Transaction Value
- Refund / Void Rate

---

## Attendance

- Monthly Headcount by Ticket Type
- Visitor Count by Sales Channel
- Yesterday's Tickets Sold
- Seven Day Headcount
- Thirty Day Headcount

---

## Memberships

- Membership Summary
- Membership Tabular

---

# Power BI

Power BI connects directly to the reporting views in BigQuery.

Advantages include:

- Minimal transformation inside Power BI
- Consistent business definitions
- Faster report development
- Centralized SQL maintenance
- Improved report performance

Because the business logic resides inside BigQuery, updating a reporting rule requires changing only the SQL view rather than every individual Power BI visual.

---

# Date Handling

One important design decision in this project is the consistent use of the Aquarium's local timezone.

Revenue calculations use:

```
America/Los_Angeles
```

instead of UTC.

This prevents transactions occurring shortly after midnight UTC from appearing in the incorrect business day or reporting month.

Most yearly reporting views intentionally use fixed date ranges such as:

```sql
DATE(created_date, "America/Los_Angeles") >= DATE '2026-01-01'

DATE(created_date, "America/Los_Angeles") < DATE '2027-01-01'
```

These dates are updated once each year after the books close to preserve historical reporting snapshots.

Operational rolling-window reports (Yesterday, Last 7 Days, Last 30 Days) remain fully dynamic.

---

# Repository Structure

```
Views/
│
├── Revenue/
├── Transactions/
├── Attendance/
├── Membership/
│
├── vw_revenue_by_sales_channel.sql
├── Revenue_By_Sales_Channel.sql
│
├── vw_monthly_revenue_by_ticket_type.sql
├── Monthly_Revenue_By_Ticket_Type.sql
│
└── ...
```

Each reporting object contains:

- View creation script
- Standalone query version

---

# Future Enhancements

Planned improvements include:

- Streamlit AI analytics assistant
- Natural language querying using Vertex AI
- BigQuery semantic layer for AI
- Automated yearly view generation
- Additional operational dashboards
- Row-level security for sensitive reporting
- Cloud Run deployment for AI assistant

---

# Author

William Spagnuolo

MS Data Science — University of San Francisco

Data Engineering | Cloud Analytics | BigQuery | Power BI | Google Cloud Platform
