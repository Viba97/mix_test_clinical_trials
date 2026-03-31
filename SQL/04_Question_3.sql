-- ============================================================================
-- Q3 — ENROLLMENT PERFORMANCE
-- ============================================================================
-- Goal: Analyze patient enrollment trends across trial types, and identify
--        which conditions attract the most participants.
--   1. Use MEDIAN (not mean) throughout — enrollment is extremely skewed
--      (mean ~18K vs median 170). Mean would be dominated by a few
--      massive observational studies.
--   2. Exclude enrollment = 0 (107 rows, all Withdrawn — no real enrollment).
--   3. Analyze Interventional and Observational separately — they have
--      fundamentally different enrollment scales.
-- ============================================================================


-- ============================================================================
-- QUERY 3A — Enrollment Distribution by Study Type & Phase
-- ============================================================================
-- What it answers: How does enrollment differ between Interventional and
--                  Observational trials, and across phases?
--
-- Shows: median, 25th percentile (Q1), 75th percentile (Q3), max.
-- This gives a full picture of the distribution shape per group.
-- ============================================================================

SELECT
    study_type,
    phase,
    COUNT(*) AS n_trials,

    -- Q1: 25th percentile
    ROUND(
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY enrollment)::numeric, 0
    ) AS enrollment_q1,

    -- Median: 50th percentile
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY enrollment)::numeric, 0
    ) AS enrollment_median,

    -- Q3: 75th percentile
    ROUND(
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY enrollment)::numeric, 0
    ) AS enrollment_q3,

    -- Max enrollment — shows the upper extreme
    MAX(enrollment) AS enrollment_max

FROM studies
WHERE
    enrollment > 0           -- exclude zero-enrollment (all Withdrawn)
    AND phase != 'Unknown'   -- exclude unknown phase
GROUP BY study_type, phase
ORDER BY study_type, phase;


-- ============================================================================
-- QUERY 3B — Top Conditions by Total Enrollment
-- ============================================================================
-- What it answers: Which specific conditions attract the most participants?
--
-- ============================================================================

WITH condition_enrollment AS (
    SELECT
        c.condition_name,
        c.therapeutic_area,
        COUNT(DISTINCT s.study_id) AS n_trials,
        SUM(s.enrollment) AS total_enrollment,

        -- Median enrollment per trial for this condition
        ROUND(
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY s.enrollment)::numeric,
            0
        ) AS median_enrollment_per_trial

    FROM studies s
    JOIN conditions c ON s.study_id = c.study_id
    WHERE s.enrollment > 0
    GROUP BY c.condition_name, c.therapeutic_area
)

SELECT
    condition_name,
    therapeutic_area,
    n_trials,
    total_enrollment,
    median_enrollment_per_trial,

    -- Rank by total enrollment across all conditions
    RANK() OVER(ORDER BY total_enrollment DESC) AS enrollment_rank

FROM condition_enrollment
ORDER BY enrollment_rank
LIMIT 20;


