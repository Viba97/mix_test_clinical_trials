-- ============================================================================
-- Q5 — DURATION ANALYSIS
-- ============================================================================
-- Goal: Analyze typical trial duration by phase and therapeutic area,
--        and identify trials that take significantly longer than expected.
--
-- KEY DECISIONS:
--   1. Duration = completion_date - start_date (in days).
--      Only computed when BOTH dates are non-NULL.
--   2. Exclude pre_covid_start = TRUE (pre-2020 repurposed trials —
--      their duration reflects pre-COVID timelines, not COVID response).
--   3. Exclude date_error = TRUE (1 trial with pre-2000 date).
--   4. Only include Completed trials for "typical" duration — Stopped
--      trials ended prematurely, Active trials haven't ended yet.
-- ============================================================================


-- ============================================================================
-- QUERY 5A — Duration Distribution by Phase
-- ============================================================================
-- What it answers: How long do completed trials typically take, by phase?
--
-- Shows full distribution: Q1, median, Q3, plus mean for comparison.
-- The gap between mean and median reveals skewness.
--
-- Also shows the count — small N means less reliable statistics.
-- ============================================================================

WITH durations AS (
    -- Compute absolute duration in days for completed trials
    SELECT
        study_id,
        phase,
        study_type,

        -- Simple subtraction (End - Start) returns the total integer count of days.
        -- This handles trials spanning multiple months/years correctly.
        (completion_date - start_date) AS duration_days

    FROM studies
    WHERE
        status_group = 'Completed'      -- Only finished trials
        AND completion_date IS NOT NULL  -- Requires both dates
        AND start_date IS NOT NULL
        AND pre_covid_start = FALSE      -- Exclude repurposed pre-2020 trials
        AND date_error = FALSE           -- Exclude data errors (e.g., end before start)
        -- Safety check: Ensure duration is non-negative
        AND (completion_date - start_date) >= 0
)

SELECT
    phase,
    COUNT(*) AS n_trials,

    -- Full distribution using the corrected duration_days
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY duration_days)::numeric, 0) AS duration_q1,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY duration_days)::numeric, 0) AS duration_median,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY duration_days)::numeric, 0) AS duration_q3,

    -- Mean for comparison
    ROUND(AVG(duration_days)::numeric, 0) AS duration_mean,

    -- Absolute Range
    MIN(duration_days)::int AS duration_min,
    MAX(duration_days)::int AS duration_max

FROM durations
WHERE phase != 'Unknown'
GROUP BY phase
ORDER BY duration_median;


-- ============================================================================
-- QUERY 5B — Duration by Therapeutic Area
-- ============================================================================
-- What it answers: Do certain therapeutic areas take longer?
--
-- Same logic as 5A but grouped by therapeutic_area instead of phase.
-- ============================================================================

WITH durations AS (
    -- Step 1: Compute absolute duration (Total Days)
    -- Corrected to handle periods longer than a month accurately
    SELECT
        s.study_id,
        (s.completion_date - s.start_date) AS duration_days
    FROM studies s
    WHERE
        s.status_group = 'Completed'
        AND s.completion_date IS NOT NULL
        AND s.start_date IS NOT NULL
        AND s.pre_covid_start = FALSE
        AND s.date_error = FALSE
        -- Ensure only valid positive durations are included
        AND (s.completion_date - s.start_date) >= 0
),
study_area_map AS (
    -- Step 2: Map trials to ALL their therapeutic areas
    -- We use DISTINCT to ensure one trial doesn't count twice for the SAME area
    -- but allow it to count for DIFFERENT areas (e.g., Respiratory AND Infectious)
    SELECT DISTINCT
        study_id,
        therapeutic_area
    FROM conditions
    WHERE therapeutic_area IS NOT NULL
)

SELECT
    sam.therapeutic_area,
    -- This now represents the number of trials touching this specific area
    COUNT(d.study_id) AS n_trials,

    -- Absolute day distribution stats
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY d.duration_days)::numeric, 0) AS duration_q1,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY d.duration_days)::numeric, 0) AS duration_median,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY d.duration_days)::numeric, 0) AS duration_q3,

    -- Mean for comparison (Average absolute days)
    ROUND(AVG(d.duration_days)::numeric, 0) AS duration_mean,

    -- Range in absolute days
    MIN(d.duration_days)::int AS duration_min,
    MAX(d.duration_days)::int AS duration_max

FROM durations d
JOIN study_area_map sam ON d.study_id = sam.study_id
GROUP BY sam.therapeutic_area

-- Requirement for statistical weight
HAVING COUNT(*) >= 10

ORDER BY duration_median DESC;



-- ============================================================================
-- QUERY 5C — Duration by Therapeutic Area and Phase
-- ============================================================================
--
-- UNIFIYNG DURATION ANALYSIS BY PHASE AND THERAPEUTIC AREA
-- ============================================================================


WITH durations AS (
    -- Step 1: Compute absolute duration for completed interventional trials
    SELECT
        s.study_id,
        s.phase,
        -- Simple subtraction for absolute total days
        (s.completion_date - s.start_date) AS duration_days
    FROM studies s
    WHERE
        s.status_group = 'Completed'
        AND s.completion_date IS NOT NULL
        AND s.start_date IS NOT NULL
        AND s.pre_covid_start = FALSE
        AND s.date_error = FALSE
        AND (s.completion_date - s.start_date) >= 0
        -- Focusing on the active clinical pipeline
        AND s.phase NOT IN ('Unknown', 'Not Applicable')
),
study_area_map AS (
    -- Step 2: Multi-label mapping
    -- One trial can belong to multiple areas, but we use DISTINCT 
    -- to prevent multiple conditions in the SAME area from over-counting.
    SELECT DISTINCT
        study_id,
        therapeutic_area
    FROM conditions
    WHERE therapeutic_area IS NOT NULL
)

SELECT
    sam.therapeutic_area,
    d.phase,
    COUNT(*) AS n_trials,
    -- Distribution stats for the dashboard
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY d.duration_days)::numeric, 0) AS duration_median,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY d.duration_days)::numeric, 0) AS duration_q1,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY d.duration_days)::numeric, 0) AS duration_q3

FROM durations d
JOIN study_area_map sam ON d.study_id = sam.study_id
GROUP BY sam.therapeutic_area, d.phase
HAVING COUNT(*) >= 1
ORDER BY sam.therapeutic_area, d.phase;