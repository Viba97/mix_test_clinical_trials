-- ─────────────────────────────────────────────────────────
-- 01_create_tables.sql
-- Clinical Trial Analytics Dashboard
-- Drops and recreates all tables from scratch
-- ─────────────────────────────────────────────────────────

-- Drop in reverse dependency order (children before parents)
DROP TABLE IF EXISTS study_design CASCADE;
DROP TABLE IF EXISTS locations CASCADE;
DROP TABLE IF EXISTS sponsors CASCADE;
DROP TABLE IF EXISTS outcomes CASCADE;
DROP TABLE IF EXISTS interventions CASCADE;
DROP TABLE IF EXISTS conditions CASCADE;
DROP TABLE IF EXISTS studies CASCADE;

-- ─────────────────────────────────────────────────────────
-- 1. STUDIES (parent table — everything references this)
-- ─────────────────────────────────────────────────────────
CREATE TABLE studies (
    study_id                 SERIAL PRIMARY KEY,
    nct_id                   VARCHAR(20) UNIQUE NOT NULL,
    title                    TEXT,
    acronym                  VARCHAR(50),
    status                   VARCHAR(50),
    status_group             VARCHAR(20),      -- derived: Active/Completed/Stopped/Other
    phase                    VARCHAR(50),      -- cleaned: highest phase or "Unknown"
    study_type               VARCHAR(50),
    start_date               DATE,
    completion_date          DATE,             -- NULLed if > 2031-04-14
    primary_completion_date  DATE,             -- NULLed if > 2031-04-14
    enrollment               INTEGER,
    gender                   VARCHAR(20),
    pre_covid_start          BOOLEAN,          -- flag: start_date < 2020-01-01
    date_error               BOOLEAN           -- flag: start_date < 2000-01-01
);

-- ─────────────────────────────────────────────────────────
-- 2. CONDITIONS
-- ─────────────────────────────────────────────────────────
CREATE TABLE conditions (
    condition_id       SERIAL PRIMARY KEY,
    study_id           INTEGER REFERENCES studies(study_id),
    condition_name     VARCHAR(255),
    mesh_term          VARCHAR(255),
    therapeutic_area   VARCHAR(100)    -- derived: 10 clinical categories
);

-- ─────────────────────────────────────────────────────────
-- 3. INTERVENTIONS
-- ─────────────────────────────────────────────────────────
CREATE TABLE interventions (
    intervention_id    SERIAL PRIMARY KEY,
    study_id           INTEGER REFERENCES studies(study_id),
    intervention_type  VARCHAR(50),
    name               VARCHAR(255),
    description        TEXT
);

-- ─────────────────────────────────────────────────────────
-- 4. OUTCOMES
-- ─────────────────────────────────────────────────────────
CREATE TABLE outcomes (
    outcome_id    SERIAL PRIMARY KEY,
    study_id      INTEGER REFERENCES studies(study_id),
    outcome_type  VARCHAR(20),
    measure       TEXT,
    time_frame    VARCHAR(255),
    description   TEXT
);

-- ─────────────────────────────────────────────────────────
-- 5. SPONSORS
-- ─────────────────────────────────────────────────────────
CREATE TABLE sponsors (
    sponsor_id          SERIAL PRIMARY KEY,
    study_id            INTEGER REFERENCES studies(study_id),
    agency              VARCHAR(255),
    agency_class        VARCHAR(50),
    lead_or_collaborator VARCHAR(20)
);

-- ─────────────────────────────────────────────────────────
-- 6. LOCATIONS
-- ─────────────────────────────────────────────────────────
CREATE TABLE locations (
    location_id  SERIAL PRIMARY KEY,
    study_id     INTEGER REFERENCES studies(study_id),
    facility     VARCHAR(255),
    city         VARCHAR(100),
    state        VARCHAR(100),
    country      VARCHAR(100),
    continent    VARCHAR(50)
);

-- ─────────────────────────────────────────────────────────
-- 7. STUDY DESIGN
-- ─────────────────────────────────────────────────────────
CREATE TABLE study_design (
    design_id           SERIAL PRIMARY KEY,
    study_id            INTEGER REFERENCES studies(study_id),
    allocation          VARCHAR(50),
    intervention_model  VARCHAR(100),
    masking             VARCHAR(100),
    primary_purpose     VARCHAR(50),
    observational_model VARCHAR(50),
    time_perspective    VARCHAR(50)
);

-- ─────────────────────────────────────────────────────────
-- INDEXES 
-- ─────────────────────────────────────────────────────────
CREATE INDEX idx_studies_status       ON studies(status);
CREATE INDEX idx_studies_status_group ON studies(status_group);
CREATE INDEX idx_studies_phase        ON studies(phase);
CREATE INDEX idx_studies_start_date   ON studies(start_date);
CREATE INDEX idx_studies_study_type   ON studies(study_type);
CREATE INDEX idx_conditions_name      ON conditions(condition_name);
CREATE INDEX idx_conditions_area      ON conditions(therapeutic_area);
CREATE INDEX idx_locations_country    ON locations(country);
CREATE INDEX idx_locations_continent  ON locations(continent);
CREATE INDEX idx_sponsors_agency      ON sponsors(agency);
CREATE INDEX idx_interventions_type   ON interventions(intervention_type);