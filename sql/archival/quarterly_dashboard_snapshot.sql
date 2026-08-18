-- ============================================================
-- Aquarium Dashboard Quarterly Snapshot
--
-- Runs on:
--   January 1, April 1, July 1, and October 1
--
-- The script archives the quarter that ended the previous day.
--
-- Examples:
--   Run on 2026-10-01 -> dashboard_archive_2026_q3
--   Run on 2027-01-01 -> dashboard_archive_2026_q4
-- ============================================================

DECLARE project_id STRING DEFAULT 'rocket-rez-api';
DECLARE source_dataset STRING DEFAULT 'rocket_rez_data';

-- The quarter ended yesterday.
DECLARE archive_date DATE DEFAULT
  DATE_SUB(CURRENT_DATE('America/Los_Angeles'), INTERVAL 1 DAY);

DECLARE archive_year INT64 DEFAULT
  EXTRACT(YEAR FROM archive_date);

DECLARE archive_quarter INT64 DEFAULT
  EXTRACT(QUARTER FROM archive_date);

DECLARE archive_dataset STRING DEFAULT FORMAT(
  'dashboard_archive_%d_q%d',
  archive_year,
  archive_quarter
);

DECLARE view_names ARRAY<STRING> DEFAULT [
  'vw_average_daily_revenue',
  'vw_median_daily_revenue',
  'vw_membership_summary',
  'vw_membership_tabular',
  'vw_monthly_headcount_by_ticket_type',
  'vw_monthly_revenue_by_ticket_type',
  'vw_monthly_ticket_revenue',
  'vw_refund_void_rate',
  'vw_revenue_by_sales_channel',
  'vw_seven_day_headcount',
  'vw_thirty_day_headcount',
  'vw_total_revenue_per_visitor',
  'vw_transactions_daily_average',
  'vw_transactions_daily_median',
  'vw_transactions_value_average',
  'vw_transactions_value_median',
  'vw_visitor_count_by_sales_channel',
  'vw_yesterdays_tickets_sold'
];

DECLARE view_name STRING;
DECLARE existing_view_count INT64;

-- ============================================================
-- SAFEGUARD 1:
-- Confirm that this script is running immediately after a
-- quarter-end date.
-- ============================================================

ASSERT
  EXTRACT(MONTH FROM archive_date) IN (3, 6, 9, 12)
  AND archive_date = LAST_DAY(archive_date, QUARTER)
AS 'The archive date is not the final day of a calendar quarter.';

-- ============================================================
-- SAFEGUARD 2:
-- Confirm that all 18 source views still exist.
-- ============================================================

SET existing_view_count = (
  SELECT COUNT(*)
  FROM `rocket-rez-api.rocket_rez_data.INFORMATION_SCHEMA.VIEWS`
  WHERE table_name IN UNNEST(view_names)
);

ASSERT existing_view_count = ARRAY_LENGTH(view_names)
AS 'One or more required dashboard views are missing.';

-- ============================================================
-- Create the quarter-specific archive dataset.
--
-- Change US below only if rocket_rez_data is stored in a
-- different BigQuery location.
-- ============================================================

EXECUTE IMMEDIATE FORMAT(
  """
  CREATE SCHEMA IF NOT EXISTS `%s.%s`
  OPTIONS(
    location = 'us-central1',
    description = 'Frozen Power BI dashboard results for %d Q%d'
  )
  """,
  project_id,
  archive_dataset,
  archive_year,
  archive_quarter
);

-- ============================================================
-- Materialize each view as a permanent physical table.
--
-- The archived table retains the same name as the live view.
-- ============================================================

FOR view_record IN (
  SELECT view_name
  FROM UNNEST(view_names) AS view_name
)
DO
  SET view_name = view_record.view_name;

  EXECUTE IMMEDIATE FORMAT(
    """
    CREATE OR REPLACE TABLE `%s.%s.%s`
    OPTIONS(
      description = 'Frozen copy of %s as of %s'
    )
    AS
    SELECT *
    FROM `%s.%s.%s`
    """,
    project_id,
    archive_dataset,
    view_name,
    view_name,
    CAST(archive_date AS STRING),
    project_id,
    source_dataset,
    view_name
  );
END FOR;

-- ============================================================
-- Add an archive metadata table.
-- ============================================================

EXECUTE IMMEDIATE FORMAT(
  """
  CREATE OR REPLACE TABLE `%s.%s.snapshot_metadata` AS
  SELECT
    %d AS archive_year,
    %d AS archive_quarter,
    DATE '%s' AS archive_date,
    CURRENT_TIMESTAMP() AS snapshot_created_at,
    '%s' AS source_dataset,
    %d AS archived_object_count
  """,
  project_id,
  archive_dataset,
  archive_year,
  archive_quarter,
  CAST(archive_date AS STRING),
  source_dataset,
  ARRAY_LENGTH(view_names)
);

-- ============================================================
-- Return a completion summary.
-- ============================================================

SELECT
  archive_dataset AS archive_dataset_created,
  archive_date AS quarter_end_date,
  ARRAY_LENGTH(view_names) AS views_archived,
  CURRENT_TIMESTAMP() AS completed_at;