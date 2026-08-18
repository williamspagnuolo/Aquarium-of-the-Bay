# Data Quality

**Document Owner:** Data Engineering  
**Last Updated:** August 2026  
**Related Documents:**
- PIPELINE_ARCHITECTURE.md
- DATA_MODEL.md
- POWERBI_REPORTING.md
- OPERATIONS.md

---

# Overview

Reliable reporting depends on more than successful data ingestion. It requires confidence that transformed data accurately represents the source system and that downstream consumers receive complete, consistent, and trustworthy information.

The Aquarium Data Engineering Platform includes a dedicated validation layer that executes after every transformation cycle. This layer verifies the integrity of the relational warehouse before refreshed data becomes available to Power BI dashboards and the Aquarium Analytics Assistant.

Validation results are written to an audit log, providing operational visibility and a historical record of pipeline health.

---

# Validation Workflow

The validation process executes after all transformation queries have completed successfully.

```
Rocket Rez API

        │

        ▼

Cloud Run Ingestion

        │

        ▼

BigQuery Transformations

        │

        ▼

Validation Queries

        │

        ▼

audit_log

        │

        ▼

Power BI
AI Analytics Assistant
```

If a validation step fails, the pipeline records the failure and prevents inaccurate data from propagating into downstream reporting systems.

---

# Validation Objectives

The validation layer was designed around five primary objectives.

- Verify transformed data matches expected business rules.
- Detect duplicate or conflicting records.
- Preserve referential integrity.
- Identify unexpected source-system changes.
- Provide traceable operational logs for troubleshooting.

---

# Duplicate Detection

Duplicate data is one of the most common causes of inaccurate reporting.

The platform performs duplicate checks against business entities that are expected to be unique.

Examples include:

- Orders
- Events
- Line Items
- Primary Contacts

Duplicate detection protects reporting metrics such as:

- Revenue
- Transaction counts
- Attendance
- Membership sales

from being artificially inflated.

---

# Primary Key Validation

Each analytical table enforces a unique primary identifier.

| Table | Primary Key |
|--------|-------------|
| orders | order_id |
| line_items | surrogate_key |
| primary_contact | contact_surrogate_key |
| event | event_surrogate_key |

Validation confirms these identifiers remain unique after every transformation.

---

# Foreign Key Validation

Relationships between warehouse tables are verified before reporting views are refreshed.

```
line_items.order_id
        │
        ▼
orders.order_id
```

```
primary_contact.order_id
        │
        ▼
orders.order_id
```

```
event.order_id
        │
        ▼
orders.order_id
```

Records referencing missing parent orders indicate incomplete transformations or unexpected source-system behavior.

---

# Null Value Validation

Some fields are expected to contain values for every record.

Examples include:

- order_id
- created_date
- status
- event_date

Unexpected null values may indicate:

- Incomplete ingestion
- Malformed API responses
- Transformation failures

Fields that are intentionally nullable are excluded from these checks.

---

# Business Rule Validation

In addition to structural validation, the platform verifies business-specific rules.

Examples include:

- Valid order statuses
- Valid ticket types
- Valid sales offices
- Expected event dates
- Expected transaction totals

This layer helps identify unexpected changes introduced by the Rocket Rez application before they affect reporting.

---

# Financial Validation

Revenue reporting depends on accurate financial calculations.

Validation confirms transformed financial fields remain internally consistent.

Examples include:

- Transaction totals
- Subtotals
- Taxes
- Discounts
- Gratuities

These checks provide confidence that reporting views accurately represent Rocket Rez transactions.

---

# Historical Integrity

The warehouse intentionally separates:

```
raw_data
```

from

```
raw_data_history
```

Validation ensures historical records continue to accumulate without overwriting previous API responses.

Maintaining historical integrity allows the platform to:

- Recover from pipeline failures
- Reprocess historical data
- Investigate reporting discrepancies
- Preserve historical event information

---

# Referential Integrity

The platform preserves relationships between business entities throughout the transformation process.

```
Order

    │

    ├── Line Items

    ├── Primary Contact

    └── Events
```

Validation ensures these relationships remain intact after nested Rocket Rez JSON has been normalized into relational tables.

---

# Unknown Contacts

Rocket Rez does not always provide complete customer information.

Rather than discarding affected orders, the transformation process creates an "unknown contact" record.

Validation verifies these records are explicitly identified using:

```
is_unknown_contact = TRUE
```

This preserves warehouse relationships while allowing reporting to distinguish between known and unknown customer information.

---

# Reporting Validation

Reporting views are validated against the underlying warehouse tables.

The objective is to ensure business metrics remain consistent regardless of whether they are queried through:

- Power BI
- BigQuery
- The Aquarium Analytics Assistant

Examples include:

- Monthly revenue
- Membership revenue
- Visitor counts
- Sales channel reporting
- Ticket revenue

This consistency is particularly important because the AI assistant is designed to mirror trusted Power BI metrics whenever an equivalent reporting view exists.

---

# Operational Validation

Each workflow execution verifies that:

- Ingestion completed successfully
- Transformations completed successfully
- Validation queries completed successfully
- Reporting views remain queryable

Failures are recorded before downstream systems are refreshed.

---

# Audit Logging

Every validation cycle records operational information within the audit log.

Typical information includes:

- Pipeline execution timestamp
- Validation stage
- Success or failure status
- Error details (when applicable)
- Workflow execution status

The audit log provides a historical record of pipeline execution and simplifies troubleshooting.

---

# Failure Handling

The platform follows a fail-fast validation strategy.

```
Transformation

        │

        ▼

Validation

        │

        ▼

Validation Passed?

      Yes ─────────► Reporting Updated

       │

       No

       ▼

Pipeline Failure

       │

       ▼

audit_log

       │

       ▼

Engineer Investigation
```

Preventing incorrect data from reaching reporting systems is prioritized over completing a pipeline with questionable results.

---

# Manual Recovery

If a pipeline failure results in missing historical data, engineers can execute a manual backfill using:

```
ingestion/main_backfill.ipynb
```

The notebook allows historical Rocket Rez data to be reloaded for specific date ranges.

Because the ingestion process is idempotent, historical backfills can safely be rerun without introducing duplicate warehouse records.

---

# Example Validation Queries

The following examples illustrate several of the validation checks performed after each pipeline execution. These examples are representative of the validation logic contained within the `sql/validation/` directory.

## Duplicate Orders

Every order should appear only once within the `orders` table.

```sql
SELECT
    order_id,
    COUNT(*) AS duplicate_count
FROM `rocket-rez-api.rocket_rez_data.orders`
GROUP BY order_id
HAVING COUNT(*) > 1;
```

**Expected Result**

```
0 rows returned
```

---

## Duplicate Line Items

Each generated surrogate key should uniquely identify a normalized line item.

```sql
SELECT
    surrogate_key,
    COUNT(*) AS duplicate_count
FROM `rocket-rez-api.rocket_rez_data.line_items`
GROUP BY surrogate_key
HAVING COUNT(*) > 1;
```

**Expected Result**

```
0 rows returned
```

---

## Orphan Line Items

Every line item should reference an existing order.

```sql
SELECT
    li.order_id
FROM `rocket-rez-api.rocket_rez_data.line_items` li
LEFT JOIN `rocket-rez-api.rocket_rez_data.orders` o
    ON li.order_id = o.order_id
WHERE o.order_id IS NULL;
```

**Expected Result**

```
0 rows returned
```

---

## Duplicate Event Records

Each event surrogate key should uniquely identify an event record.

```sql
SELECT
    event_surrogate_key,
    COUNT(*) AS duplicate_count
FROM `rocket-rez-api.rocket_rez_data.event`
GROUP BY event_surrogate_key
HAVING COUNT(*) > 1;
```

**Expected Result**

```
0 rows returned
```

---

## Unknown Contact Monitoring

Orders without complete customer information should be explicitly identified rather than discarded.

```sql
SELECT
    COUNT(*) AS unknown_contacts
FROM `rocket-rez-api.rocket_rez_data.primary_contact`
WHERE is_unknown_contact = TRUE;
```

**Expected Result**

A non-zero result is acceptable. Unknown contacts are intentionally retained to preserve referential integrity while indicating that complete customer information was unavailable from the source system.

---

## Historical Table Growth

The historical archive should continue to accumulate records over time.

```sql
SELECT
    COUNT(*) AS historical_records
FROM `rocket-rez-api.rocket_rez_data.raw_data_history`;
```

**Expected Result**

The total number of records should increase as new pipeline executions occur. Existing historical records should never be overwritten.

---

# Validation Philosophy

The objective of the validation layer is not only to detect failures, but also to prevent incorrect data from reaching downstream reporting systems.

Validation queries are intentionally designed to verify both structural integrity (such as primary and foreign key relationships) and business integrity (such as revenue calculations and historical completeness). By executing these checks before reporting views are refreshed, the platform helps ensure that Power BI dashboards and the Aquarium Analytics Assistant consistently return trusted, accurate business metrics.

---

# Data Quality Principles

The platform was designed around the following principles.

- Validate before publishing.
- Fail fast when integrity checks fail.
- Preserve historical records.
- Maintain referential integrity.
- Keep business logic centralized.
- Provide operational transparency through audit logging.
- Support safe manual recovery.

These principles help ensure that Power BI dashboards and the Aquarium Analytics Assistant consistently report trusted business metrics while providing engineers with the information necessary to investigate and resolve data quality issues.