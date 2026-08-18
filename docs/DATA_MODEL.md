# Data Model

## Overview

The Aquarium Data Engineering Platform transforms nested JSON returned by the Rocket Rez REST API into a normalized relational data warehouse within Google BigQuery.

Rocket Rez is designed as a transactional reservation system and returns deeply nested JSON documents containing orders, contacts, line items, events, memberships, questions, and other related entities. While this structure is well suited for API communication, it is difficult to query efficiently for analytics and business intelligence.

To support scalable reporting, the platform decomposes the nested JSON into relational tables while preserving the relationships between business entities.

The resulting warehouse provides:

- Clearly defined table grain
- Stable primary keys
- Explicit foreign key relationships
- Reduced data duplication
- Simplified SQL development
- Improved reporting performance
- Consistent metrics across Power BI and the Aquarium Analytics Assistant

---

# Source Data

The source system for the warehouse is the Rocket Rez REST API.

Each API response contains a hierarchical JSON document similar to the structure below.

```
Order
│
├── Primary Contact
│
├── Questions
│
├── Payments
│
├── Line Items
│      │
│      ├── Rate Types
│      ├── Products
│      └── Events
│
└── Additional Metadata
```

Rather than querying nested arrays directly, the ingestion pipeline separates each business entity into its own relational table.

---

# Entity Relationship Diagram

```
                                    orders
                           ┌──────────────────────┐
                           │ PK order_id          │
                           │ created_date         │
                           │ modified_date        │
                           │ status               │
                           │ salesoffice_name     │
                           │ total                │
                           └──────────┬───────────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
                    ▼                 ▼                 ▼

        line_items             primary_contact              event
   ┌──────────────────┐    ┌────────────────────┐    ┌────────────────────┐
   │ PK surrogate_key │    │ PK contact_key     │    │ PK event_key       │
   │ FK order_id      │    │ FK order_id        │    │ FK order_id        │
   │ line_item_type   │    │ city               │    │ event_date         │
   │ rate_type        │    │ province           │    │ event_start        │
   │ quantity         │    │ country            │    │ event_end          │
   │ subtotal         │    │ is_unknown_contact │    │ schedule_id        │
   └──────────────────┘    └────────────────────┘    └────────────────────┘
```

The **orders** table acts as the central transactional table for the warehouse.

Each supporting table references the order through the `order_id` foreign key while maintaining its own business grain.

---

# Warehouse Tables

The warehouse consists of four primary analytical tables.

## orders

### Purpose

Stores one record for every Rocket Rez order.

This table represents the transaction itself rather than individual purchased products.

Typical information includes:

- Order status
- Sales office
- Salesperson
- Transaction totals
- Created and modified timestamps
- Contact group information

### Grain

**One row per order.**

### Primary Key

```
order_id
```

### Referenced By

- line_items
- primary_contact
- event

### Business Purpose

The orders table serves as the central transaction table used for reporting metrics such as:

- Total revenue
- Transaction counts
- Average transaction value
- Sales office performance
- Order trends

---

## line_items

### Purpose

Stores every purchased item associated with an order.

Examples include:

- Admission tickets
- Memberships
- Retail products
- Packages
- Prepaid passes

### Grain

**One row per unique line item and rate type combination.**

### Primary Key

```
surrogate_key
```

### Foreign Key

```
order_id
```

joins to

```
orders.order_id
```

### Business Purpose

This table powers reporting such as:

- Ticket revenue
- Ticket quantities
- Product revenue
- Membership revenue
- Revenue by ticket type

---

## primary_contact

### Purpose

Stores customer information associated with an order.

### Grain

**One row per order.**

### Primary Key

```
contact_surrogate_key
```

### Foreign Key

```
order_id
```

### Business Purpose

Provides customer dimensions such as:

- City
- Province / State
- Country

Personally identifiable information is masked before becoming available to the AI reporting layer.

---

## event

### Purpose

Stores scheduled event information associated with purchased tickets.

Examples include:

- Event date
- Event schedule
- Start time
- End time

### Grain

**One row per scheduled event associated with an order.**

### Primary Key

```
event_surrogate_key
```

### Additional Column

```
rn
```

The `rn` (row number) column is generated during transformation using a window function.

It allows duplicate event records to be identified while providing a consistent mechanism for selecting the desired record during downstream processing.

### Foreign Key

```
order_id
```

### Business Purpose

The event table enables reporting based on **visit dates** rather than **purchase dates**.

Examples include:

- Daily attendance
- Visitor headcount
- Attendance by ticket type
- Operational reporting

---

# Supporting Tables

## raw_data

Contains the most recent Rocket Rez API response.

Purpose:

- Staging
- Troubleshooting
- Intermediate processing

This table is overwritten during each successful ingestion.

---

## raw_data_history

Contains an append-only history of every API response processed by the platform.

Purpose:

- Historical reporting
- Auditability
- Data recovery
- Pipeline reprocessing
- Change tracking

Unlike `raw_data`, this table is never overwritten.

---

## audit_log

Stores validation results generated during each pipeline execution.

Examples include:

- Successful validation
- Duplicate detection
- Integrity failures
- Workflow execution status

---

# Transformation Decisions

## Nested JSON Normalization

Rocket Rez stores multiple business entities inside a single nested JSON document.

Rather than querying nested arrays directly, the ingestion pipeline separates each entity into its own relational table.

Examples include:

- Orders
- Line Items
- Primary Contacts
- Events

This improves query readability, reporting performance, and long-term maintainability.

---

## Surrogate Keys

Some Rocket Rez entities cannot be uniquely identified after nested arrays are expanded.

For example, a single line item may contain multiple nested rate types, resulting in multiple analytical rows.

To ensure uniqueness, the platform generates deterministic surrogate keys for:

- line_items
- primary_contact
- event

These keys simplify joins, validation, and duplicate detection while providing stable identifiers for downstream reporting.

---

## Row Number (rn)

The **event** table includes an `rn` (row number) column generated during transformation.

This value identifies duplicate event records associated with the same business entity.

Keeping the row number allows engineers to:

- Investigate duplicate records
- Troubleshoot historical changes
- Simplify deduplication logic

while allowing downstream reporting to consistently select the desired record.

---

## Unknown Contacts

Some Rocket Rez orders do not contain complete primary contact information.

Rather than discarding these orders, the pipeline creates an "unknown contact" record and sets:

```
is_unknown_contact = TRUE
```

This preserves referential integrity while allowing reporting to distinguish between known and unknown customer information.

---

## Historical Preservation

The warehouse intentionally separates:

```
raw_data
```

from

```
raw_data_history
```

The latest API response is stored in `raw_data`.

Every ingestion is appended to `raw_data_history`.

This design preserves historical event information that would otherwise be lost when Rocket Rez updates an order after its original purchase.

---

# Reporting Layer

Power BI connects exclusively to reporting views rather than directly querying warehouse tables.

```
Warehouse Tables
        │
        ▼
Reporting Views
        │
        ▼
Power BI
```

Benefits include:

- Centralized business logic
- Consistent KPI definitions
- Reduced duplication
- Easier maintenance
- Simpler Power BI models

---

# AI Reporting Layer

The Aquarium Analytics Assistant queries a separate collection of AI-specific views.

```
Warehouse Tables
        │
        ▼
AI Reporting Views
        │
        ▼
Gemini Analytics Assistant
```

These views:

- Expose only approved columns
- Simplify joins
- Hide sensitive information
- Preserve reporting consistency
- Mirror trusted Power BI metrics whenever possible

---

# Date Strategy

The warehouse distinguishes between two different business concepts.

## Transaction Date

Derived from:

```
orders.created_date
```

Represents when a purchase occurred.

Used for:

- Revenue reporting
- Transaction reporting
- Sales analysis

---

## Visit Date

Derived from:

```
event.event_date
```

Represents when guests visited the Aquarium.

Used for:

- Attendance
- Visitor counts
- Operational reporting

Separating these concepts prevents purchases made in advance from being attributed to the wrong attendance period.

---

# Data Flow

```
Rocket Rez API

        │

        ▼

raw_data

        │

        ▼

raw_data_history

        │

        ▼

orders
line_items
primary_contact
event

        │

        ▼

Reporting Views
AI Reporting Views

        │

        ▼

Power BI
Gemini Analytics Assistant
```

---

# Why This Model?

The data warehouse was intentionally designed to balance transactional fidelity with analytical simplicity.

Rather than exposing nested Rocket Rez JSON directly to reporting tools, the platform creates a normalized relational model that:

- Preserves historical information
- Reduces duplicated business logic
- Simplifies SQL development
- Supports scalable reporting
- Improves query performance
- Enables consistent metrics across Power BI and the AI Analytics Assistant

The resulting warehouse serves as the single source of truth for both traditional business intelligence and conversational analytics while remaining maintainable for future enhancements.