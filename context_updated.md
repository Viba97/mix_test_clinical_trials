# Project Context — Clinical Trial Analytics Dashboard
## DA Technical Challenge — MIGx (Updated after Chat #2)

---

## Project Overview

**Challenge:** Build a Clinical Trial Analytics Dashboard for a life sciences consultancy using COVID-19 clinical trial data.

**Dataset:** COVID-19 Clinical Trials from ClinicalTrials.gov (Kaggle)
- 5,783 raw rows → 5,749 after cleaning (34 Expanded Access removed)
- Extraction date: 2021-04-14
- 27 original columns

**Stack:**
- Python (pandas, sqlalchemy, plotly)
- PostgreSQL 16 (via Homebrew on macOS ARM)
- VS Code + SQLTools extension
- Jupyter Notebooks

---

## Database Schema (PostgreSQL)

7 tables, all linked via study_id:
```
studies (5,749 rows)
    ├── conditions    (11,097 rows)
    ├── interventions (~7,000 rows)
    ├── outcomes      (~8,000 rows)
    ├── sponsors      (~6,000 rows)  ← columns: agency_class, lead_or_collaborator (NOT agency_type)
    ├── locations     (~23,703 rows)
    └── study_design  (5,749 rows)
```

### Key column names confirmed:
- sponsors table: `agency_class` (not agency_type), `lead_or_collaborator`
- studies table: `status`, `status_group`, `phase`, `study_type`, `enrollment`, `start_date`, `completion_date`, `primary_completion_date`, `pre_covid_start`, `date_error`
- conditions table: `therapeutic_area`, `condition_name`
- locations table: `country`, `continent`
- study_design table: `allocation`, `intervention_model`, `masking`

---

## Data Cleaning Decisions (from Chat #1)

1. **Expanded Access:** 34 removed → 5,749 rows
2. **Phase:** 42.6% missing → "Unknown"; multi-value → highest phase
3. **Status:** 12 values → 3 groups (Active, Completed, Stopped)
4. **Enrollment:** No capping; median used; zero enrollment kept but excluded from analysis
5. **Dates:** Cutoff at extraction + 10yr; pre-2020 flagged; 1 pre-2000 flagged
6. **Conditions:** 2-level normalization → 10 therapeutic areas
7. **Locations:** Country extracted as last comma element; continent derived
8. **Outcomes:** Raw text, not used in business questions

---

## Business Questions & SQL Status

### Q1 — Trial Landscape Overview ✅ SQL DONE ✅ NOTEBOOK DONE
- File: `sql/02_trial_landscape.sql` (4 queries: 1A-1D)
- Notebook: `02_visualizations_q1.ipynb`
- Charts: Phase bar, Status donut + breakdown, Therapeutic area bar, Monthly stacked bar, Cumulative line
- Removed: "Completion rate by launch month" chart (belonged to Q2, not Q1)

**Key results from Q1:**
- Phase: Unknown 42.2%, Not Applicable 23.6%, Phase 2 15.3%, Phase 3 11.3%
- Status: Active 78.6% (4,516), Completed 17.8% (1,025), Stopped 3.6% (208)
- Resolved completion rate: 83.1% (1,025/1,233)
- Therapeutic areas: Infectious Disease 80.0%, Other 26.6%, Respiratory 13.1%, Mental Health 7.3%
- Timeline peak: 825 trials in April 2020; 50% of all trials launched by June 2020

### Q2 — Completion Analysis ✅ SQL DONE ✅ NOTEBOOK DONE
- File: `sql/03_completion_analysis.sql` (4 queries: 2A-2D)
- Notebook: `02_visualizations_q2.ipynb`
- **BUG FIXED:** `agency_type` → `agency_class` in Query 2B
- Charts: Phase completion rate with enrollment overlay, Sponsor type bar, Allocation/Model/Masking bars, Heatmap failure type × phase, Faceted failure breakdown, Bubble chart duration vs enrollment

**Key results from Q2:**
- Completion by phase: Not Applicable 86.9%, Phase 1 77.6%, Phase 4 61.1%, Phase 2 58.6%, Phase 3 55.9%
- By sponsor: Other (academic) 84.7%, Industry 74.1%, NIH 70.0% (n=10)
- Design: Non-Randomized 87.9% vs Randomized 67.6%; Crossover 96.3% vs Parallel 68.4%
- Masking: more blinding → lower completion (Single 89.7% → Quadruple 57.1%)
- Stopped trials: Withdrawn 107 (median enrollment 0, "dead on arrival"), Terminated 74, Suspended 27
- Failures are fast: median duration 0-19 days

### Q3 — Enrollment Performance ✅ SQL DONE 🔜 NOTEBOOK TODO
- File: `sql/04_enrollment_performance.sql` (4 queries: 3A-3D)
- Concepts: PERCENTILE_CONT, LAG, NTILE, NULLIF

### Q4 — Geographic Insights ✅ SQL DONE 🔜 NOTEBOOK TODO
- File: `sql/05_geographic_insights.sql` (4 queries: 4A-4D)
- Concepts: 3-table JOIN, specialization index, cumulative %, CASE in ORDER BY

### Q5 — Duration Analysis ✅ SQL DONE 🔜 NOTEBOOK TODO
- File: `sql/06_duration_analysis.sql` (4 queries: 5A-5D)
- Concepts: DISTINCT ON, PERCENT_RANK, outlier detection (>2× median), Completed vs Stopped comparison

---

## Project Structure (current)
```
project-root/
├── data/
│   ├── raw/COVID-19 ClinicalTrials.csv
│   └── processed/clinical_trials_clean.csv
├── notebooks/
│   ├── 01_eda.ipynb                          ← DONE
│   ├── 02_visualizations_q1.ipynb            ← DONE
│   └── 02_visualizations_q2.ipynb            ← DONE
├── sql/
│   ├── 01_create_tables.sql                  ← DONE
│   ├── 02_trial_landscape.sql               ← DONE (Q1, 4 queries)
│   ├── 03_completion_analysis.sql           ← DONE (Q2, 4 queries, agency_class fixed)
│   ├── 04_enrollment_performance.sql        ← DONE (Q3, 4 queries)
│   ├── 05_geographic_insights.sql           ← DONE (Q4, 4 queries)
│   └── 06_duration_analysis.sql             ← DONE (Q5, 4 queries)
├── load_to_postgres.py                      ← DONE
├── CONTEXT.md
└── README.md                               ← TODO
```

---

## Notebook Style Guide

- **Theme:** Minimal/corporate — white background, clean palette
- **Colors:** Primary #2563EB, Success #10B981, Danger #EF4444, Accent #F59E0B, Secondary #64748B
- **Font:** Helvetica Neue
- **Structure per question:** Setup cell → Query cell → Chart cell(s) → Markdown analysis → Summary & Recommendations
- **Connection:** `pd.read_sql(query, engine)` — queries run live from PostgreSQL
- **Data source:** Query results are pulled via SQLAlchemy, NOT from CSV

---

## Known Issues & Notes

- `load_to_postgres.py` will throw IntegrityError if run twice (UNIQUE constraint on nct_id). Data is already loaded — no need to re-run unless schema changes.
- SQLTools shows only the last query result when running a full file → execute queries one at a time by selecting the block.
- User is proficient in Python, beginner in SQL — every SQL concept explained before use.
- Each SQL file has heavy inline comments explaining every clause.

---

## Next Steps (in order)

1. Generate notebook for Q3 — Enrollment Performance (run queries, paste results, generate notebook)
2. Generate notebook for Q4 — Geographic Insights
3. Generate notebook for Q5 — Duration Analysis
4. Decide: single combined notebook or keep separate per question?
5. Write README.md with recommendations and bonus answers
6. Final review of GitHub repo structure

---

## PostgreSQL Connection Details

- Host: localhost
- Port: 5432
- Database: clinical_trials
- Username: vittoriobariosco
- Connection string: postgresql+psycopg2://vittoriobariosco@localhost:5432/clinical_trials

## SQL Concepts Already Explained

- JOIN, LEFT JOIN, CROSS JOIN (Q1C)
- CTE (WITH ... AS)
- GROUP BY + aggregations (COUNT, SUM, AVG)
- Window functions: SUM() OVER(), SUM() OVER(ORDER BY), RANK(), PERCENT_RANK(), NTILE(), LAG()
- PARTITION BY
- FILTER clause
- DATE_TRUNC, EXTRACT, AGE()
- CASE WHEN (in SELECT and ORDER BY)
- PERCENTILE_CONT (median, Q1, Q3)
- UNION ALL
- DISTINCT ON
- NULLIF
- Subqueries
- HAVING
- Aliases (table and column)
- COUNT(DISTINCT) for multi-label data
