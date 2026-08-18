CREATE OR REPLACE VIEW
  `rocket-rez-api.rocket_rez_data.vw_total_revenue_per_visitor`
AS

WITH visitor_metrics AS (
  SELECT
    CAST(li.event.schedule.date AS DATE) AS visit_date,
    SUM(rt.quantity) AS visitors,
    SUM(rt.subTotal) AS revenue

  FROM `rocket-rez-api.rocket_rez_data.raw_data_history` AS r

  LEFT JOIN UNNEST(IFNULL(r.lineItems, [])) AS li
  LEFT JOIN UNNEST(IFNULL(li.rateTypes, [])) AS rt

  WHERE CAST(li.event.schedule.date AS DATE) >= DATE '2026-01-01'-- update to 2027-01-01
    AND CAST(li.event.schedule.date AS DATE) < DATE '2027-01-01'-- update to 2028-01-01

    AND li.type = 'Rate'

    AND rt.rateType IN (
      'Adult (13-64)',
      'Child (4-12)',
      'Senior (65+)',
      'Student (9-12)',
      'Student (K-8)',
      'Under 3'
    )

    AND UPPER(r.status) NOT IN (
      'CANCELLED',
      'VOID',
      'VOIDED',
      'RETURNPENDING',
      'RETURNPROCESSED'
    )

  GROUP BY visit_date
)

SELECT
  ROUND(SUM(revenue), 2) AS total_revenue,
  SUM(visitors) AS total_visitors,
  ROUND(
    SAFE_DIVIDE(
      SUM(revenue),
      SUM(visitors)
    ),
    2
  ) AS revenue_per_visitor

FROM visitor_metrics;