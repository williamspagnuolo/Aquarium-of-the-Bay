CREATE OR REPLACE VIEW
  `rocket-rez-api.rocket_rez_data.vw_average_daily_revenue`
AS

WITH daily_revenue_cte AS (
  SELECT
    DATE(o.created_date, 'America/Los_Angeles') AS revenue_date,
    SUM(li.line_item_subtotal) AS daily_revenue

  FROM `rocket-rez-api.rocket_rez_data.orders` AS o

  INNER JOIN `rocket-rez-api.rocket_rez_data.line_items` AS li
    ON o.order_id = li.order_id

  WHERE DATE(o.created_date, 'America/Los_Angeles') >= DATE '2026-01-01'-- update to 2027-01-01
    AND DATE(o.created_date, 'America/Los_Angeles') < DATE '2027-01-01'-- update to 2028-01-01

    AND UPPER(o.status) NOT IN (
      'CANCELLED',
      'VOID',
      'VOIDED',
      'RETURNPENDING',
      'RETURNPROCESSED'
    )

    AND li.rate_type IN (
      'Adult (13-64)',
      'Child (4-12)',
      'Senior (65+)',
      'Student (9-12)',
      'Student (K-8)',
      'Under 3'
    )

  GROUP BY revenue_date
)

SELECT
  ROUND(AVG(daily_revenue), 2) AS average_daily_revenue
FROM daily_revenue_cte;