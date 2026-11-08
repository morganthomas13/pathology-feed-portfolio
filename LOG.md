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