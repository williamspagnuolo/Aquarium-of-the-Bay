CREATE OR REPLACE VIEW
  `rocket-rez-api.rocket_rez_data.vw_transactions_daily_median`
AS

WITH daily_transactions AS (
  SELECT
    DATE(created_date, 'America/Los_Angeles') AS transaction_date,
    COUNT(DISTINCT order_id) AS transactions

  FROM `rocket-rez-api.rocket_rez_data.orders`

  WHERE DATE(created_date, 'America/Los_Angeles') >= DATE '2026-01-01'-- update to 2027-01-01
    AND DATE(created_date, 'America/Los_Angeles') < DATE '2027-01-01'-- update to 2028-01-01

    AND UPPER(status) NOT IN (
      'CANCELLED',
      'VOID',
      'VOIDED',
      'RETURNPENDING',
      'RETURNPROCESSED'
    )

  GROUP BY
    transaction_date
)

SELECT
  ROUND(
    PERCENTILE_CONT(transactions, 0.5) OVER (),
    2
  ) AS median_daily_transactions

FROM daily_transactions

QUALIFY ROW_NUMBER() OVER () = 1;