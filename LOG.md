# Project log

## 8 Nov 2026: Week 0 setup
**Done:**
- Created this repo with a README and .gitignore. Installed Homebrew, Java and DuckDB.
- Generated synthetic data with Synthea (seed 42, clinician seed 42, reference date
  2026-11-08): 1,159 patients (1,000 alive, 159 deceased) across 18 CSVs in data/.
- Confirmed git ignores the data folder (`git check-ignore`).
**Checks:**
- Row count reconciled three ways: Synthea's run summary (1,159), `wc -l` on
  patients.csv (1,160 including the header) and `SELECT COUNT(*)` in DuckDB (1,159).
**Problems and fixes:**
- Push failed with "password authentication is not supported". Cause: an old saved
  GitHub password on my Mac. Fix: removed it and signed in again.
- Synthea wouldn't run. Cause: Java 8 installed; Synthea needs 11 or newer.
  Fix: installed Java 25.
- Homebrew wasn't installed, and the shell setup pointed at a path that didn't exist yet.
  Fix: installed Homebrew, which created that path.
- Updated macOS from 14 to 27 before installing DuckDB, which flagged
  macOS 14 as unsupported.
- Repo was created inside iCloud Drive. Moved to a fresh local copy to avoid syncing
  large data files and git conflicts.
**Decisions:**
- Data generation is seeded and date-pinned so the dataset can be reproduced exactly.
- DuckDB runs in memory against the CSVs; queries worth keeping will be saved as .sql files.
**Next:** Week 1 SQL (joins, CTEs, window functions) and git basics.

## Wed 11 Nov 2026: exploration checklist and SQLBolt
- **Did:** Turned my LSE NHS notebook into a reusable Data Exploration Checklist (pandas checks mapped to DuckDB SQL). SQLBolt lessons 1–12. Set up `sql/00_profile.sql`.
- **Confused me:** Nothing; SQLBolt was a comfortable refresher.
- **Fixed it:** n/a

## Fri 13 Nov 2026: PostgreSQL "Basic" and profiling patients
- **Did:** PostgreSQL Exercises "Basic". Profiled patients (grain, shape, column profile, duplicates, category values).
- **Confused me:** Filtering on a timestamp (reached for EXTRACT). Used ORDER BY … LIMIT 1 where MAX fitted. Needed a subquery in WHERE for the last question. Profiling took far too long because I chased every finding.
- **Fixed it:** Compare timestamps directly (`>=`); EXTRACT pulls out parts for grouping. Before writing, ask "do I want a value or a row?" and "could rows tie?" `WHERE x = (SELECT MAX(x) …)` returns all tied rows. Profiling is for recording, not chasing: note `DQ:` or `Q?:` and move on. SUMMARIZE covers missing values, types and ranges. `approx_unique` is an estimate.

## Sat 14 Nov 2026: profiling all tables and PostgreSQL "Joins and Subqueries"
- **Did:** Redid the "Basic" timestamp question unaided (Basic now clean). Finished "Joins and Subqueries". Profiled encounters, conditions and observations. Found 262 exact duplicate observations across 40 encounters. Decided data-quality checks go in `dq_checks.sql`, separate from analysis in `week1.sql`.
- **Confused me:** When to use a subquery or a join. BETWEEN on timestamps. Filtering on a CASE result. Correlated subqueries (a long-standing gap). Subquery versus CTE. 31,911 "orphan" observations.
- **Fixed it:** Join when the output needs columns from both tables. Use an `IN` subquery when only filtering; it also avoids duplicate rows. `NOT IN` fails if the list has a NULL, so use `NOT EXISTS`. Use a half-open range (`>=` start, `<` next day) for timestamps. WHERE runs before SELECT, so it can't use a SELECT alias: compute once in a CTE, or repeat the expression. Correlated subqueries need aliases on both tables. A CTE is a named derived table (a subquery in FROM). A NULL foreign key counts as an orphan in a LEFT JOIN check, so count blanks separately: all 31,911 were blank ENCOUNTERs, with 0 true orphans. A column read as BIGINT already proves its values are clean numbers.
**Open:** redo the recommender question unaided.

## Sun 15 Nov 2026: scoping the analysis, priority DQ checks and Q1
- **Did:** Redid the recommender question unaided ("Joins and Subqueries" complete). Wrote a one-sentence explanation of LEFT JOIN against INNER JOIN. Framed the overarching question (where prevention could reduce cost), with "preventable" approximated as chronic or recurring, inspired by AIHW's potentially preventable hospitalisations. Cut a 30+ question brainstorm down to 10. Wrote the priority DQ checks: CODE and DESCRIPTION are one-to-one for encounters and conditions; some CODEs sit under several classes; each ENCOUNTERCLASS and CODE pair has exactly one price. Answered Q1: frequent visitors are right-skewed, and Barnstable has about twice its share of them.
- **Confused me:** Correlated subqueries are still a bit fuzzy, because I find them hard to picture. Getting from a brainstorm to key questions. The interpretations take far longer than the queries.
- **Fixed it:** A row-by-row trace makes correlated subqueries visible (`m` = the row being described, `r` = the list being searched). Build queries in stages, with `SELECT *` on the join first. The six-step scoping process is now in my Data Exploration Checklist. `COUNT(DISTINCT x)` checks one-to-one relationships in one pass. HAVING can't use a SELECT alias outside DuckDB. Compare shares against a baseline before reading anything into them. With a LEFT JOIN, `COUNT(e.Id)` gives 0 for no matches, where `COUNT(*)` gives 1. Use Q1 as the worked example and keep the other answers to 1–2 lines.
**Open:** practise correlated subqueries with `NOT EXISTS` in Q8.

## Mon 16 Nov 2026: deceased share, Q2 and Q3
- **Did:** Re-scoped the week 1 questions before starting (Q2 now compares cost per encounter; new Q6; exposure-time limitation stated up front). Finished Q1 with the deceased share: 37.93% of frequent visitors against 13.72% of all patients, which supports the limitation. Answered Q2: frequent visitors make up 41.97% of encounters but cost less per encounter ($102.05) than the other 90% ($120.22). Answered Q3 on disorders only: dental and respiratory infections lead, and volume drives the totals. Found that conditions are recorded once, at diagnosis or a new episode, so Q9 moves to patient level.
- **Confused me:** Why the outer WHERE didn't filter my scalar subqueries. Whether NOT IN was safe to use. Which SNOMED tags count as conditions. What conditions.ENCOUNTER actually links to. Total or average cost, and whether to keep cost in Q3 at all. Whether average cost shows how acute a condition is. Why the questions took so much longer than writing the queries.
- **Fixed it:** Brackets start a new query, so a subquery is only filtered by its own WHERE; non-correlated subqueries run once and return one value. NOT IN drops every row if the list holds a NULL, so it's only safe when the list comes from a primary key (NOT EXISTS has no trap). Put `* 100.0` first, because integer division truncates outside DuckDB. Use `COUNT(*)` on a unique key, not `COUNT(DISTINCT Id)`. Add a unique tie-breaker (`p.Id`) so every query gets the same top 116. Compare a group with the rest, not only with the total, because its own rows pull the overall average; reconcile by checking the counts add up and the weighted average matches. "Clinical finding" covers disorders too; the non-clinical rows are social determinants, admin flags and history items, so filter with `LIKE '%(disorder)'` (brackets included), which lines up with the AIHW list. Rows against distinct patients (234 and 234 for hypertension) showed conditions are recorded at diagnosis. Show total and average cost together (total = count × average) and never rank by average alone. Prices follow the encounter setting, not acuity (sepsis averages $87.71). Most of the time went on data discovery, not query writing, which is a one-off cost for a new dataset.

## Tue 17 – Wed 18 Nov 2026: price structure, total claim cost and Q4
- **Did:** Explored base cost by class and CODE: two price tiers, inpatient priced the same as emergency, and about 88% of base cost in ambulatory, wellness and outpatient. Found TOTAL_CLAIM_COST and profiled it: no NULLs, never below base, heavily skewed (mean $2,688 against a median of about $906), with base only about 4% of it. Added claim cost to Q2 (frequent visitors are 31% cheaper per encounter than the rest) and Q3 (dental still leads, but sepsis and colon polyps rise sharply). Answered Q4 in about 20 minutes: a cardiometabolic cluster leads the ongoing disorders. Added a join convention to week1.sql. From Q5, I write each answer first using a four-question reading routine, now in my Data Exploration Checklist.
- **Confused me:** Whether base cost really showed that volume drives cost. Which way round the below-base check should go. Why my distinct list of claim costs couldn't show skew. When a LEFT JOIN is needed if there are no orphans. Which denominator to use for a share of patients.
- **Fixed it:** Base cost is a fee schedule, so volume dominates any total; total claim cost varies per visit and changes the ranking (sepsis averages $87.71 on base but $47,795 on claim). A check that expects 0 must show the 0: no HAVING on a single aggregate row. DISTINCT collapses repeats, so use SUMMARIZE quartiles and compare the median with the mean. LEFT JOIN for enrichment as a convention so rows never drop, explicit INNER JOIN when filtering; a WHERE on the right-hand table breaks a LEFT JOIN, except the IS NULL anti-join. Use patients.csv for the denominator, not a count that only happens to match. Write the answer first, then ask: what's biggest, compared with what, could the data mislead me, how does this help me answer the overarching question or make a decision?

## Fri 20 – Sat 21 Nov 2026: Q5 to Q8
- **Did:** Planned Q5–Q7 before writing any queries (15 min). Answered Q5: gingivitis recurs for 682 patients (58.84%) at 4.0 episodes each, and overdose stands out at 3.74 episodes per affected patient. Q6: 99.14% of frequent visitors have a chronic or recurring disorder, against 88.30% of the rest. Q7: no gender difference, and every county is within about 7 patients of expected. Q8: 123 patients have neither, which reconciles with Q7. Times: Q5 ~45 min, Q6 ~45, Q7 ~50, Q8 ~30.
- **Confused me:** Whether Q5 needed a subquery in FROM when a CTE reads better. Whether an open episode should count towards recurring. Why Q6 gave 18,523 recurring episodes for 116 patients. Whether to count episodes or a yes/no per patient. What the UNION list actually filters. Why county shares just tracked county size. Why my expected-gap column made no sense. How NOT EXISTS works with SELECT 1.
- **Fixed it:** Kept the CTE: it's what production uses and coverage was already met. Recurring now means 2+ closed episodes, with open episodes counted as chronic only (stated as an assumption). A subset can't exceed the whole, so 18,523 against 5,337 total pointed to a join fan-out: aggregate to one row per patient before joining. "More likely" needs a yes/no per patient, which also resists exposure time. GROUP BY PATIENT, CODE with HAVING checks recurrence per patient. UNION removes duplicates; UNION ALL keeps them. A within-group rate needs the group's own denominator, so patients is the base with a LEFT JOIN to the list. Compare actual with expected in patients, not patients minus percent, and calculate the overall rate in a CTE rather than typing it in. A CTE only lasts for one statement. NOT EXISTS (resolves the 15 Nov open item): a match returns a row, so NOT EXISTS is false; it's true only when the search comes back empty. SUM(CASE WHEN NOT EXISTS ...) counts within groups while COUNT(*) keeps the totals. The LEFT JOIN + IS NULL anti-join does the same job.
**Open:** NOT EXISTS feels less natural through low use. Plan 2–3 short spaced drills and one cold, unaided self-test before Gate 1.

## Sun 22 Nov

**Done**
- Q9 and Q10 answered on both cost measures. All ten Week 1 questions are complete.
- Q10 header added; session timings removed from week1.sql.

**Findings**
- Q9: chronic-or-recurring patients cost less per encounter ($2,670.63 vs $3,107.05 claim) but about 2.4x more per patient ($166,558.71 vs $68,430.98). Volume drives it: about 62.4 encounters each vs 22.0. They account for 95.35% of claim cost.
- Q10: 41,489 encounters (61.6%) have no condition recorded, carrying 65.2% of claim cost. Conditions are recorded at diagnosis, so this group includes follow-ups and ongoing care, not just unrelated visits.
- Base cost per encounter barely moves by class ($100.14 to $142.58) while claim cost ranges from $614.65 to $29,444.02. Total claim cost is the better measure for Week 2.

**Learned**
- WHERE removes rows (like a spreadsheet filter). CASE in SELECT keeps every row and flags it (like a helper column). Use CASE when the query needs the group's total as well as the subset.
- NOT IN fails silently if the list contains a NULL: every row drops. Safe here because profiling showed conditions.PATIENT is never NULL. NOT EXISTS has no such trap.
- ROUND goes around the whole calculation, not inside it: ROUND(SUM(x) / COUNT(DISTINCT y), 2).
- LEFT JOIN + IS NULL anti-join: an INNER JOIN with the same WHERE returns 0 rows, because unmatched rows are gone before the filter runs.
- Reconcile every split against the total (64,612 + 2,709 = 67,321; 67,321 - 25,832 = 41,489).

**Open**
- NOT EXISTS feels less natural through low use. Plan 2–3 short spaced drills and one cold, unaided self-test before Gate 1.
- Test what the 16,128 no-condition "Encounter for problem" visits are for, using REASONDESCRIPTION.
- Re-run Q9 per year of record to remove the exposure-time effect.
- Rewrite Q2 and Q9 as CASE + GROUP BY instead of scalar subquery columns.