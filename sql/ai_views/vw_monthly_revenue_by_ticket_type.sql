CREATE OR REPLACE VIEW
  `rocket-rez-api.rocket_rez_ai.vw_monthly_revenue_by_ticket_type`
AS

SELECT
  DATE_TRUNC(
    DATE(o.created_date, 'America/Los_Angeles'),
    MONTH
  ) AS revenue_month_date,

  FORMAT_DATE(
    '%B %Y',
    DATE_TRUNC(
      DATE(o.created_date, 'America/Los_Angeles'),
      MONTH
    )
  ) AS revenue_month,

  li.rate_type AS ticket_type,

  SUM(li.line_item_quantity) AS tickets_sold,

  SUM(li.line_item_subtotal) AS revenue

FROM `rocket-rez-api.rocket_rez_data.line_items` AS li

INNER JOIN `rocket-rez-api.rocket_rez_data.orders` AS o
  ON li.order_id = o.order_id

WHERE UPPER(o.status) NOT IN (
    'CANCELLED',
    'VOID',
    'VOIDED',
    'REFUNDED',
    'RETURNPENDING',
    'RETURNPROCESSED'
  )

  AND DATE(o.created_date, 'America/Los_Angeles') >= DATE '2026-01-01'-- update to 2027-01-01
  AND DATE(o.created_date, 'America/Los_Angeles') < DATE '2027-01-01'-- update to 2028-01-01

  AND li.rate_type IN (
    'Adult (13-64)',
    'Child (4-12)',
    'Senior (65+)',
    'Student (9-12)',
    'Student (K-8)',
    'Under 3'
  )

GROUP BY
  revenue_month_date,
  revenue_month,
  ticket_type

ORDER BY
  revenue_month_date,
  ticket_type;