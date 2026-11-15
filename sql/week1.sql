-- Week 1: analysis questions on Synthea data
-- Overarching question: A population health manager wants to know which chronic or recurring
-- conditions, and which patient groups, drive the most encounters and cost, so they can decide where
-- prevention could reduce that cost.
--
-- Assumptions:
-- - "Preventable" is approximated as chronic (no STOP date) or recurring (same condition recorded
--   more than once for a patient), inspired by AIHW's potentially preventable hospitalisations.
--   A proper mapping to the AIHW condition list is out of scope for Week 1.
-- - Demographics means gender and county (age needs date arithmetic, so it's covered in Week 2).
-- - Encounter cost can't be split between the conditions recorded at an encounter. Q4 therefore shows the
--   cost of encounters where each condition appears (associated, not attributed): an encounter counts
--   towards every condition it records, so condition totals overlap and don't add up to total cost.
--   Totals across a group (Q9) count each encounter once.
-- - Cost is BASE_ENCOUNTER_COST, checked for consistency in dq_checks.sql first.
-- - BASE_ENCOUNTER_COST is fixed per ENCOUNTERCLASS and CODE pair (see dq_checks.sql). It may reflect the
--   expected complexity of each encounter type, but not differences between individual visits of the same type.

-- ===== Baseline: who and what drives activity =====

-- Q1. Which patients have the most encounters, and what are their gender and county?
-- Tables: patients, encounters | Technique: join, GROUP BY, CTE with subquery for percentages
-- Assumption: "most encounters" = top 10% of patients (116 of 1,159), chosen to cover the steep part of the skew.
-- Answer: Encounter volume is right-skewed: the top ~40 patients have 250-720 encounters each, the next ~50 have 100-250.
--   County: the top 10% come from 13 of the 14 counties, broadly in line with where patients live. The exception is
--   Barnstable: 5.95% of all patients but 12.07% of frequent visitors, about twice its share. The six largest counties
--   hold 73% of frequent visitors: Middlesex (18, 15.52%), Worcester (17, 14.66%), Suffolk (15, 12.93%),
--   Barnstable (14, 12.07%), Plymouth (11, 9.48%) and Essex (10, 8.62%).
--   Gender: 54% female (63), 46% male (53), against 50.13% female (581), 49.87% male (578) across all patients.
--   A difference of about 5 patients out of 116 is within normal variation, so gender isn't a meaningful factor here.
--   Tie at the cut-off: patients 116-118 have the same count, so which two of the three are included is arbitrary.
--   The effect on the results is negligible.

-- All patients by encounter count
SELECT p.Id AS patient, GENDER, COUNTY, COUNT(e.Id) AS encounters
FROM 'patients.csv' AS p
LEFT JOIN 'encounters.csv' AS e
  ON p.Id = e.PATIENT
GROUP BY p.Id, GENDER, COUNTY
ORDER BY encounters DESC;

-- Baseline: all patients by county
SELECT COUNTY, COUNT(*) AS patients,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM 'patients.csv'), 2) AS percent_total
FROM 'patients.csv'
GROUP BY COUNTY
ORDER BY percent_total DESC;

-- Baseline: all patients by gender
SELECT GENDER, COUNT(*) AS patients,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM 'patients.csv'), 2) AS percent_total
FROM 'patients.csv'
GROUP BY GENDER;

-- Top 10% by county
WITH top_ten_percent AS (
  SELECT p.Id AS patient, GENDER, COUNTY, COUNT(e.Id) AS encounters
  FROM 'patients.csv' AS p
  LEFT JOIN 'encounters.csv' AS e
    ON p.Id = e.PATIENT
  GROUP BY p.Id, GENDER, COUNTY
  ORDER BY encounters DESC
  LIMIT 116
)
SELECT COUNTY, COUNT(*) AS patients,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM top_ten_percent), 2) AS percent_total
FROM top_ten_percent
GROUP BY COUNTY
ORDER BY percent_total DESC;

-- Top 10% by gender
WITH top_ten_percent AS (
  SELECT p.Id AS patient, GENDER, COUNTY, COUNT(e.Id) AS encounters
  FROM 'patients.csv' AS p
  LEFT JOIN 'encounters.csv' AS e
    ON p.Id = e.PATIENT
  GROUP BY p.Id, GENDER, COUNTY
  ORDER BY encounters DESC
  LIMIT 116
)
SELECT GENDER, COUNT(*) AS patients,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM top_ten_percent), 2) AS percent_total
FROM top_ten_percent
GROUP BY GENDER;

-- Q2. For the 10 most frequent visitors, which encounter classes make up their visits?
-- Tables: encounters | Technique: IN subquery (top 10 patients)
-- Answer:

-- Q3. Which encounter classes account for the most encounters and the most total cost?
-- Tables: encounters | Technique: GROUP BY
-- Answer:

-- Q4. Which conditions are linked to the most encounters, and what is the total cost of the encounters where they appear?
-- Tables: conditions, encounters | Technique: join. Ranked by encounter count; cost shown as
-- cost_of_encounters_with_condition (associated, not attributed; see Assumptions)
-- Answer:

-- ===== The preventable group =====

-- Q5. Which conditions are most often ongoing (no STOP date)?
-- Tables: conditions | Technique: WHERE, GROUP BY
-- Answer:

-- Q6. Which conditions most often recur for the same patient?
-- Tables: conditions | Technique: GROUP BY with HAVING, inside a subquery in FROM
-- Answer:

-- ===== Who has them =====

-- Q7. How many patients have at least one chronic or recurring condition, by gender and county?
-- Tables: patients, conditions | Technique: IN subqueries
-- Answer:

-- Q8. How do patients with neither a chronic nor a recurring condition compare, by gender and county?
-- Tables: patients, conditions | Technique: NOT EXISTS (correlated subquery)
-- Answer:

-- ===== What it costs =====

-- Q9. What is the total and average cost of encounters linked to a chronic or recurring condition?
-- Tables: encounters, conditions | Technique: IN subquery (counts each encounter once)
-- Answer:

-- Q10. Which encounters record no condition at all, what class are they, and what do they cost?
-- Tables: encounters, conditions | Technique: LEFT JOIN that changes the answer
-- Answer:

-- ===== Parked: Week 2 (dates, CASE, CTEs) =====
-- Compare encounters with and without a chronic or recurring condition side by side (count, total and average cost)
-- Demographics by age for frequent visitors and for patients with chronic or recurring conditions
-- How do conditions change with patient age?
-- How do observations change with patient age?
-- Do encounter START dates cluster by month?
-- Average encounter duration by gender, county and age
-- Average encounter duration by associated condition
-- Is encounter duration associated with cost or encounter class?
-- Do long encounters cluster by condition?
-- Observations per encounter by encounter duration
-- Typical income, expenses and coverage by area (LAT and LON)
-- Hypothesis (Week 2): encounter duration has a narrow range within each ENCOUNTERCLASS and CODE pair,
-- and BASE_ENCOUNTER_COST rises with average duration across pairs.

-- ===== Parked: Week 3 (window functions) =====
-- What is each frequent visitor's main reason for visiting?
-- Do patients whose encounters record no condition go on to develop conditions later?

-- ===== Parked: candidates =====
-- Which types of condition are most common, by SNOMED semantic tag?
-- How many patients have both a chronic and a recurring condition?
-- Which observations are recorded alongside which conditions?
-- Observations per encounter by associated condition
-- Encounter cost by number of observations
-- Do conditions or observations vary by COUNTY?
-- Can REASONCODE attribute encounter cost to a condition? (Check how often it's filled first.)