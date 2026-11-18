-- Data-quality checks: Synthea data
-- Built from findings in 00_profile.sql.

-- ===== Priority: affect the Week 1 analysis =====

-- Check: each encounter CODE has exactly one DESCRIPTION (and the reverse)
-- Why: the cost and service-type questions group by CODE or DESCRIPTION
SELECT CODE, COUNT(DISTINCT DESCRIPTION) AS n
FROM 'encounters.csv'
GROUP BY CODE
HAVING COUNT(DISTINCT DESCRIPTION) > 1;

SELECT DESCRIPTION, COUNT(DISTINCT CODE) AS n
FROM 'encounters.csv'
GROUP BY DESCRIPTION
HAVING COUNT(DISTINCT CODE) > 1;
-- Result: no rows either way. CODE and DESCRIPTION are one-to-one.

-- Check: each encounter CODE sits under one ENCOUNTERCLASS
-- Why: Q10 compares classes, and price depends on the class
SELECT CODE, COUNT(DISTINCT ENCOUNTERCLASS) AS n
FROM 'encounters.csv'
GROUP BY CODE
HAVING COUNT(DISTINCT ENCOUNTERCLASS) > 1;

-- Investigate: which codes, and in which classes
SELECT DISTINCT CODE, DESCRIPTION, ENCOUNTERCLASS
FROM 'encounters.csv'
WHERE CODE IN (SELECT CODE
               FROM 'encounters.csv'
               GROUP BY CODE
               HAVING COUNT(DISTINCT ENCOUNTERCLASS) > 1)
ORDER BY CODE, ENCOUNTERCLASS;
-- Result: some CODEs appear under more than one ENCOUNTERCLASS. Not an error: ENCOUNTERCLASS classifies
-- the individual encounter (its setting), while CODE describes what the encounter was.

-- Check: each condition CODE has exactly one DESCRIPTION (and the reverse)
-- Why: Q3 to Q9 group conditions by CODE or DESCRIPTION
SELECT CODE, COUNT(DISTINCT DESCRIPTION) AS n
FROM 'conditions.csv'
GROUP BY CODE
HAVING COUNT(DISTINCT DESCRIPTION) > 1;

SELECT DESCRIPTION, COUNT(DISTINCT CODE) AS n
FROM 'conditions.csv'
GROUP BY DESCRIPTION
HAVING COUNT(DISTINCT CODE) > 1;
-- Result: no rows either way. CODE and DESCRIPTION are one-to-one.

-- Check: is BASE_ENCOUNTER_COST fixed by ENCOUNTERCLASS, by CODE, or by both together?
-- Why: Q2, Q3, Q9 and Q10 all use encounter cost
SELECT ENCOUNTERCLASS, COUNT(DISTINCT BASE_ENCOUNTER_COST) AS n
FROM 'encounters.csv'
GROUP BY ENCOUNTERCLASS
HAVING COUNT(DISTINCT BASE_ENCOUNTER_COST) > 1
ORDER BY ENCOUNTERCLASS;
-- Result: home, hospice, snf and urgentcare have one price each; the other classes have two.

SELECT CODE, COUNT(DISTINCT BASE_ENCOUNTER_COST) AS n
FROM 'encounters.csv'
GROUP BY CODE
HAVING COUNT(DISTINCT BASE_ENCOUNTER_COST) > 1
ORDER BY CODE;
-- Result: some CODEs have more than one price.

SELECT ENCOUNTERCLASS, CODE, COUNT(DISTINCT BASE_ENCOUNTER_COST) AS n
FROM 'encounters.csv'
GROUP BY ENCOUNTERCLASS, CODE
HAVING COUNT(DISTINCT BASE_ENCOUNTER_COST) > 1;
-- Result: no rows. Each ENCOUNTERCLASS and CODE pair has exactly one price.

-- Investigate: prices for codes used in more than one class
SELECT DISTINCT CODE, DESCRIPTION, ENCOUNTERCLASS, BASE_ENCOUNTER_COST
FROM 'encounters.csv'
WHERE CODE IN (SELECT CODE
               FROM 'encounters.csv'
               GROUP BY CODE
               HAVING COUNT(DISTINCT ENCOUNTERCLASS) > 1)
ORDER BY CODE, ENCOUNTERCLASS;
-- Finding: neither ENCOUNTERCLASS nor CODE sets the price alone; the combination does (like a fee schedule).

-- Investigate: every price, by class and by code
SELECT DISTINCT ENCOUNTERCLASS, BASE_ENCOUNTER_COST
FROM 'encounters.csv'
ORDER BY BASE_ENCOUNTER_COST DESC;

SELECT DISTINCT CODE, DESCRIPTION, ENCOUNTERCLASS, BASE_ENCOUNTER_COST
FROM 'encounters.csv'
ORDER BY BASE_ENCOUNTER_COST DESC, ENCOUNTERCLASS, CODE;
-- Finding: two price tiers. Named visit and admission codes cost $110.92-146.18 (highest in emergency and
--   inpatient); generic codes ("Encounter for problem", "Follow-up visit", "Check up") cost $75.00-87.71.
--   Within a CODE, class adds a small difference (virtual lowest). Both tiers are mostly "(procedure)", so the
--   SNOMED semantic tag doesn't explain price; the split between named and generic codes does.

-- Investigate: total and average base cost by class
SELECT ENCOUNTERCLASS,
       ROUND(SUM(BASE_ENCOUNTER_COST),2) AS total_base,
       ROUND(AVG(BASE_ENCOUNTER_COST),2) AS avg_base
FROM 'encounters.csv'
GROUP BY ENCOUNTERCLASS
ORDER BY total_base DESC;
-- Finding: ambulatory ($3.75M), wellness ($1.92M) and outpatient ($1.01M) hold about 88% of the $7.58M total;
--   emergency and inpatient together hold about 6%.
-- Impact: inpatient admissions (including ICU) cost the same as emergency visits ($146.18), so base cost doesn't
--   reflect real-world acuity or length of stay, and volume dominates any total. "Volume drives cost" holds for
--   this dataset but wouldn't carry over to real costs, where admissions cost far more than visits.
-- Impact: on base cost, differences in Q2, Q3, Q9 and Q10 reflect the mix of encounter types, not visit length
--   or complexity.

-- Check: TOTAL_CLAIM_COST range and distinct values, and whether it varies within a class and CODE pair
-- Why: Q2, Q3, Q9 and Q10 show it alongside base cost; Week 2 chooses which measure to carry forward
SELECT MAX(TOTAL_CLAIM_COST) AS max_claim_cost,
       MIN(TOTAL_CLAIM_COST) AS min_claim_cost,
       (SELECT COUNT(*) FROM
                            (SELECT DISTINCT CODE, ENCOUNTERCLASS FROM 'encounters.csv')
                            ) AS code_enc_pairs,
       (SELECT COUNT(*) FROM
                            (SELECT DISTINCT CODE, ENCOUNTERCLASS, TOTAL_CLAIM_COST FROM 'encounters.csv')
                            ) AS code_enc_total_pairs,
       COUNT(DISTINCT BASE_ENCOUNTER_COST) AS distinct_base_cost,
       COUNT(DISTINCT TOTAL_CLAIM_COST) AS distinct_claim_cost,
       (SELECT COUNT(*) FROM (SELECT DISTINCT TOTAL_CLAIM_COST - BASE_ENCOUNTER_COST FROM 'encounters.csv')) AS distinct_total_sub_base
  FROM 'encounters.csv';

-- Check: rows where TOTAL_CLAIM_COST < BASE_ENCOUNTER_COST
SELECT COUNT(*) AS n
  FROM 'encounters.csv'
 WHERE BASE_ENCOUNTER_COST > TOTAL_CLAIM_COST;

-- Result: no NULLs (see 00_profile.sql). 0 rows below base; 59,347 (88%) above base; 7,974 (12%) equal to base.
-- Finding: consistent with TOTAL_CLAIM_COST being base plus extras (e.g. medications, procedures). It varies per
--   visit (17,995 distinct class, CODE and cost combinations against 78 class and CODE pairs) and ranges from
--   $75 to $234,387.31, against $75-146.18 for base.
-- Finding: heavily right-skewed (see 00_profile.sql). Mean $2,688 against a median of about $906; middle half
--   about $525-2,208. Base cost is about 4% of total claim cost on average.
-- Q?: The $234k claim is one encounter with three conditions (see Q3); which encounter types carry the other
--   large claims?

-- ===== Week 3 =====

-- patients
-- Check: SSN shared by more than one patient (found: 999-41-9812)
-- Check: ZIP 00000 with NULL FIPS (possible placeholder data)
-- Check: oldest patients (born 1915) with no DEATHDATE

-- encounters
-- Check: encounters dated before the patient's BIRTHDATE
-- Check: encounter duration negative or implausibly long (needs Week 2 date arithmetic)

-- conditions
-- Check: conditions starting before the patient's BIRTHDATE

-- observations
-- Check: exact duplicate observations (found: 262 rows across 40 encounters)
-- Check: observations with no ENCOUNTER (found: 31,911); same rows as those with no CATEGORY?
-- Check: observation DATE outside its encounter's START and STOP
-- Check: each observation CODE has exactly one DESCRIPTION
-- Check: CODE X9999-2 (possible placeholder)
-- Check: numeric results with no UNITS; UNITS consistent per CODE
-- Check: VALUE consistent with TYPE and plausible per CODE

-- Types: FIPS read as BIGINT (should be text). CODE and REASONCODE in encounters and conditions read as BIGINT
-- (low risk; SNOMED IDs never start with 0). Fix types at load in Week 4.