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
-- - Cost: BASE_ENCOUNTER_COST is fixed per ENCOUNTERCLASS and CODE pair (see dq_checks.sql) and only ranges
--   from $75 to $146.18: named visit and admission codes sit in the top tier, generic encounter codes in the
--   bottom tier. Inpatient admissions cost the same as emergency visits, so base cost doesn't reflect real-world
--   acuity or length of stay, and volume dominates any total. TOTAL_CLAIM_COST varies by visit and likely adds
--   medications and procedures. Q2, Q3, Q9 and Q10 show both measures; Week 2 chooses which to carry forward.
-- - Encounter cost can't be split between the conditions recorded at an encounter. Q3 therefore shows the
--   cost of encounters where each condition appears (associated, not attributed): an encounter counts
--   towards every condition it records, so condition totals overlap and don't add up to total cost.
--   Totals across a group (Q9) count each encounter once.
-- - "Condition" means SNOMED disorders only (DESCRIPTION LIKE '%(disorder)'), from Q3 onwards. This excludes
--   social determinants, admin flags and history items recorded as findings or situations, and lines up with
--   the AIHW list (all disorders). It also drops clinical risk factors such as prediabetes and obesity, and a
--   few untagged rows (e.g. Gout); refining the list is a candidate for Week 2 (CASE).
-- - conditions.ENCOUNTER is the encounter where a condition was recorded (diagnosis, or the start of a new
--   episode), not every visit where it was managed. Checked: hypertension has 234 rows for 234 patients.
--   So Q3 covers recording encounters only and undercounts chronic conditions; Q9 works at patient level.
--   Follow-up visits may link through encounters.REASONCODE (candidate).
-- - Joins: the base table comes first, and enrichment joins are LEFT JOINs even where profiling found no
--   orphans, so rows never drop if the data changes. Joins that are meant to filter are written as INNER JOIN.
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
--   Tie at the cut-off: patients 116-118 have the same count. Ties are broken by Id, so the same two are included
--   every time. The effect on the results is negligible.

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

-- Q2. How does frequent visitors' (the top 10%) average cost per encounter compare with all patients and with
--     the other 90%?
-- Tables: patients, encounters | Technique: top-10% CTE plus IN and NOT IN, scalar subqueries for the other
--   averages. Base and total claim cost.
-- Answer: Frequent visitors account for 41.97% of encounters (28,252 of 67,321) but cost less per encounter on
--   both measures.
--   Base cost: $102.05 against $120.22 for the other 90% (15% lower) and $112.60 overall. Prices are fixed per
--   class and CODE, so this reflects a cheaper mix of encounter types, not lighter visits.
--   Total claim cost: $2,141.00 against $3,083.89 for the other 90% (31% lower) and $2,688.19 overall. Claim costs
--   are heavily skewed (see dq_checks.sql), so a few large claims among the other 90% could drive part of this
--   gap; medians are a Week 2 check.
--   Caveats: against all encounters the gap looks smaller because frequent visitors' own encounters pull the
--   average down. Exposure-time limitation applies (see top).
-- Notes: NOT IN is safe here because the list comes from a primary key. Rewrite with CASE in Week 2.
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

SELECT COUNT(*) AS num_freq_patients_encounters,
       ROUND(AVG(BASE_ENCOUNTER_COST),2) AS avg_freq_patients_base_cost,
       ROUND(AVG(TOTAL_CLAIM_COST),2) AS avg_freq_patients_total_cost,
       (SELECT COUNT(*) FROM 'encounters.csv') AS num_all_patients_encounters,
       (SELECT ROUND(AVG(BASE_ENCOUNTER_COST),2) FROM 'encounters.csv') AS avg_all_patients_base_cost,
       (SELECT ROUND(AVG(TOTAL_CLAIM_COST),2) FROM 'encounters.csv') AS avg_all_patients_total_cost,
       (SELECT COUNT(*) FROM 'encounters.csv' WHERE PATIENT NOT IN (SELECT patient FROM top_ten_percent)) AS num_not_freq_encounters,
       (SELECT ROUND(AVG(BASE_ENCOUNTER_COST),2) FROM 'encounters.csv' WHERE PATIENT NOT IN (SELECT patient FROM top_ten_percent)) AS avg_not_freq_base_cost,
       (SELECT ROUND(AVG(TOTAL_CLAIM_COST),2) FROM 'encounters.csv' WHERE PATIENT NOT IN (SELECT patient FROM top_ten_percent)) AS avg_not_freq_total_cost
FROM 'encounters.csv'
WHERE PATIENT IN (SELECT patient FROM top_ten_percent);

-- Q3. Which conditions are linked to the most encounters, and what is the total cost of the encounters where they appear?
-- Tables: conditions, encounters | Technique: join. Ranked by encounter count; base and total claim cost shown as
--   total and average cost of encounters with the condition (associated, not attributed; see Assumptions).
--   Disorders only.
-- Answer: By encounter count, dental and respiratory infections lead: gingivitis (2,990), viral sinusitis (1,159),
--   gingival disease (916), acute viral pharyngitis (725) and dental caries (719).
--   Base cost: average cost per encounter varies less than 2x across disorders ($83-146) while counts run from 1 to
--   2,990, so volume drives the totals (prices are nearly flat; see Assumptions). Averages reflect the setting
--   where a condition is recorded, not how sick the patient was (sepsis averages $87.71).
--   Total claim cost: the ranking changes. Dental disorders still lead (gingival disease $4.53M, gingivitis $4.15M,
--   dental caries $2.76M), but low-volume acute conditions rise sharply (polyp of colon: 81 encounters, $1.94M;
--   sepsis: 26 encounters averaging $47,795), and viral sinusitis drops because its claims equal base. So claim
--   cost reflects what happens at the visit, not just volume.
--   Caveats: chronic conditions (hypertension 234, ischemic heart disease 186) are undercounted because they're
--   recorded once, at diagnosis. The largest claim ($234,387) is one encounter recorded against three conditions,
--   which shows why condition totals overlap. Dental conditions are also the most common AIHW potentially
--   preventable hospitalisation.
-- Answered 17 Nov: $146.18 is the top price for emergency and inpatient encounters (see dq_checks.sql).

SELECT c.CODE,
       c.DESCRIPTION,
       COUNT(c.ENCOUNTER) AS num_enc,
       ROUND(SUM(e.TOTAL_CLAIM_COST),2) AS total_enc_claim_with_disorder,
       ROUND(AVG(e.TOTAL_CLAIM_COST),2) AS avg_enc_claim_with_disorder,
       ROUND(SUM(e.BASE_ENCOUNTER_COST),2) AS total_enc_base_with_disorder,
       ROUND(AVG(e.BASE_ENCOUNTER_COST),2) AS avg_enc_base_with_disorder
FROM 'conditions.csv' AS c
LEFT JOIN 'encounters.csv' AS e
  ON c.ENCOUNTER = e.Id
WHERE c.DESCRIPTION LIKE '%(disorder)'
GROUP BY c.CODE, c.DESCRIPTION
ORDER BY num_enc DESC, total_enc_claim_with_disorder DESC;
-- To see the claim-cost ranking, sort by total_enc_claim_with_disorder DESC instead.

-- ===== The preventable group =====

-- Q4. Which conditions are most often ongoing (no STOP date)?
-- Tables: conditions | Technique: WHERE, GROUP BY
-- Answer: Ongoing disorders are led by a cardiometabolic cluster: essential hypertension (234 patients, 20.19%),
--   ischemic heart disease (186, 16.05%), metabolic syndrome (158, 13.63%), hyperlipidemia (120, 10.35%), and
--   type 2 diabetes with its kidney complications (diabetic kidney disorder 100, microalbuminuria 80, type 2
--   diabetes 78, CKD stages 1-4). This matches AIHW's chronic preventable conditions (diabetes complications,
--   hypertension, angina, heart failure). Anemia (381, 32.87%) and chronic sinusitis (226, 19.50%) are the other
--   large groups. Every ongoing disorder has one record per patient, consistent with recording at diagnosis.
--   Without the disorder filter, ongoing records are led by admin and social findings (medication review due 638,
--   full-time employment 600).
--   Caveat: some acute disorders have no STOP (all 26 sepsis records, acute MI 46, septic shock 9, pneumonia 8).
--   These likely ended at death or were open on the reference date, so "no STOP" isn't always chronic.
-- Q?: Do acute disorders with no STOP belong to deceased patients? (Week 2: compare with DEATHDATE.)

SELECT CODE, DESCRIPTION, COUNT (*) AS n
FROM 'conditions.csv'
WHERE STOP IS NULL 
GROUP BY CODE, DESCRIPTION
ORDER BY n DESC;

SELECT CODE, 
       DESCRIPTION, 
       COUNT(DISTINCT PATIENT) AS patients,
       ROUND(COUNT(DISTINCT PATIENT) * 100.0 / (SELECT COUNT(*) FROM 'patients.csv'),2) AS percent_total       
FROM 'conditions.csv'
WHERE STOP IS NULL AND DESCRIPTION LIKE '%(disorder)' 
GROUP BY CODE, DESCRIPTION
ORDER BY patients DESC;

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

-- Q9. What is the total and average cost of all encounters for patients with a chronic or recurring condition?
-- Tables: encounters, conditions | Technique: IN subquery on PATIENT (counts each encounter once)
-- Note: works at patient level because conditions are recorded once, at diagnosis (see Assumptions).
--   Includes visits before diagnosis; filtering those out needs date arithmetic (Week 2).
--   Shows both BASE_ENCOUNTER_COST and TOTAL_CLAIM_COST.
-- Answer:

-- Q10. Which encounters record no condition at all, what class are they, and what do they cost?
-- Tables: encounters, conditions | Technique: LEFT JOIN that changes the answer
-- Note: shows both BASE_ENCOUNTER_COST and TOTAL_CLAIM_COST.
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
-- Encounters and total cost by class (explored 17 Nov: ambulatory, wellness and outpatient hold ~88% of base
--   cost; see dq_checks.sql)
-- Encounters per patient by county (a rate, like the NHS appointments-per-patient analysis)
-- Which types of condition are most common, by SNOMED semantic tag?
-- How many patients have both a chronic and a recurring condition?
-- Which observations are recorded alongside which conditions?
-- Observations per encounter by associated condition
-- Encounter cost by number of observations
-- Do conditions or observations vary by COUNTY?
-- Can REASONCODE attribute encounter cost to a condition? (Filled for ~65% of encounters, 18 Nov.)