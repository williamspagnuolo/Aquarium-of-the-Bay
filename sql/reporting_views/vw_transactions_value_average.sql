CREATE OR REPLACE VIEW
  `rocket-rez-api.rocket_rez_data.vw_transactions_value_average`
AS

WITH transactions AS (
  SELECT
    order_id,
    total

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
)

SELECT
  ROUND(AVG(total), 2) AS average_transaction_value

FROM transactions;