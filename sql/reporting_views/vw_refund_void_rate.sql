CREATE OR REPLACE VIEW
  `rocket-rez-api.rocket_rez_data.vw_refund_void_rate`
AS

SELECT
  COUNTIF(
    UPPER(REPLACE(status, ' ', '')) IN (
      'VOID',
      'VOIDED',
      'CANCELLED',
      'RETURNPENDING',
      'RETURNPROCESSED'
    )
  ) AS refunded_or_voided_transactions,

  COUNT(*) AS total_transactions,

  ROUND(
    SAFE_DIVIDE(
      COUNTIF(
        UPPER(REPLACE(status, ' ', '')) IN (
          'VOID',
          'VOIDED',
          'CANCELLED',
          'RETURNPENDING',
          'RETURNPROCESSED'
        )
      ),
      COUNT(*)
    ),
    4
  ) AS refund_void_rate

FROM `rocket-rez-api.rocket_rez_data.orders`

WHERE DATE(created_date, 'America/Los_Angeles') >= DATE '2026-01-01'--update to 2027-01-01
  AND DATE(created_date, 'America/Los_Angeles') < DATE '2027-01-01';--update to 2028-01-01