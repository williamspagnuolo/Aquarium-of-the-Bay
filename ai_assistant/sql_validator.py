import re


BLOCKED_KEYWORDS = {
    "INSERT",
    "UPDATE",
    "DELETE",
    "MERGE",
    "DROP",
    "ALTER",
    "CREATE",
    "TRUNCATE",
    "EXPORT",
    "CALL",
    "GRANT",
    "REVOKE",
}

ALLOWED_PROJECT = "rocket-rez-api"
ALLOWED_DATASET = "rocket_rez_ai"

ALLOWED_VIEWS = {
    "vw_primary_contact_masked",
    "vw_orders",
    "vw_line_items",
    "vw_event",
    "vw_revenue_by_sales_channel",
    "vw_membership_tabular",
    "vw_monthly_revenue_by_ticket_type",
    "vw_monthly_headcount_by_ticket_type",
    "vw_revenue_by_sales_channel",
    "vw_visitor_count_by_sales_channel",
    "vw_thirty_day_headcount",
}


def validate_sql(sql: str) -> None:
    normalized = re.sub(r"\s+", " ", sql.strip()).upper()

    if not (
        normalized.startswith("SELECT")
        or normalized.startswith("WITH")
    ):
        raise ValueError("Only read-only SELECT queries are permitted.")

    sql_without_final_semicolon = sql.strip().rstrip(";")

    if ";" in sql_without_final_semicolon:
        raise ValueError("Multiple SQL statements are not permitted.")

    for keyword in BLOCKED_KEYWORDS:
        if re.search(rf"\b{keyword}\b", normalized):
            raise ValueError(
                f"Blocked SQL keyword detected: {keyword}"
            )

    referenced_objects = re.findall(r"`([^`]+)`", sql)

    if not referenced_objects:
        raise ValueError(
            "Queries must use fully qualified backtick table names."
        )

    for object_name in referenced_objects:
        parts = object_name.split(".")

        if len(parts) != 3:
            raise ValueError(
                f"Use fully qualified table names: {object_name}"
            )

        project, dataset, view = parts

        if project != ALLOWED_PROJECT:
            raise ValueError(
                f"Project is not approved: {project}"
            )

        if dataset != ALLOWED_DATASET:
            raise ValueError(
                f"Dataset is not approved: {dataset}"
            )

        if view not in ALLOWED_VIEWS:
            raise ValueError(
                f"View is not approved: {view}"
            )