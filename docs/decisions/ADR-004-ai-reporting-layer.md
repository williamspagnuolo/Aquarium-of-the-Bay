# ADR-004 — Restrict AI to Approved Reporting Views

**Status:** Accepted  
**Date:** August 2026

---

# Context

Large Language Models can generate SQL dynamically.

Allowing unrestricted access to warehouse tables could expose:

- Personally identifiable information
- Internal implementation details
- Complex joins
- Inconsistent business calculations

It would also increase the likelihood that AI-generated queries disagree with Power BI.

---

# Decision

The Analytics Assistant queries only approved views within:

```
rocket_rez_ai
```

These views:

- expose approved columns,
- simplify joins,
- mask sensitive information,
- mirror trusted reporting metrics whenever possible.

The SQL validator additionally prevents access to unauthorized datasets and write operations.

---

# Consequences

Benefits:

- Consistent business answers.
- Improved security.
- Reduced SQL complexity.
- Better AI reliability.
- Easier prompt engineering.

Tradeoffs:

- AI has access to fewer tables.
- New reporting requirements may require additional AI views.

---

# Rationale

The primary objective of the Analytics Assistant is to answer business questions accurately and consistently—not to expose the entire data warehouse.