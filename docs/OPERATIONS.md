# Operations

**Document Owner:** Data Engineering  
**Last Updated:** August 2026  
**Related Documents:**
- PIPELINE_ARCHITECTURE.md
- DATA_MODEL.md
- DATA_QUALITY.md
- POWERBI_REPORTING.md
- ../ai_assistant/DEPLOYMENT.md

---

# Overview

This document describes the day-to-day operation and maintenance of the Aquarium Data Engineering Platform.

The platform has been designed to operate automatically while providing engineers with clear procedures for troubleshooting, recovery, and annual maintenance.

Typical operational responsibilities include:

- Monitoring pipeline execution
- Investigating failures
- Executing historical backfills
- Updating annual reporting views
- Deploying code changes
- Validating reporting accuracy

---

# Daily Pipeline

The production workflow executes automatically.

High-level execution order:

```
Cloud Scheduler

        │

        ▼

Google Cloud Workflows

        │

        ▼

Cloud Run Ingestion

        │

        ▼

BigQuery Transformations

        │

        ▼

Validation

        │

        ▼

Reporting Views

        │

        ▼

Power BI

        │

        ▼

Analytics Assistant
```

Each stage depends on the successful completion of the previous stage.

---

# Daily Responsibilities

Under normal operation, no manual intervention is required.

The platform automatically:

- Retrieves Rocket Rez data
- Loads raw JSON into BigQuery
- Archives historical records
- Refreshes warehouse tables
- Executes validation
- Updates reporting views
- Refreshes downstream reporting

---

# Monitoring

Pipeline health should be monitored using:

- Cloud Workflows execution history
- Cloud Run logs
- BigQuery job history
- audit_log table

These tools provide visibility into both successful executions and failures.

---

# Common Failure Scenarios

Typical failures include:

## Rocket Rez API

Examples:

- API unavailable
- Authentication failure
- Rate limiting
- Unexpected API response

---

## Cloud Run

Examples:

- Container startup failure
- Python exception
- Timeout
- Memory exhaustion

---

## BigQuery

Examples:

- SQL syntax error
- Schema mismatch
- Permission changes
- Missing datasets

---

## Validation

Examples:

- Duplicate records
- Failed integrity checks
- Missing parent records
- Unexpected null values

Validation failures intentionally stop downstream reporting.

---

# Troubleshooting Workflow

When a pipeline failure occurs:

```
Failure

    │

    ▼

Review Workflow Logs

    │

    ▼

Review Cloud Run Logs

    │

    ▼

Review BigQuery Jobs

    │

    ▼

Review audit_log

    │

    ▼

Determine Root Cause

    │

    ▼

Fix Issue

    │

    ▼

Rerun Pipeline
```

This process helps isolate whether the failure originated in ingestion, transformation, validation, or reporting.

---

# Manual Backfill

Historical data can be recovered using:

```
ingestion/main_backfill.ipynb
```

The notebook allows engineers to execute historical Rocket Rez API requests for any desired date range.

Typical parameters include:

```python
params = {
    "startDate": "2026-01-01",
    "endDate": "2026-01-31",
    "pageIndex": 0
}
```

The Rocket Rez API interprets these dates using the company timezone while returning timestamps in UTC.

---

# Backfill Procedure

1. Open:

```
ingestion/main_backfill.ipynb
```

2. Update:

- startDate
- endDate

3. Execute the notebook.

4. Verify:

- raw_data updated
- raw_data_history appended

5. Execute the transformation workflow.

6. Review validation results.

7. Confirm reporting views.

---

# Idempotent Processing

The ingestion process is designed to be idempotent.

Re-running an existing date range updates modified records while preventing duplicate warehouse data.

This allows historical recovery without rebuilding the warehouse from scratch.

---

# Annual Maintenance

Most reporting views intentionally represent a fixed reporting year.

Near the beginning of each calendar year, update the reporting window.

Example:

```
DATE(created_date, "America/Los_Angeles")
>= DATE '2026-01-01'

DATE(created_date, "America/Los_Angeles")
< DATE '2027-01-01'
```

becomes

```
DATE(created_date, "America/Los_Angeles")
>= DATE '2027-01-01'

DATE(created_date, "America/Los_Angeles")
< DATE '2028-01-01'
```

Views requiring this update include:

- Revenue reporting
- Membership reporting
- Transaction reporting
- Attendance reporting

Rolling operational views (such as yesterday's attendance and thirty-day headcount) do not require annual modification.

---

# Annual Verification Checklist

After updating the reporting year:

- Execute reporting views.
- Confirm January data exists.
- Verify Power BI visuals.
- Verify Analytics Assistant responses.
- Compare totals against Rocket Rez.
- Confirm no unexpected reporting gaps.

---

# Deploying Pipeline Changes

When ingestion code changes:

1. Build a new container image.
2. Push the image to Artifact Registry.
3. Deploy a new Cloud Run revision.
4. Execute a test ingestion.
5. Verify transformed tables.
6. Validate reporting.

---

# Deploying SQL Changes

When modifying transformations or reporting views:

1. Test SQL in BigQuery.
2. Validate results.
3. Update saved queries.
4. Update production views.
5. Refresh Power BI.
6. Verify Analytics Assistant responses.

---

# Deploying Workflow Changes

Workflow changes should be tested in a development environment before deployment.

Typical procedure:

1. Update:

```
orchestration/workflow.yaml
```

2. Deploy updated workflow.

3. Execute a manual run.

4. Confirm successful completion.

---

# Deploying AI Changes

AI Assistant changes are documented separately in:

```
ai_assistant/DEPLOYMENT.md
```

Typical deployment includes:

- Container rebuild
- Cloud Run deployment
- IAP verification
- Functional testing

---

# Post-Deployment Validation

After any deployment:

Verify:

- Cloud Run healthy
- Workflow completes
- Validation succeeds
- Reporting views return expected results
- Power BI refreshes successfully
- Analytics Assistant returns correct answers

---

# Repository Structure

```
ingestion/
    Cloud Run ingestion
    Manual backfill notebook

orchestration/
    Google Cloud Workflow

sql/
    transformations
    validation
    reporting_views
    ai_views

powerbi/
    Reporting documentation

ai_assistant/
    Streamlit application

docs/
    Engineering documentation
```

---

# Operational Principles

The platform was designed around several operational principles.

- Automate repetitive tasks.
- Preserve historical data.
- Validate before publishing.
- Recover through idempotent processing.
- Centralize business logic.
- Keep reporting consistent.
- Separate operational and analytical concerns.
- Document every critical engineering decision.

These principles allow the platform to be maintained by future engineers while providing reliable reporting for Aquarium operations.