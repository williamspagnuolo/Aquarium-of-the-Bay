# Aquarium Analytics Assistant

## Overview

The Aquarium Analytics Assistant is a Streamlit-based natural language interface for querying approved Aquarium of the Bay reporting data stored in Google BigQuery.

The application uses Gemini through Vertex AI to translate business questions into read-only GoogleSQL, validates the generated SQL, executes approved queries against BigQuery, and returns the result to the user.

The assistant is designed to complement the existing Power BI reporting environment while preserving the same trusted business definitions used in dashboard reporting.

## Architecture

```text
User
  │
  ▼
Streamlit Application
  │
  ▼
Gemini / Vertex AI
  │
  ▼
Generated GoogleSQL
  │
  ▼
SQL Validator
  │
  ▼
Approved BigQuery Views
  │
  ▼
Query Result
  │
  ▼
Streamlit Response
```

The application does not query the protected `rocket_rez_data` dataset directly.

Instead, it is restricted to approved views in:

```text
rocket-rez-api.rocket_rez_ai
```

These views provide privacy-safe, business-approved access to reporting data.

## Components

### `app.py`

Streamlit user interface.

Responsibilities include:

* accepting natural language questions
* displaying generated SQL
* displaying estimated BigQuery processing
* returning query results
* handling query errors

### `gemini_client.py`

Handles communication with Gemini through Vertex AI.

Gemini receives:

* the user's question
* the approved schema context
* business definitions
* view-selection rules
* privacy and security restrictions

The model is instructed to return exactly one read-only GoogleSQL query.

### `schema_context.py`

Defines the semantic layer used by the AI assistant.

It documents:

* approved views
* column names and types
* table grain
* primary and foreign keys
* trusted Power BI metrics
* revenue definitions
* visitor definitions
* timezone rules
* reporting-year rules
* privacy restrictions
* SQL-generation requirements

Trusted Power BI views are preferred whenever they directly answer the user's question so that results remain consistent with the production dashboard.

### `sql_validator.py`

Validates generated SQL before execution.

The validator restricts queries to approved project, dataset, and view names and blocks write operations and other prohibited SQL statements.

### `bigquery_client.py`

Executes validated GoogleSQL against BigQuery and returns query results to the Streamlit application.

## Trusted Reporting Layer

The assistant uses approved views in the `rocket_rez_ai` dataset.

Examples include:

* `vw_revenue_by_sales_channel`
* `vw_membership_tabular`
* `vw_monthly_revenue_by_ticket_type`
* `vw_monthly_headcount_by_ticket_type`
* `vw_visitor_count_by_sales_channel`
* `vw_thirty_day_headcount`

Views that correspond directly to Power BI metrics are treated as trusted sources of truth.

For example, a question such as:

```text
How much ticket revenue was made in Q1 of 2026?
```

is answered from the approved monthly ticket-revenue view rather than reconstructing the metric from lower-level tables.

## Security

The application uses several layers of protection.

### BigQuery Access

The Cloud Run service account is granted access only to the approved `rocket_rez_ai` reporting dataset.

The service account does not receive direct read access to the protected `rocket_rez_data` dataset.

### Authorized Views

AI-facing views expose only approved reporting fields and metrics.

PII is either excluded or masked before it becomes available to the assistant.

### SQL Validation

Generated SQL is validated before execution.

The application allows read-only queries and blocks operations such as:

* `INSERT`
* `UPDATE`
* `DELETE`
* `MERGE`
* `DROP`
* `ALTER`
* `CREATE`
* `TRUNCATE`
* `EXPORT`
* `CALL`

### Identity-Aware Proxy

The deployed Cloud Run application is protected by Google Cloud Identity-Aware Proxy (IAP).

Only approved users with the `IAP-Secured Web App User` role can access the application.

## Local Development

Create and activate a Python virtual environment, then install dependencies:

```bash
pip install -r requirements.txt
```

Authenticate locally with Google Cloud:

```bash
gcloud auth application-default login
```

Run the application:

```bash
streamlit run app.py
```

## Deployment

The application is containerized with Docker and deployed to Google Cloud Run.

See:

```text
DEPLOYMENT.md
```

for deployment instructions.

## Technologies

* Python
* Streamlit
* Gemini
* Vertex AI
* Google BigQuery
* Google Cloud Run
* Identity-Aware Proxy
* Docker
