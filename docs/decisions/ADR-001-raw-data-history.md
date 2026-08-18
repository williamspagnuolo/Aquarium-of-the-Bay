# ADR-001 — Preserve Historical API Responses

**Status:** Accepted  
**Date:** August 2026

---

# Context

Rocket Rez provides order information through a REST API.

Each API request returns the **current version** of an order.

If an order is modified after its original purchase—for example:

- event schedule changes
- ticket modifications
- payment updates
- status changes

the API no longer exposes the previous version.

Without additional historical storage, historical reporting could change over time as source data changes.

---

# Decision

The platform stores API responses in two separate BigQuery tables.

```
raw_data
```

Contains the latest ingestion only.

```
raw_data_history
```

Stores every successful ingestion using an append-only strategy.

---

# Consequences

Benefits:

- Historical reporting remains reproducible.
- Previous event schedules are preserved.
- Pipeline recovery is simplified.
- Historical investigations are possible.
- Reports can be regenerated for previous periods.

Tradeoffs:

- Increased storage usage.
- Slightly more complex transformations.

---

# Rationale

Storage costs in BigQuery are relatively inexpensive compared to the operational value of preserving historical data.

Maintaining an append-only history provides significantly greater analytical flexibility while improving recoverability and auditability.