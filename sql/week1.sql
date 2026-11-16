-- Week 1: analysis questions on Synthea data
-- Overarching question: A population health manager wants to know which chronic or recurring
-- conditions, and which patient groups, drive the most encounters and cost, so they can decide where
-- prevention could reduce that cost.
-- Approach: identify the heaviest users (with the exposure-time limitation stated), compare their cost fairly,
-- find which chronic or recurring conditions they carry, then see who else has those conditions and what it costs.
--
-- Assumptions:
-- - "Preventable" is approximated as chronic (no STOP date) or recurring (same condition recorded
--   more than once for a patient), inspired by AIHW's potentially preventable hospitalisations.
--   A proper mapping to the AIHW condition list is out of scope for Week 1.
-- - Demographics means gender and county (age needs date arithmetic, so it's covered in Week 2).
-- - BASE_ENCOUNTER_COST is fixed per ENCOUNTERCLASS and CODE pair (see dq_checks.sql). It may reflect the
--   expected complexity of each encounter type, but not differences between individual visits of the same type.
-- - Encounter cost can't be split between the conditions recorded at an encounter. Q3 therefore shows the
--   cost of encounters where each condition appears (associated, not attributed): an encounter counts
--   towards every condition it records, so condition totals overlap and don't add up to total cost.
--   Totals across a group (Q9) count each encounter once.
--
-- Limitation: "frequent visitors" is ranked by lifetime encounter count. Synthea records whole lives, so older
-- or deceased patients have had longer to accumulate encounters; the top 10% may be older or sicker rather
-- than visiting more often. Week 2 re-ranks by encounters per year of record.

-- ===== Baseline: who and what drives activity =====

-- Q1. Which patients have the most encounters, and what are their gender and county?
-- Tables: patients, encounters | Technique: join, GROUP BY, CTE with subquery for percentages
-- Assumption: "most encounters" = top 10% of patients (116 of 1,159), chosen to cover the steep part of the skew.
-- Answer: Encounter volume is right-skewed: the top ~40 patients have 250-720 encounters each, the next ~50 have 100-250.
--   County: the top 10% come from 13 of the 14 counties, broadly in line with where patients live. The exception is
--   Barnstable: 5.95% of all patients but 12.07% of frequent visitors, about twice its share. The six counties with the most 
--   frequent visitors hold 73% of them: Middlesex (18, 15.52%), Worcester (17, 14.66%), Suffolk (15, 12.93%),
--   Barnstable (14, 12.07%), Plymouth (11, 9.48%) and Essex (10, 8.62%).
--   Gender: 54% female (63), 46% male (53), against 50.13% female (581), 49.87% male (578) across all patients.
--   A difference of about 5 patients out of 116 is within normal variation, so gender isn't a meaningful factor here.
--   Deceased: 37.93% of frequent visitors (44 of 116) have a DEATHDATE, against 13.72% (159 of 1,159) of all
--   patients. This supports the exposure-time limitation; Week 2 re-ranks by encounters per year of record.
--   Tie at the cut-off: patients 116-118 have the same count, so which two of the three are included is arbitrary, ranked by Id for consistency.
--   The effect on the results is negligible.

-- All patients by encounter count
SELECT p.Id AS patient, GENDER, COUNTY, COUNT(e.Id) AS encounters
FROM 'patients.csv' AS p
LEFT JOIN 'encounters.csv' AS e
  ON p.Id = e.PATIENT
GROUP BY p.Id, GENDER, COUNTY
ORDER BY encounters DESC, p.Id;

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
  ORDER BY encounters DESC, p.Id
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
  ORDER BY encounters DESC, p.Id
  LIMIT 116
)
SELECT GENDER, COUNT(*) AS patients,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM top_ten_percent), 2) AS percent_total
FROM top_ten_percent
GROUP BY GENDER;

-- Deceased share: top 10% frequent visitors
WITH top_ten_percent AS (
  SELECT p.Id AS patient, p.GENDER, p.COUNTY, p.DEATHDATE, COUNT(e.Id) AS encounters
  FROM 'patients.csv' AS p
  LEFT JOIN 'encounters.csv' AS e
    ON p.Id = e.PATIENT
  GROUP BY p.Id, p.GENDER, p.COUNTY, p.DEATHDATE
  ORDER BY encounters DESC, p.Id
  LIMIT 116
)

SELECT COUNT(DEATHDATE) AS num_deaths, 
       ROUND(COUNT(DEATHDATE) * 100.0/COUNT(patient) ,2) AS percent_deaths
FROM top_ten_percent;

-- Deceased share: all patients
SELECT COUNT(DEATHDATE) AS num_deaths,
       ROUND(COUNT(DEATHDATE) * 100.0/COUNT(*),2) AS percent_deaths
FROM  'patients.csv';

-- Q2. How does frequent visitors' (the top 10%) average cost per encounter compare with all patients?
-- Tables: patients, encounters | Technique: top-10% CTE plus IN, subquery for the overall average
-- Answer: Frequent visitors account for 41.97% of encounters (28,252 of 67,321) but average $102.05 per encounter,
--   15% below the other 90% ($120.22); against all encounters ($112.60) the gap looks smaller because their own
--   encounters pull the average down. Prices are fixed per class and CODE, so this reflects a cheaper mix of
--   encounter types, not lighter visits. Exposure-time limitation applies (see top). NOT IN is safe here: the list
--   comes from a primary key. Clean up this query with a CASE statement in Week 2.
-- Q?: Why is their mix cheaper? See candidate "encounter classes for frequent visitors".

-- Average cost: top 10% frequent visitors, all patients, and patients who aren't in the top 10%
WITH top_ten_percent AS (
  SELECT p.Id AS patient
  FROM 'patients.csv' AS p
  LEFT JOIN 'encounters.csv' AS e
    ON p.Id = e.PATIENT
  GROUP BY p.Id
  ORDER BY COUNT(e.Id) DESC, p.Id
  LIMIT 116
)

SELECT COUNT(*) AS num_freq_enc,
       ROUND(AVG(BASE_ENCOUNTER_COST),2) AS avg_freq_cost,
       (SELECT COUNT(*) FROM 'encounters.csv') AS num_all_enc,
       (SELECT ROUND(AVG(BASE_ENCOUNTER_COST),2) FROM 'encounters.csv') AS avg_all_cost,
       (SELECT COUNT(*) FROM 'encounters.csv' WHERE PATIENT NOT IN (SELECT patient FROM top_ten_percent)) AS num_rest_enc,
       (SELECT ROUND(AVG(BASE_ENCOUNTER_COST),2) FROM 'encounters.csv' WHERE PATIENT NOT IN (SELECT patient FROM top_ten_percent)) AS avg_rest_cost
FROM 'encounters.csv'
WHERE PATIENT IN (SELECT patient FROM top_ten_percent);

-- Q3. Which conditions are linked to the most encounters, and what is the total cost of the encounters where they appear?
-- Tables: conditions, encounters | Technique: join. Ranked by encounter count; cost shown as
-- cost_of_encounters_with_condition (associated, not attributed; see Assumptions)
-- Answer: Dental and respiratory infections lead: gingivitis (2,990 encounters, $381,749), viral sinusitis (1,159),
--   gingival disease (916), acute viral pharyngitis (725) and dental caries (719). Average cost per encounter varies
--   less than 2x across disorders ($83-146) while counts run from 1 to 2,990, so volume drives the totals; the
--   averages only reorder the middle (e.g. anemia above acute bronchitis). They reflect the setting where a
--   condition is recorded, not how sick the patient was (sepsis averages $87.71; see dq_checks.sql).
--   Chronic conditions (hypertension 234, ischemic heart disease 186) are undercounted because they're recorded
--   once, at diagnosis (see Assumptions). Dental conditions are also the most common AIHW potentially
--   preventable hospitalisation.
-- Q?: Which ENCOUNTERCLASS does each price belong to (e.g. is $146.18 emergency)?

SELECT c.CODE, 
       c.DESCRIPTION, 
       COUNT(c.ENCOUNTER) AS num_enc, 
       ROUND(SUM(e.BASE_ENCOUNTER_COST),2) AS total_enc_cost_with_condition,
       ROUND(AVG(e.BASE_ENCOUNTER_COST),2) AS avg_enc_cost_with_condition
FROM 'conditions.csv' AS c
LEFT JOIN 'encounters.csv' AS e
ON c.ENCOUNTER = e.Id
WHERE c.DESCRIPTION LIKE '%(disorder)'
GROUP BY c.CODE, c.DESCRIPTION
ORDER BY num_enc DESC, total_enc_cost_with_condition DESC, avg_enc_cost_with_condition; 

-- ===== The preventable group =====

-- Q4. Which conditions are most often ongoing (no STOP date)?
-- Tables: conditions | Technique: WHERE, GROUP BY
-- Answer:

-- Q5. Which conditions most often recur for the same patient?
-- Tables: conditions | Technique: GROUP BY with HAVING, inside a subquery in FROM
-- Answer:

-- ===== Who has them =====

-- Q6. Are frequent visitors (the top 10%) more likely than all patients to have a chronic or recurring condition?
-- Tables: patients, encounters, conditions | Technique: join of the top-10% CTE to conditions, COUNT(DISTINCT) patients
-- Answer:

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
-- Re-rank frequent visitors by encounters per year of record (birth to DEATHDATE or 2026-11-08), then revisit
-- their share of total encounter cost and compare with the lifetime ranking.
-- Frequent visitors' cost against all patients, side by side
-- Patients with chronic or recurring conditions: encounters per year and cost, against all patients
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
-- Hypothesis: encounter duration has a narrow range within each ENCOUNTERCLASS and CODE pair,
-- and BASE_ENCOUNTER_COST rises with average duration across pairs.

-- ===== Parked: Week 3 (window functions) =====
-- What is each frequent visitor's main reason for visiting?
-- Do patients whose encounters record no condition go on to develop conditions later?

-- ===== Parked: candidates =====
-- Which encounter classes make up frequent visitors' visits, compared with all encounters?
-- Encounters and total cost by class
-- Encounters per patient by county (a rate, like the NHS appointments-per-patient analysis)
-- Which types of condition are most common, by SNOMED semantic tag?
-- How many patients have both a chronic and a recurring condition?
-- Which observations are recorded alongside which conditions?
-- Observations per encounter by associated condition
-- Encounter cost by number of observations
-- Do conditions or observations vary by COUNTY?
-- Can REASONCODE attribute encounter cost to a condition? (Check how often it's filled first.)