CREATE OR REPLACE VIEW
rocket-rez-api.rocket_rez_ai.vw_thirty_day_headcount
AS

SELECT
  CAST(li.event.schedule.date AS DATE) AS visit_date,
  SUM(rt.quantity) AS headcount
FROM `rocket_rez_data.raw_data_history` r
LEFT JOIN UNNEST(IFNULL(r.lineItems, [])) AS li
LEFT JOIN UNNEST(IFNULL(li.rateTypes, [])) AS rt
WHERE CAST(li.event.schedule.date AS DATE)
      BETWEEN DATE_SUB(CURRENT_DATE('America/Los_Angeles'), INTERVAL 30 DAY) -- no date change, remains dynamic
          AND DATE_SUB(CURRENT_DATE('America/Los_Angeles'), INTERVAL 1 DAY)
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
ORDER BY visit_date;