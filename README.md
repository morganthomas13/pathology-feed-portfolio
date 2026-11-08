# Pathology Results Feed: Portfolio Project

A simulated hospital pathology results feed, built end to end on synthetic patient data.
It shows the core work of a clinical systems or data analyst: querying, checking data
quality, reporting, moving results between systems, and validating the result.

**All data is synthetic, generated with [Synthea](https://github.com/synthetichealth/synthea). No real patient data is used.**

## What this project covers
- **SQL:** analysis and data-quality checks on patient, encounter and lab data
- **Power BI:** a results and data-quality dashboard, reconciled to SQL
- **HL7 v2:** lab results (ORU^R01) routed through an interface engine into PostgreSQL
- **FHIR R4:** Patient, Observation and DiagnosticReport resources
- **Validation:** requirements, risk assessment, test scripts and traceability

## Status
| Phase | Focus | Status |
|---|---|---|
| 1 | SQL and data quality | In progress |
| 2 | Power BI | Not started |
| 3 | HL7 v2 and FHIR | Not started |
| 4 | Validation pack | Not started |

## Data
Raw CSVs aren't committed. To regenerate them:
`java -jar synthea-with-dependencies.jar -p 1000 -s 42 -cs 42 -r 20261108 --exporter.csv.export true --exporter.fhir.export false`