# Project History

**Document Owner:** Data Engineering  
**Last Updated:** August 2026  
**Related Documents:**
- PIPELINE_ARCHITECTURE.md
- DATA_MODEL.md
- DATA_QUALITY.md
- POWERBI_REPORTING.md
- OPERATIONS.md

---

# Overview

The Aquarium Data Engineering Platform was developed iteratively, with each phase addressing a specific operational or reporting challenge.

Rather than being built as a single project, the platform evolved from a simple API ingestion process into a fully documented analytics ecosystem supporting automated reporting, data quality validation, and conversational analytics.

This document summarizes the major milestones and architectural decisions that shaped the platform.

---

# Phase 1 — Rocket Rez Data Ingestion

## Objective

Automate the retrieval of ticketing data from the Rocket Rez REST API.

## Outcome

A Python ingestion service was developed and deployed to Google Cloud Run.

The ingestion service:

- Authenticates with the Rocket Rez API
- Retrieves paginated order data
- Loads raw JSON into BigQuery
- Supports configurable historical date ranges
- Provides a foundation for automated reporting

At this stage, the platform consisted primarily of a raw ingestion pipeline.

---

# Phase 2 — Historical Data Preservation

## Challenge

The Rocket Rez API returns the current version of an order rather than historical versions.

If an order changed after purchase, previous event information could no longer be retrieved from the API.

## Solution

A dedicated append-only history table was introduced.

```
raw_data_history
```

This table stores every successful API ingestion.

Benefits included:

- Historical reporting
- Pipeline recovery
- Event history preservation
- Improved auditability

This became one of the most significant architectural decisions within the platform.

---

# Phase 3 — Warehouse Normalization

## Challenge

Rocket Rez returns highly nested JSON that is difficult to query efficiently.

## Solution

The nested API response was transformed into a normalized relational warehouse.

Primary warehouse tables include:

- orders
- line_items
- primary_contact
- event

Benefits included:

- Improved query performance
- Clear table grain
- Stable relationships
- Simplified reporting

This phase established the warehouse as the authoritative analytical data source.

---

# Phase 4 — Workflow Automation

## Objective

Automate the transformation process following ingestion.

## Outcome

Google Cloud Workflows was introduced to orchestrate the complete pipeline.

The workflow coordinates:

- Data ingestion
- Warehouse transformations
- Validation
- Audit logging

Automating orchestration reduced manual intervention while improving operational reliability.

---

# Phase 5 — Data Quality Framework

## Challenge

Successful ingestion does not guarantee accurate reporting.

## Solution

A dedicated validation layer was implemented.

Validation now verifies:

- Duplicate records
- Referential integrity
- Primary key uniqueness
- Business rules
- Financial consistency

Validation results are written to an audit log before reporting data is published.

This ensures downstream consumers receive trusted data.

---

# Phase 6 — Reporting Layer

## Objective

Provide a centralized semantic layer for business reporting.

## Solution

Business logic was moved from reporting tools into BigQuery reporting views.

Representative views include:

- Revenue reporting
- Attendance reporting
- Membership reporting
- Transaction reporting

This created a single source of truth for business metrics while simplifying Power BI development.

---

# Phase 7 — Timezone Standardization

## Challenge

The Rocket Rez API filters requests using the company timezone while returning transaction timestamps in UTC.

Without normalization, revenue near midnight UTC could appear in the wrong reporting day or month.

## Solution

Transaction reporting was standardized using:

```sql
DATE(created_date, "America/Los_Angeles")
```

Attendance reporting continues to use scheduled event dates.

This change aligned reporting with business operations and eliminated discrepancies between Rocket Rez and Power BI.

---

# Phase 8 — Reporting Standardization

## Objective

Ensure consistent reporting throughout each calendar year.

## Solution

Annual reporting views were converted from dynamic year filtering to fixed reporting windows.

For example:

```
2026-01-01
```

through

```
2026-12-31
```

These windows are updated annually as part of platform maintenance.

This approach preserves reporting consistency throughout the reporting year while preventing historical dashboards from changing unexpectedly.

---

# Phase 9 — AI Reporting Layer

## Objective

Support conversational analytics while preserving reporting consistency.

## Solution

A dedicated AI reporting dataset was introduced.

```
rocket_rez_ai
```

Rather than exposing warehouse tables directly, the AI assistant queries approved views that:

- Mask sensitive information
- Simplify joins
- Mirror trusted Power BI metrics
- Restrict access to approved business data

This created a secure semantic layer specifically for natural language analytics.

---

# Phase 10 — Aquarium Analytics Assistant

## Objective

Enable users to query Aquarium reporting data using natural language.

## Outcome

A Streamlit application powered by Gemini was developed and deployed on Google Cloud Run.

The application:

- Accepts natural language questions
- Generates GoogleSQL
- Validates generated SQL
- Executes approved queries
- Returns formatted results

Whenever possible, the assistant answers questions using trusted reporting views to ensure consistency with Power BI dashboards.

---

# Phase 11 — Security Enhancements

## Objective

Protect internal reporting data while allowing secure access.

## Solution

The platform was secured using multiple layers.

These include:

- Identity-Aware Proxy (IAP)
- Dedicated service accounts
- SQL validation
- AI-specific reporting views
- Masked personally identifiable information

These measures allow authorized users to access reporting data while protecting internal business information.

---

# Phase 12 — Documentation

## Objective

Improve long-term maintainability and onboarding.

## Outcome

Comprehensive engineering documentation was added covering:

- Platform architecture
- Data model
- Data quality
- Reporting architecture
- Operational procedures
- AI deployment
- Engineering decisions

This documentation enables future engineers to understand, operate, and extend the platform without relying on institutional knowledge.

---

# Looking Forward

The current platform establishes a strong foundation for future enhancements.

Potential future improvements include:

- Automated monitoring and alerting
- Infrastructure as Code (Terraform)
- CI/CD deployment pipelines
- Automated testing
- Additional AI reporting capabilities
- Expanded operational dashboards
- Support for additional reporting systems

The architecture was intentionally designed to accommodate future growth while maintaining consistent business definitions across reporting tools.

---

# Summary

The Aquarium Data Engineering Platform evolved from a simple ingestion process into a fully integrated analytics ecosystem.

Today, the platform provides:

- Automated cloud-based ingestion
- Historical data preservation
- Normalized relational warehousing
- Automated workflow orchestration
- Data quality validation
- Centralized reporting views
- Power BI dashboards
- Gemini-powered conversational analytics
- Secure cloud deployment
- Comprehensive engineering documentation

Each phase built upon the previous one, resulting in a platform that emphasizes reliability, maintainability, consistency, and operational simplicity.