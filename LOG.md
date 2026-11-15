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
- **Fixed it:** Join when the output needs columns from both tables. Use an `IN` subquery when only filtering; it also avoids duplicate rows. `NOT IN` fails if the list has a NULL, so use `NOT EXISTS`. Use a half-open range (`>=` start, `<` next day) for timestamps. WHERE runs before SELECT, so it can't use a SELECT alias: compute once in a CTE, or repeat the expression. Correlated subqueries need aliases on both tables. A CTE is a named derived table (a subquery in FROM). A NULL foreign key counts as an orphan in a LEFT JOIN check, so count blanks separately: all 31,911 were blank ENCOUNTERs, with 0 true orphans. A column read as BIGINT already proves its values are clean numbers. **Open:** redo the recommender question unaided on Sunday.

## Sun 15 Nov 2026: scoping the analysis, priority DQ checks and Q1
- **Did:** Redid the recommender question unaided ("Joins and Subqueries" complete). Wrote the LEFT JOIN sentence (passed). Framed the overarching question (where prevention could reduce cost), with "preventable" approximated as chronic or recurring, inspired by AIHW's potentially preventable hospitalisations. Cut a 30+ question brainstorm down to 10. Wrote the priority DQ checks: CODE and DESCRIPTION are one-to-one for encounters and conditions; some CODEs sit under several classes; each ENCOUNTERCLASS and CODE pair has exactly one price. Answered Q1: frequent visitors are right-skewed, and Barnstable has about twice its share of them.
- **Confused me:** Correlated subqueries are still a bit fuzzy, because I find them hard to picture. Getting from a brainstorm to key questions. The interpretations take far longer than the queries.
- **Fixed it:** A row-by-row trace makes correlated subqueries visible (`m` = the row being described, `r` = the list being searched). Build queries in stages, with `SELECT *` on the join first. The six-step scoping process is now in my Data Exploration Checklist. `COUNT(DISTINCT x)` checks one-to-one relationships in one pass. HAVING can't use a SELECT alias outside DuckDB. Compare shares against a baseline before reading anything into them. With a LEFT JOIN, `COUNT(e.Id)` gives 0 for no matches, where `COUNT(*)` gives 1. Use Q1 as the worked example and keep the other answers to 1–2 lines. 
**Open:** practise correlated subqueries with `NOT EXISTS` in Q8.