# Clinical Trial Analytics Dashboard

A data analytics project exploring **COVID-19 clinical trial performance and trends** using data from [ClinicalTrials.gov](https://clinicaltrials.gov/) (Kaggle dataset). Built as a technical challenge for a life sciences consultancy's Data & AI Engineering team.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Key Findings](#key-findings)
3. [Project Structure](#project-structure)
4. [Setup & Reproducibility](#setup--reproducibility)
5. [Data Pipeline](#data-pipeline)
6. [Data Cleaning Decisions](#data-cleaning-decisions)
7. [Business Questions & Analysis](#business-questions--analysis)
8. [SQL Concepts Demonstrated](#sql-concepts-demonstrated)
9. [Statistical Analysis](#statistical-analysis)
10. [Recommendations](#recommendations)
11. [Bonus Questions](#bonus-questions)
12. [AI Tools Disclosure](#ai-tools-disclosure)

---

## Project Overview

**Dataset:** COVID-19 Clinical Trials (Kaggle) — 5,783 raw records extracted on 2021-04-14, covering trials registered on ClinicalTrials.gov during the pandemic response.

**Final dataset:** 5,749 trials after removing 34 Expanded Access programs.

**Stack:**
- **Database:** PostgreSQL 16
- **Analysis:** Python (pandas, SQLAlchemy, plotly)
- **Environment:** Jupyter Notebooks, VS Code + SQLTools
- **Visualization:** Plotly (publication-quality interactive charts)

**Approach:** SQL-first analysis — all queries run live against PostgreSQL via SQLAlchemy. No CSV-based analysis in the visualization notebooks.

---
## Project Structure

```
MIGx/
├── data/
│   ├── raw/                          # Original CSV from Kaggle (untouched)
│   │   └── COVID-19 ClinicalTrials.csv
│   └── processed/                    # Cleaned flat file
│       └── clinical_trials_clean.csv
│
├── notebooks_py/
│   ├── 01_data_loading.ipynb         # EDA: data quality, distributions, cleaning
│   ├── 02_load_to_postgres.ipynb     # Schema creation + data loading into PostgreSQL
│   ├── 03_visualizations_q1.ipynb    # Q1: Trial Landscape Overview
│   ├── 04_visualizations_q2.ipynb    # Q2: Completion Analysis
│   ├── 05_visualizations_q3.ipynb    # Q3: Enrollment Performance
│   ├── 06_visualizations_q4.ipynb    # Q4: Geographic Insights
│   └── 07_visualizations_q5.ipynb    # Q5: Duration Analysis
│
├── SQL/
│   ├── 01_create_tables.sql          # Database schema (7 tables)
│   ├── 02_Question_1.sql             # Trial Landscape queries (4 queries)
│   ├── 03_Question_2.sql             # Completion Analysis queries (4 queries)
│   ├── 04_Question_3.sql             # Enrollment Performance queries (4 queries)
│   ├── 05_Question_4.sql             # Geographic Insights queries (4 queries)
│   └── 06_Question_5.sql             # Duration Analysis queries (4 queries)
│
└── README.md                         # This file
```

---

## Setup & Reproducibility

### Prerequisites

- Python 3.9+
- PostgreSQL 16 (or compatible version)
- Jupyter Notebook or JupyterLab

### Python Dependencies

```bash
pip install pandas sqlalchemy psycopg2-binary plotly notebook
```
**Libraries by notebook:**

| Notebook | Libraries |
|----------|-----------|
| `01_data_loading.ipynb` | pandas, numpy, matplotlib, seaborn |
| `02_load_to_postgres.ipynb` | pandas, numpy, sqlalchemy, psycopg2-binary |
| `03–07_visualizations_q*.ipynb` | pandas, plotly, wordcloud, sqlalchemy, psycopg2-binary |

### Important: Update File Paths

> **⚠️ Before running any notebook**, update all file paths to match your local environment.
>
> Each notebook contains hardcoded paths for reading/writing data files and connecting to PostgreSQL. After cloning the repository, search for path references in every `.ipynb` file and update them to reflect where you downloaded the project.
>
> Paths to update:
> - **CSV file paths** (e.g., `data/raw/...`, `data/processed/...`) — adjust to your local project directory
> - **PostgreSQL connection string** — update the username to match your local PostgreSQL user:
>   ```python
>   engine = create_engine('postgresql+psycopg2://YOUR_USER@localhost:5432/clinical_trials')
>   

### Step-by-Step Execution

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Viba97/mix_test_clinical_trials.git
   cd mix_test_clinical_trials
   ```

2. **Start PostgreSQL** and create the database:
   ```bash
   # macOS (Homebrew)
   brew services start postgresql@16

   # Create the database
   createdb clinical_trials
   ```

3. **Create the schema:** Open `SQL/01_create_tables.sql` in your SQL client and execute it. This creates 7 tables with proper foreign keys and indexes.

4. **Run the notebooks in order:**
   - `01_data_loading.ipynb` — Loads raw CSV, performs EDA, applies all cleaning transformations, exports `clinical_trials_clean.csv`
   - `02_load_to_postgres.ipynb` — Reads the cleaned CSV and loads data into the 7 PostgreSQL tables
   - `03–07_visualizations_q*.ipynb` — Each notebook runs SQL queries against PostgreSQL and generates interactive Plotly visualizations

5. **PostgreSQL connection:** Update the connection string in the notebooks if your setup differs:
   ```python
   engine = create_engine('postgresql+psycopg2://YOUR_USER@localhost:5432/clinical_trials')
   ```

---

## Data Pipeline

```
Raw CSV (Kaggle)
    │
    ▼
01_data_loading.ipynb
    │  • Data quality assessment
    │  • Missing value analysis
    │  • Cleaning & normalization
    │  • Export clean CSV
    ▼
02_load_to_postgres.ipynb
    │  • Reads clean CSV
    │  • Splits into 7 normalized tables
    │  • Loads into PostgreSQL
    ▼
SQL queries (02–06_Question_*.sql)
    │  • 20 queries across 5 business questions
    │  • JOINs, CTEs, window functions, aggregations
    ▼
Visualization notebooks (03–07)
    │  • Queries run live via SQLAlchemy
    │  • Plotly interactive charts
    │  • Markdown analysis + recommendations
    ▼
Insights & Recommendations
```

---

## Data Cleaning Decisions

| Issue | Decision | Rationale |
|-------|----------|-----------|
| 34 Expanded Access records | Removed entirely | Compassionate use programs, not clinical trials |
| Phase: 42.6% missing | Labeled "Unknown"; multi-value → highest phase | Preserves data; unknown excluded from phase-specific analysis |
| Status: 12 distinct values | Grouped into 3 categories (Active, Completed, Stopped) | Simplifies analysis without losing information |
| Enrollment: max 20M, 107 zeros | No capping; median used; zeros kept but flagged | Zeros are all Withdrawn trials (never enrolled) |
| Dates: 2099 placeholders | Cutoff at extraction date + 10 years → NULL | 10 completion dates and 3 primary completion dates affected |
| Pre-2020 start dates (175 trials) | Kept with boolean flag `pre_covid_start` | Legitimate trials that added COVID arms |
| Conditions: 2,821 unique names | 2-level normalization → 10 therapeutic areas | COVID variants consolidated; therapeutic areas enable aggregation |
| Locations: inconsistent format | Country = last comma element; continent derived | Consistent extraction across all format variations |
| Outcomes: free text | Loaded as-is; not used in analysis | No structured parsing possible |


---

## Bonus Questions

### 1. Stakeholder Communication

**For a non-technical executive:** Focus on 3–4 headline KPIs (total trials, completion rate, time-to-failure, geographic concentration) presented as a single-page summary with trend arrows. Use the Plotly charts in simplified form — hide axes details, emphasize directional insights. Frame everything around business impact: cost of failure, time savings, competitive positioning.

**For a clinical operations manager:** Provide drill-down capability by phase, sponsor, therapeutic area. Include the detailed breakdowns (masking vs completion, enrollment distributions by quartile). Add filters for their specific portfolio. They need the granularity to make operational decisions — which sites to activate, what enrollment targets to set, when to trigger protocol amendments.

### 2. Data Quality at Scale

For a daily-refresh pipeline, I would implement:
- **Schema validation:** Check column types, null rates, and value ranges against expected bounds on each ingestion (e.g., enrollment ≥ 0, dates within plausible range, status in known enum).
- **Completeness monitoring:** Track % missing per column over time; alert if a column's null rate spikes (e.g., phase missing jumps from 42% to 60%).
- **Freshness SLA:** Alert if no new data arrives within expected cadence.

### 3. Self-Service Analytics

I would deploy a **Metabase or Apache Superset** instance connected to the PostgreSQL database, with:
- Pre-built dashboards mirroring the 5 business questions, with interactive filters (phase, status, therapeutic area, date range, country).
- Saved SQL queries that stakeholders can fork and modify.
- A curated semantic layer (dbt metrics or Metabase models) so non-SQL users can drag-and-drop fields without writing queries.
- Scheduled email reports for recurring KPIs (weekly trial landscape summary).

### 4. Compliance Considerations (GxP)

In a GxP-regulated environment:
- **Audit trail:** Every data transformation must be logged with timestamp, user, and justification. The cleaning decisions documented in this README would need formal change control.
- **Validation protocol:** IQ/OQ/PQ (Installation, Operational, Performance Qualification) for the database and ETL pipeline. Each SQL query would need documented test cases with expected vs actual results.
- **SOPs:** Standard Operating Procedures for data ingestion, cleaning, analysis, and reporting — with version control.

### 5. Advanced Analytics

Models that would add value to this use case:
- **NLP on outcomes/eligibility text:** Extract structured features from free-text fields (outcome measures, eligibility criteria) to identify patterns associated with success/failure — currently unused data.
- **Geographic clustering:** Identify optimal site networks using k-means or hierarchical clustering on country-level trial density, therapeutic specialization, and regulatory timeline data.

---

## AI Tools Disclosure

This project used **Claude (Anthropic)** as a coding assistant throughout development. Specifically:
- SQL query design and debugging (especially window functions and CTEs, as I am a SQL beginner)
- Python visualization code generation (Plotly chart formatting and layout)
- Data cleaning strategy discussion and validation
- README structure and content drafting

All technical decisions (cleaning logic, chart selection, analysis interpretation, recommendations) are my own.

---

## Database Schema

7 normalized tables, all linked via `study_id`:

```
studies (5,749 rows)
    ├── conditions    (11,097 rows)  — therapeutic areas, condition names
    ├── interventions (~7,000 rows)  — drugs, procedures, devices
    ├── outcomes      (~8,000 rows)  — outcome measures (free text)
    ├── sponsors      (~6,000 rows)  — agency, agency_class, lead/collaborator
    ├── locations     (23,703 rows)  — country, continent
    └── study_design  (5,749 rows)   — allocation, masking, intervention model
```

---

## PostgreSQL Connection

```
Host:     localhost
Port:     5432
Database: clinical_trials
```

Update the connection string in notebooks as needed for your local environment.
