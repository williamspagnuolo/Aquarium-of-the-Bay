# ADR-002 — Standardize Reporting Using Pacific Time

**Status:** Accepted  
**Date:** August 2026

---

# Context

Rocket Rez accepts API date filters using the company's configured timezone.

However,

```
createdDate
```

is returned as a UTC timestamp.

This creates situations where transactions occurring shortly after midnight UTC actually belong to the previous business day in California.

Using UTC directly would produce incorrect daily and monthly revenue totals.

---

# Decision

All transaction-based reporting converts:

```
created_date
```

using

```sql
DATE(created_date, "America/Los_Angeles")
```

before grouping by day, month, or year.

Attendance reporting continues to use:

```
event.schedule.date
```

because it already represents the business visit date.

---

# Consequences

Benefits:

- Revenue aligns with business operations.
- Daily reports match Rocket Rez.
- Monthly reporting remains consistent.
- Power BI and the Analytics Assistant return identical values.

Tradeoffs:

- Reporting queries become slightly more verbose.
- Engineers must distinguish between transaction dates and visit dates.

---

# Rationale

Business reporting should reflect the Aquarium's operating day rather than UTC calendar boundaries.