-- ============================================================================
-- Q2 — COMPLETION ANALYSIS
-- ============================================================================
-- Goal: Identify factors associated with higher completion rates, and
--        analyze patterns in terminated/withdrawn trials.
-- only include "resolved" trials in completion rate
-- calculations. A trial is resolved if status_group = 'Completed' or
-- status_group = 'Stopped'. Active trials are excluded because they
-- haven't reached an outcome yet.
-- ============================================================================


-- ============================================================================
-- QUERY 2A — Completion Rate by Phase & Study Type
-- ============================================================================
-- What it answers: Does phase or study type (Interventional vs Observational)
--                  predict whether a trial completes successfully?
--
-- Logic:
--   1. Filter to resolved trials only (Completed + Stopped)
--   2. Group by phase and study_type
--   3. Count total resolved and completed within each group
--   4. Compute completion rate as completed / resolved
--
-- ============================================================================

WITH resolved AS (
    -- Step 1: keep only trials that have reached a final state.
    -- Active trials are still running — we can't judge them yet.
    SELECT
        study_id,
        phase,
        study_type,
        status_group,
        enrollment
    FROM studies
    WHERE status_group IN ('Completed', 'Stopped')
)

SELECT
    phase,
    study_type,

    -- Total resolved trials in this group
    COUNT(*) AS total_resolved,

    -- How many completed successfully
    -- FILTER counts only the rows where the condition is true.
    COUNT(*) FILTER (WHERE status_group = 'Completed') AS completed,

    -- How many stopped (Withdrawn + Terminated + Suspended)
    COUNT(*) FILTER (WHERE status_group = 'Stopped') AS stopped,

    -- Completion rate = completed / total resolved × 100
    -- This tells us: of the trials that DID reach an outcome,
    -- what percentage finished successfully?
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status_group = 'Completed')
        / COUNT(*),
        1
    ) AS completion_rate_pct,

    -- Median enrollment for context: are bigger trials harder to complete?
    -- PERCENTILE_CONT(0.5) computes the 50th percentile (median).
    -- WITHIN GROUP (ORDER BY enrollment) tells PostgreSQL which column
    -- to compute the percentile on and how to sort it.
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY enrollment)::numeric,
        0
    ) AS median_enrollment

FROM resolved

-- Exclude Unknown phase — adds noise without insight
WHERE phase != 'Unknown'

GROUP BY phase, study_type

-- Show highest completion rates first
ORDER BY completion_rate_pct DESC;

-- ============================================================================
-- QUERY 2B — Completion Rate by Sponsor Type
-- ============================================================================
-- What it answers: Do industry-sponsored trials complete more or less often
--                  than academic or government-funded ones?
--
-- Design decisions:
--   - sponsors table has `agency_class` and `lead_or_collaborator` columns.
--   - We filter to 'Lead' only — each trial has exactly one lead sponsor,
--     so no double-counting.
--   - agency_class values: Industry, NIH, U.S. Fed, Other, etc.
--   - Same resolved-only filter as 2A.
-- ============================================================================
 
WITH resolved_sponsored AS (
    SELECT
        s.study_id,
        s.status_group,
        sp.agency_class
    FROM studies s
    JOIN sponsors sp ON s.study_id = sp.study_id
    WHERE
        s.status_group IN ('Completed', 'Stopped')
        AND sp.lead_or_collaborator = 'Lead'
)
 
SELECT
    agency_class,
    COUNT(*) AS total_resolved,
    COUNT(*) FILTER (WHERE status_group = 'Completed') AS completed,
    COUNT(*) FILTER (WHERE status_group = 'Stopped') AS stopped,
 
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status_group = 'Completed')
        / COUNT(*),
        1
    ) AS completion_rate_pct
 
FROM resolved_sponsored
GROUP BY agency_class
ORDER BY completion_rate_pct DESC;



-- ============================================================================
-- QUERY 2C — Completion Rate by Study Design Features
-- ============================================================================
-- What it answers: Does randomization, masking, or allocation method
--                  affect whether a trial completes?
--
-- Tables: studies + study_design (1:1 relationship via study_id)
--
-- The study_design table has columns like:
--   - allocation (Randomized, Non-Randomized, N/A)
--   - intervention_model (Parallel, Sequential, Single Group, etc.)
--   - masking (None/Open Label, Single, Double, Triple, Quadruple)
--
-- We'll compute completion rate for each value of each design feature.
-- Using UNION ALL to stack three separate analyses into one result set.
-- ============================================================================

WITH resolved_design AS (
    SELECT
        s.study_id,
        s.status_group,
        sd.allocation,
        sd.intervention_model,
        sd.masking
    FROM studies s
    JOIN study_design sd ON s.study_id = sd.study_id
    WHERE s.status_group IN ('Completed', 'Stopped')
)

-- Block 1: by allocation
SELECT
    'Allocation' AS design_feature,
    allocation AS feature_value,
    COUNT(*) AS total_resolved,
    COUNT(*) FILTER (WHERE status_group = 'Completed') AS completed,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status_group = 'Completed')
        / COUNT(*), 1
    ) AS completion_rate_pct
FROM resolved_design
WHERE allocation IS NOT NULL
GROUP BY allocation

-- UNION ALL stacks the results from multiple SELECTs into one table.
-- Unlike UNION (without ALL), it keeps duplicates — which is what we want
-- because the same completion rate could appear in different features.
UNION ALL

-- Block 2: by intervention model
SELECT
    'Intervention Model' AS design_feature,
    intervention_model AS feature_value,
    COUNT(*) AS total_resolved,
    COUNT(*) FILTER (WHERE status_group = 'Completed') AS completed,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status_group = 'Completed')
        / COUNT(*), 1
    ) AS completion_rate_pct
FROM resolved_design
WHERE intervention_model IS NOT NULL
GROUP BY intervention_model

UNION ALL

-- Block 3: by masking
SELECT
    'Masking' AS design_feature,
    masking AS feature_value,
    COUNT(*) AS total_resolved,
    COUNT(*) FILTER (WHERE status_group = 'Completed') AS completed,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status_group = 'Completed')
        / COUNT(*), 1
    ) AS completion_rate_pct
FROM resolved_design
WHERE masking IS NOT NULL
GROUP BY masking

ORDER BY design_feature, completion_rate_pct DESC;


-- ============================================================================
-- QUERY 2D — Stopped Trials Deep Dive
-- ============================================================================
-- What it answers: What patterns exist among failed trials?
--                  Which phases, study types, and enrollment levels
--                  are most associated with failure?
--
-- Two parts:
--   Part 1: Summary statistics for stopped trials by raw status and phase
--   Part 2: Rank the "worst" categories by failure count
--
-- ============================================================================

-- Part 1: Breakdown of stopped trials by raw status × phase
WITH stopped_detail AS (
    SELECT
        status,          -- raw status: Withdrawn, Terminated, Suspended
        phase,
        study_type,
        enrollment,
        -- Duration in days (only if both dates exist)
        -- AGE() returns an interval (e.g., '3 months 12 days').
        -- EXTRACT(DAY FROM ...) converts the full interval to days.
        CASE
            WHEN completion_date IS NOT NULL AND start_date IS NOT NULL
            THEN EXTRACT(DAY FROM AGE(completion_date, start_date))
        END AS duration_days
    FROM studies
    WHERE status_group = 'Stopped'
),

stopped_summary AS (
    SELECT
        status,
        phase,
        COUNT(*) AS n_trials,

        -- Median enrollment of stopped trials in this group
        ROUND(
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY enrollment)::numeric,
            0
        ) AS median_enrollment,

        -- Median duration (where available)
        ROUND(
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duration_days)::numeric,
            0
        ) AS median_duration_days

    FROM stopped_detail
    WHERE phase != 'Unknown'
    GROUP BY status, phase
)

SELECT
    status,
    phase,
    n_trials,
    median_enrollment,
    median_duration_days,

    -- RANK() assigns a rank within each raw status group.
    -- PARTITION BY status = "restart ranking for each status".
    -- ORDER BY n_trials DESC = "most trials = rank 1".
    -- This tells us: within Withdrawn trials, which phase fails most?
    RANK() OVER(
        PARTITION BY status
        ORDER BY n_trials DESC
    ) AS rank_within_status

FROM stopped_summary
ORDER BY status, rank_within_status;