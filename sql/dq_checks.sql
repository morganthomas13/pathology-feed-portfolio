-- Data-quality checks: Synthea data
-- Each check returns only the failing rows. Built from findings in 00_profile.sql.

-- ===== Priority: affect the Week 1 analysis =====

-- Check: each encounter CODE has exactly one DESCRIPTION
-- Why: the cost and service-type questions group by CODE or DESCRIPTION

-- Check: each encounter CODE sits under one ENCOUNTERCLASS
-- Why: the cost question compares classes

-- Check: each condition CODE has exactly one DESCRIPTION
-- Why: priority only if a Week 1 question groups conditions by DESCRIPTION or semantic tag

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