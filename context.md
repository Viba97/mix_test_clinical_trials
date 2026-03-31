# Project Context — Clinical Trial Analytics Dashboard
## DA Technical Challenge — MIGx

---

## Project Overview

**Challenge:** Build a Clinical Trial Analytics Dashboard for a life 
sciences consultancy using COVID-19 clinical trial data.

**Dataset:** COVID-19 Clinical Trials from ClinicalTrials.gov (Kaggle)
- 5,783 raw rows → 5,749 after cleaning
- Extraction date: 2021-04-14
- 27 original columns

**Stack:**
- Python (pandas, sqlalchemy, plotly, seaborn) 
- PostgreSQL 16 (via Homebrew on macOS ARM)
- VS Code + SQLTools extension
- Jupyter Notebooks

**Submission format:**
- GitHub repository
- README.md with recommendations + bonus questions

---

## Project Structure
```
project-root/
├── data/
│   ├── raw/
│   │   └── COVID-19 ClinicalTrials.csv       ← original, never modified
│   └── processed/
│       └── clinical_trials_clean.csv         ← cleaned flat file
│
├── notebooks/
│   ├── 01_eda.ipynb                          ← DONE
│   └── 02_visualizations.ipynb              ← TODO
│
├── sql/
│   ├── 01_create_tables.sql                  ← DONE
│   ├── 02_trial_landscape.sql               ← TODO
│   ├── 03_completion_analysis.sql           ← TODO
│   ├── 04_enrollment_performance.sql        ← TODO
│   ├── 05_geographic_insights.sql           ← TODO
│   └── 06_duration_analysis.sql            ← TODO
│
├── load_to_postgres.py                      ← DONE
├── CONTEXT.md                               ← this file
└── README.md                               ← TODO
```

---

## Database Schema (PostgreSQL)

7 tables, all linked via study_id:
```
studies (5,749 rows)
    ├── conditions    (11,097 rows)
    ├── interventions (~7,000 rows)
    ├── outcomes      (~8,000 rows)
    ├── sponsors      (~6,000 rows)
    ├── locations     (~23,703 rows)
    └── study_design  (5,749 rows)
```

### studies columns:
- study_id (PK, auto-generated)
- nct_id, title, acronym
- status (raw), status_group (derived)
- phase (cleaned), study_type
- start_date, completion_date, primary_completion_date
- enrollment, gender
- pre_covid_start (boolean flag)
- date_error (boolean flag)

### conditions columns:
- condition_id (PK)
- study_id (FK)
- condition_name (normalized)
- mesh_term (NULL — not in CSV)
- therapeutic_area (derived — 10 categories)

### locations columns:
- location_id (PK)
- study_id (FK)
- facility, city, state (all NULL — not parsed)
- country (extracted as last comma element)
- continent (derived from country lookup)

---

## All Data Cleaning Decisions

### 1. Expanded Access Programs
- **Issue:** 34 records are compassionate use programs, not trials
- **Decision:** Removed entirely
- **Impact:** 5,783 → 5,749 rows

### 2. Phase Column
- **Issue:** 42.6% missing (2,461 rows), some multi-value ("Phase 1|Phase 2")
- **Decision:** 
  - NaN → labeled "Unknown"
  - Multi-value → take highest phase
  - Stored in new column `phase_clean`
- **Impact:** Excluded from phase-specific queries with WHERE phase != 'Unknown'

### 3. Status Column
- **Issue:** 12 distinct values including edge cases
- **Decision:** Grouped into 4 categories in new column `status_group`:
  - Active: Recruiting, Not yet recruiting, Active not recruiting, Enrolling by invitation
  - Completed: Completed
  - Stopped: Withdrawn, Terminated, Suspended
  - Other: remaining edge cases (0 after Expanded Access removal)

### 4. Enrollment
- **Issue:** Max = 20,000,000, mean (18,319) >> median (170), 107 zeros
- **Decision:**
  - No capping — observational and interventional analyzed separately
  - Zero enrollment kept but excluded from enrollment analysis (all Withdrawn)
  - Median used instead of mean throughout
  - Expanded Access excluded (no enrollment data)

### 5. Dates
- **Issue:** Placeholder dates of 2099-12-31, pre-2020 starts, 1 pre-2000 start
- **Decision:**
  - Cutoff = extraction date (2021-04-14) + 10 years = 2031-04-14
  - 10 completion dates beyond cutoff → set to NULL
  - 3 primary completion dates beyond cutoff → set to NULL
  - 175 pre-2020 trials → kept with boolean flag pre_covid_start=TRUE
  - 1 pre-2000 trial → kept with boolean flag date_error=TRUE
  - Both flags stored in studies table for use in SQL queries

### 6. Conditions
- **Issue:** 2,821 unique condition names, 15+ COVID variants
- **Decision:** Two-level normalization:
  - Level 1: canonical name normalization (e.g. all COVID variants → "COVID-19")
  - Level 2: therapeutic_area classification into 10 categories:
    - Infectious Disease (53.1%)
    - Other (22.0%) — includes non-disease entries
    - Respiratory/Critical Care (8.8%)
    - Mental Health (6.4%)
    - Metabolic/Cardiovascular (3.7%)
    - Oncology (2.5%)
    - Musculoskeletal/Rheumatology (1.1%)
    - Neurological (1.1%)
    - Renal (0.8%)
    - Reproductive Health (0.6%)
  - 22% remaining "Other" is correct — non-disease entries
    (quality of life, healthy volunteers, telemedicine etc.)

### 7. Locations
- **Issue:** Inconsistent format (3-10 comma-separated parts)
- **Decision:**
  - Extract only last element as country (consistent across all formats)
  - Derive continent from country lookup table (131/134 countries mapped)
  - 3 unmapped entries (0.8%) are parsing artifacts ("Republic of" etc.)
  - city, facility, state left as NULL (not needed for business questions)

### 8. Outcomes
- **Issue:** Free text, no consistent structure
- **Decision:** Load pipe-separated entries as raw text rows
  - outcome_type = NULL (not parseable)
  - Not used in any of the 5 business questions

---

## Business Questions to Answer (SQL)

All 5 queries must demonstrate: JOINs, CTEs, window functions, 
aggregations, subqueries.

### Q1 — Trial Landscape Overview
- Distribution by phase, status, therapeutic area
- How has this evolved over time?
- Tables needed: studies, conditions

### Q2 — Completion Analysis  
- Factors associated with higher completion rates
- Patterns in terminated/withdrawn trials
- Tables needed: studies, sponsors, study_design

### Q3 — Enrollment Performance
- Trends in patient enrollment across trial types
- Which conditions attract most participants?
- Tables needed: studies, conditions

### Q4 — Geographic Insights
- Global distribution of trials
- Regional specializations in therapeutic areas
- Tables needed: locations, conditions, studies

### Q5 — Duration Analysis
- Typical duration by phase and therapeutic area
- Which trials take significantly longer than expected?
- Tables needed: studies, conditions
- Note: exclude pre_covid_start=TRUE and date_error=TRUE trials

---

## Current Status

✅ DONE:
- PostgreSQL setup and running
- All 7 tables created with correct schema
- Data loaded and verified:
  - studies:       5,749 rows
  - conditions:   11,097 rows
  - interventions: ~7,000 rows
  - outcomes:      ~8,000 rows
  - sponsors:      ~6,000 rows
  - locations:    23,703 rows
  - study_design:  5,749 rows
- EDA notebook complete with documented findings
- All cleaning decisions implemented and documented

🔜 NEXT STEPS (in order):
1. Write SQL queries for Q1-Q5 (one file per question)
2. Build visualizations notebook (pull SQL results into plotly)
3. Statistical analysis (descriptive stats, correlations)
4. Write README.md with recommendations and bonus answers

---

## SQL Concepts Needed (reminder)

The test explicitly evaluates these — use all of them:
- JOINs (JOIN, LEFT JOIN)
- CTEs (WITH ... AS)
- Window functions (OVER, PARTITION BY, RANK, ROW_NUMBER)
- Aggregations (COUNT, AVG, SUM, PERCENTILE_CONT)
- Subqueries
- FILTER clause
- DATE arithmetic (AGE(), EXTRACT())
- CASE WHEN

---

## PostgreSQL Connection Details

- Host: localhost
- Port: 5432
- Database: clinical_trials
- Username: vittoriobariosco
- Connection string: postgresql+psycopg2://vittoriobariosco@localhost:5432/clinical_trials

## Key Commands

Start PostgreSQL:
brew services start postgresql@16

Run loading script:
cd /Users/vittoriobariosco/Documents/APPLICATIONS/MIGx
python load_to_postgres.py

---

## Notes for Next Chat

- User is proficient in Python, beginner in SQL
- Every SQL concept must be explained carefully before writing queries
- Go one business question at a time
- Each SQL file should have comments explaining every clause
- After SQL is done → notebook_02_visualizations.ipynb
- Then README.md with recommendations