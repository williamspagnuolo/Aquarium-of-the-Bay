from google.cloud import bigquery


PROJECT_ID = "rocket-rez-api"
MAXIMUM_BYTES_BILLED = 500_000_000  # 500 MB per query

client = bigquery.Client(project=PROJECT_ID)


def estimate_query(sql: str) -> int:
    """Return the estimated number of bytes processed."""

    config = bigquery.QueryJobConfig(
        dry_run=True,
        use_query_cache=False,
    )

    job = client.query(sql, job_config=config)

    return int(job.total_bytes_processed or 0)


def run_query(sql: str):
    """Run an approved query with a hard billing limit."""

    config = bigquery.QueryJobConfig(
        use_legacy_sql=False,
        maximum_bytes_billed=MAXIMUM_BYTES_BILLED,
    )

    job = client.query(sql, job_config=config)
    return job.to_dataframe()