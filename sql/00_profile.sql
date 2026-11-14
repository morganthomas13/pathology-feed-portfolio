-- Data: Synthea run on 8 Nov 2026
-- java -jar synthea-with-dependencies.jar -p 1000 -s 42 -cs 42 -r 20261108 --exporter.csv.export true --exporter.fhir.export false
-- Profiling approach: grain, shape, column profile, duplicates, category values

-- ===== patients =====

-- Grain
SELECT * FROM 'patients.csv' LIMIT 10;
-- Obs: One row per patient, with their demographics. Id is a long hyphenated alphanumeric string.
-- Obs: DEATHDATE mostly NULL in the sample, as expected for living patients.
-- Obs: Names (first, middle, last, maiden) end in digits. Synthea does this on purpose to mark records as synthetic.
-- DQ: At least one patient has ZIP 00000 and a NULL FIPS; possibly placeholder data.

-- Size and shape
SELECT COUNT(*) FROM 'patients.csv';
DESCRIBE 'patients.csv';
-- Obs: 1,159 rows, matching the Synthea run. Date columns typed correctly. INCOME is BIGINT (whole dollars), which is fine.

-- Column profile
SUMMARIZE 'patients.csv';
-- Obs: All patients are in Massachusetts, so STATE adds nothing.
-- Obs: NULLs only in DEATHDATE, DRIVERS, PASSPORT, PREFIX, MIDDLE, SUFFIX, MAIDEN, MARITAL and FIPS.
--      DEATHDATE mostly NULL (expected). MAIDEN and SUFFIX mostly NULL, so mainly useful for telling apart
--      otherwise matching patients. MARITAL about 35% NULL; the rest about 20-25%.
-- Obs: Categorical columns all have a reasonable spread of values.
-- Obs: SSN approx_unique is 1,148 against 1,159 rows. approx_unique is an estimate, so checked exactly under Duplicates.
-- DQ: FIPS should be text, not a BIGINT. It's a code, and codes starting with 0 (e.g. Alabama 01) lose the leading zero.
-- Q?: Oldest birthdate is 1915. Do the oldest patients have a DEATHDATE? Alive in 2026 would make them 110+.
-- Q?: LAT and LON could show typical income, expenses and coverage by area.

-- Duplicates
SELECT COUNT(*) FROM (SELECT DISTINCT * FROM 'patients.csv');
-- Obs: 1,159 distinct rows, so no whole-row duplicates.

SELECT Id, COUNT(*) AS n
FROM 'patients.csv'
GROUP BY Id
HAVING COUNT(*) > 1;
-- Obs: No rows returned, so Id is unique.

SELECT birthdate
      ,deathdate
      ,SSN
      ,first
      ,last
      ,gender
      ,COUNT(*) AS n
FROM 'patients.csv'
GROUP BY birthdate
      ,deathdate
      ,SSN
      ,first
      ,last
      ,gender
HAVING COUNT(*) > 1;
-- Obs: No rows returned, so no patient appears twice under different Ids.

SELECT SSN
      ,COUNT(*) AS n
FROM 'patients.csv'
GROUP BY SSN
HAVING COUNT(*) > 1;
-- DQ: SSN 999-41-9812 is shared by more than one patient. The query above shows they differ on
--     name, birthdate or gender, so these are different people sharing one SSN.

-- Category values
SELECT prefix, LENGTH(prefix) AS len, COUNT(*) AS n
FROM 'patients.csv'
GROUP BY prefix
ORDER BY prefix;
-- Obs: Mr., Mrs., Ms.: clean.

SELECT MARITAL, LENGTH(MARITAL) AS len, COUNT(*) AS n
FROM 'patients.csv'
GROUP BY MARITAL
ORDER BY MARITAL;
-- Obs: D, M, S, W: clean.

SELECT RACE, LENGTH(RACE) AS len, COUNT(*) AS n
FROM 'patients.csv'
GROUP BY RACE
ORDER BY RACE;
-- Obs: asian, black, hawaiian, native, other, white: clean.

SELECT ETHNICITY, LENGTH(ETHNICITY) AS len, COUNT(*) AS n
FROM 'patients.csv'
GROUP BY ETHNICITY
ORDER BY ETHNICITY;
-- Obs: hispanic and nonhispanic only, no NULLs: clean.

SELECT GENDER, LENGTH(GENDER) AS len, COUNT(*) AS n
FROM 'patients.csv'
GROUP BY GENDER
ORDER BY GENDER;
-- Obs: Two categories, roughly even split: clean.

-- Missing values, data types and ranges: covered by SUMMARIZE above.
-- Orphan checks: not applicable (patients is the parent table).

-- ======================
-- ===== encounters =====

-- Grain
SELECT * FROM 'encounters.csv' LIMIT 10;
-- Obs: One row per encounter (visit). Id, PATIENT, ORGANIZATION, PROVIDER and PAYER all use the same long ID format.
-- Q?: ENCOUNTERCLASS looks like a grouping of CODE. Does each CODE sit under one class?
-- Q?: DESCRIPTION looks like the text for CODE. Is there exactly one DESCRIPTION per CODE?
-- Q?: The sample hinted at START dates clustering around Oct, Jan and Mar. Check by month.

-- Size and shape
SELECT COUNT(*) FROM 'encounters.csv';
DESCRIBE 'encounters.csv';
-- Obs: 67,321 rows. All types as expected except CODE and REASONCODE, read as BIGINT.
-- Obs: CODE and REASONCODE are SNOMED CT codes. SNOMED IDs never start with 0, so BIGINT loses nothing here,
--      but they're identifiers, so text is the better type (low risk).
-- Q?: Which patients are frequent visitors, and for what?

-- Column profile
SUMMARIZE 'encounters.csv';
-- Obs: Earliest START is 1917, consistent with the oldest patients (born 1915).
-- Obs: Every START has a STOP. NULLs only in REASONCODE and REASONDESCRIPTION.
-- Obs: approx_unique: CODE and DESCRIPTION about equal; ENCOUNTERCLASS smaller; BASE_ENCOUNTER_COST about 11.
--      These are estimates, so exact checks below.
-- Q?: Encounter duration (STOP - START): are any negative or implausibly long?
-- Q?: Is no encounter dated before the patient's BIRTHDATE?

-- Duplicates
SELECT COUNT(*) FROM (SELECT DISTINCT * FROM 'encounters.csv');
-- Obs: 67,321 distinct rows, so no whole-row duplicates.

SELECT Id, COUNT(*) AS n
FROM 'encounters.csv'
GROUP BY Id
HAVING COUNT(*) > 1;
-- Obs: No rows returned, so Id is unique.

-- Category values
SELECT ENCOUNTERCLASS, LENGTH(ENCOUNTERCLASS) AS len, COUNT(*) AS n
FROM 'encounters.csv'
GROUP BY ENCOUNTERCLASS
ORDER BY ENCOUNTERCLASS;
-- Obs: 10 classes: clean.

SELECT DISTINCT CODE
FROM 'encounters.csv'
ORDER BY CODE DESC;
-- Obs: Visual check: clean.

SELECT DESCRIPTION, LENGTH(DESCRIPTION) AS len, COUNT(*) AS n
FROM 'encounters.csv'
GROUP BY DESCRIPTION
ORDER BY DESCRIPTION;
-- Obs: Clean, and the same number of DESCRIPTIONs as CODEs.
-- Q?: DESCRIPTIONs fall into broader types (therapy, procedure and so on). Where does the service spend most of its time?
-- Q?: Which encounter types are most expensive? Which PAYERs provide the most coverage? Which types of encounters are most covered?
-- Q?: About 11 BASE_ENCOUNTER_COST values against 10 classes. Is cost fixed by class, CODE or neither?
--     Group CODE, DESCRIPTION and BASE_ENCOUNTER_COST to find out.

-- Orphan check
SELECT COUNT(*) AS orphans
FROM 'encounters.csv' c
LEFT JOIN 'patients.csv' p ON c.PATIENT = p.Id
WHERE p.Id IS NULL;
-- Obs: 0 orphans: every encounter links to a patient.

-- Volume check
SELECT COUNT(DISTINCT PATIENT) AS patients_referred_to
FROM 'encounters.csv';
-- Obs: 1,159, matching patients. Every patient has at least one encounter.

-- ======================
-- ===== conditions =====
-- Grain
SELECT * FROM 'conditions.csv' LIMIT 10;
-- Obs: One row per SNOMED CT condition code recorded for a patient at an encounter. PATIENT and ENCOUNTER are foreign keys.
-- Obs: DESCRIPTION is the readable text for CODE.
-- Q?: Confirm the code system for CODE.
-- Q?: DESCRIPTIONs end in SNOMED semantic tags such as (disorder) and (situation). Which types of condition are most common?

-- Size and shape
SELECT COUNT(*) FROM 'conditions.csv';
DESCRIBE 'conditions.csv';
-- Obs: 40,041 rows. All types as expected except CODE, read as BIGINT. As with encounters: SNOMED IDs never start
--      with 0, so nothing is lost, but text is the better type for identifiers (low risk).

-- Column profile
SUMMARIZE 'conditions.csv';
-- Obs: About 25% of conditions have no STOP, likely ongoing conditions.
-- Obs: START and STOP ranges look plausible overall. A per-patient check (nothing before BIRTHDATE) is for Week 3.

-- Duplicates
SELECT COUNT(*) FROM (SELECT DISTINCT * FROM 'conditions.csv');
-- Obs: 40,041 distinct rows, so no whole-row duplicates.

SELECT PATIENT, ENCOUNTER, CODE, COUNT(*) AS n
FROM 'conditions.csv'
GROUP BY PATIENT, ENCOUNTER, CODE
HAVING COUNT(*) > 1;
-- Obs: No rows returned, so no CODE is recorded twice for the same patient at the same encounter.

-- Category values
SELECT DISTINCT CODE
FROM 'conditions.csv'
ORDER BY CODE DESC;
-- Obs: Visual check of codes: clean.

-- Orphan checks
SELECT COUNT(*) AS orphans
FROM 'conditions.csv' c
LEFT JOIN 'encounters.csv' e ON c.ENCOUNTER = e.Id
WHERE e.Id IS NULL;
-- Obs: 0 orphans: every condition links to an encounter.

SELECT COUNT(*) AS orphans
FROM 'conditions.csv' c
LEFT JOIN 'patients.csv' p ON c.PATIENT = p.Id
WHERE p.Id IS NULL;
-- Obs: 0 orphans: every condition links to a patient.

-- Volume checks
SELECT COUNT(DISTINCT PATIENT) AS patients_referred_to
FROM 'conditions.csv';
-- Obs: 1,159, matching patients. Every patient has at least one condition.

SELECT COUNT(DISTINCT ENCOUNTER) AS encounters_referred_to
FROM 'conditions.csv';
-- Obs: 25,832 of 67,321 encounters have a condition recorded. Expected: not every encounter records a condition.
-- Q?: Which kinds of encounter don't record a condition?


-- ========================
-- ===== observations =====

-- Grain
SELECT * FROM 'observations.csv' LIMIT 10;
-- Obs: One row per observation (measurement or result) for a patient, with a single DATE timestamp. PATIENT and ENCOUNTER are foreign keys.
-- Q?: Do observation DATEs fall within their encounter's START and STOP?
-- Q?: Does each CODE have exactly one DESCRIPTION?
-- Q?: Are UNITS consistent per CODE, and VALUEs plausible?

-- Size and shape
SELECT COUNT(*) FROM 'observations.csv';
DESCRIBE 'observations.csv';
-- Obs: 802,996 rows, so most encounters carry several observations.
-- Obs: VALUE is VARCHAR, because results can be numbers or text. CODE is VARCHAR because LOINC codes include a hyphen
--      (e.g. 718-7), so it's correctly read as text here.

-- Column profile
SUMMARIZE 'observations.csv';
-- Obs: DATE range looks plausible overall.
-- Obs: Small percentage of NULLs in ENCOUNTER, and about the same in CATEGORY.
-- Obs: Small percentage of NULL UNITS; not every observation needs units (e.g. text results).
-- Q?: Are the observations with no ENCOUNTER the same rows as those with no CATEGORY?
-- DQ: Highest CODE is X9999-2. Check whether it's a placeholder.
-- Q?: Is VALUE consistent with TYPE and plausible for each CODE?

-- Duplicates
SELECT COUNT(*) FROM (SELECT DISTINCT * FROM 'observations.csv');
-- Obs: 802,734 distinct rows against 802,996, so 262 rows are exact duplicates.

SELECT DATE, PATIENT, ENCOUNTER, CATEGORY, CODE, DESCRIPTION, VALUE, UNITS, TYPE, COUNT(*) AS n
FROM 'observations.csv'
GROUP BY DATE, PATIENT, ENCOUNTER, CATEGORY, CODE, DESCRIPTION, VALUE, UNITS, TYPE
HAVING COUNT(*) > 1
ORDER BY DATE, PATIENT, ENCOUNTER;
-- Obs: 262 duplicated groups, consistent with each duplicate appearing exactly twice.

SELECT PATIENT, ENCOUNTER, COUNT(*) AS duplicated_groups
FROM (SELECT DATE, PATIENT, ENCOUNTER, CATEGORY, CODE, DESCRIPTION, VALUE, UNITS, TYPE
        FROM 'observations.csv'
       GROUP BY DATE, PATIENT, ENCOUNTER, CATEGORY, CODE, DESCRIPTION, VALUE, UNITS, TYPE
      HAVING COUNT(*) > 1) AS dups
GROUP BY PATIENT, ENCOUNTER;
-- DQ: 262 exact duplicate observations across 40 patient encounters.

-- Category values
SELECT CATEGORY, LENGTH(CATEGORY) AS len, COUNT(*) AS n
FROM 'observations.csv'
GROUP BY CATEGORY
ORDER BY CATEGORY;
-- Obs: 8 categories: clean.

SELECT UNITS, LENGTH(UNITS) AS len, COUNT(*) AS n
FROM 'observations.csv'
GROUP BY UNITS
ORDER BY UNITS;
-- Obs: 50 distinct UNITS, all plausible.
-- DQ: Check UNITS match each CODE's measurement and TYPE (e.g. numeric results with no units).

SELECT TYPE, LENGTH(TYPE) AS len, COUNT(*) AS n
FROM 'observations.csv'
GROUP BY TYPE
ORDER BY TYPE;
-- Obs: numeric and text only: clean.

-- Orphan checks
SELECT COUNT(*) - COUNT(ENCOUNTER) AS missing_encounter
FROM 'observations.csv';
-- Obs: 31,911 observations have no ENCOUNTER.

SELECT COUNT(*) AS orphans
FROM 'observations.csv' o
LEFT JOIN 'encounters.csv' e ON o.ENCOUNTER = e.Id
WHERE e.Id IS NULL;
-- Obs: 31,911 apparent orphans. A NULL ENCOUNTER never matches in a LEFT JOIN, so blanks count as orphans here.

SELECT COUNT(*) AS orphans
FROM 'observations.csv' o
LEFT JOIN 'encounters.csv' e ON o.ENCOUNTER = e.Id
WHERE e.Id IS NULL
  AND o.ENCOUNTER IS NOT NULL;
-- Obs: 0 true orphans. Every observation that has an ENCOUNTER links to a real encounter; the 31,911 are all blanks.
-- Q?: Which observations are recorded without an encounter, and why?

SELECT COUNT(*) AS orphans
FROM 'observations.csv' o
LEFT JOIN 'patients.csv' p ON o.PATIENT = p.Id
WHERE p.Id IS NULL;
-- Obs: 0 orphans: every observation links to a patient.

-- Volume checks
SELECT COUNT(DISTINCT ENCOUNTER) AS encounters_referred_to
FROM 'observations.csv';
-- Obs: 35,750 of 67,321 encounters have at least one observation (COUNT DISTINCT ignores NULLs).

SELECT COUNT(DISTINCT PATIENT) AS patients_referred_to
FROM 'observations.csv';
-- Obs: 1,159, matching patients. Every patient has at least one observation.