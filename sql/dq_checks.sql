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
-- Why: the cost question compares classes
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
-- Impact: price may reflect the expected complexity of each encounter type, but not variation between
-- individual visits of the same type (e.g. a longer visit costs the same).
-- Impact: cost differences in Q2, Q3 and Q9 reflect the mix of encounter types, not visit length or complexity.

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