# ADR-003 — Centralize Business Logic in BigQuery Views

**Status:** Accepted  
**Date:** August 2026

---

# Context

Business calculations such as revenue, attendance, memberships, and transaction metrics are used by multiple downstream systems.

Duplicating business logic across Power BI, SQL scripts, and the AI assistant would eventually produce inconsistent metrics.

---

# Decision

Business calculations are implemented as BigQuery reporting views.

Consumers query these views rather than warehouse tables directly.

Current consumers include:

- Power BI
- BigQuery analysts
- Aquarium Analytics Assistant

---

# Consequences

Benefits:

- Single source of truth.
- Easier maintenance.
- Simplified Power BI.
- Consistent KPIs.
- Reduced duplicated SQL.

Tradeoffs:

- Additional reporting layer.
- New metrics require creating or updating views.

---

# Rationale

Business logic should exist in one location rather than being duplicated across reporting tools.