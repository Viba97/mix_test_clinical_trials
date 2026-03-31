-- ============================================================================
-- Q1 — TRIAL LANDSCAPE OVERVIEW
-- ============================================================================
-- Goal: Understand the distribution of COVID-19 clinical trials by phase,
--        status, and therapeutic area, and how this evolved over time.
-- ============================================================================


-- ============================================================================
-- QUERY 1A — Distribution by Phase
-- ============================================================================
-- What it answers: How many trials exist in each phase?
-- ============================================================================

WITH phase_counts AS (
    -- Step 1: count how many trials exist for each phase value.
    -- GROUP BY collapses all rows with the same phase into one row,
    -- then COUNT(*) counts how many rows were in each group.
    SELECT
        phase,
        COUNT(*) AS trial_count
    FROM studies
    GROUP BY phase
)
SELECT
    phase,
    trial_count,

    -- SUM(trial_count) OVER() is a window function.
    -- OVER() with empty parentheses = "compute over ALL rows in the result".
    -- So SUM(trial_count) OVER() = total trials across all phases.
    -- We divide each phase's count by this total to get a percentage.
    ROUND(100.0 * trial_count / SUM(trial_count) OVER(), 1) AS pct

FROM phase_counts

-- ORDER BY trial_count DESC puts the most common phase first.
ORDER BY trial_count DESC;


-- ============================================================================
-- QUERY 1B — Distribution by Status Group
-- ============================================================================
-- What it answers: How are trials distributed across Active / Completed /
--                  Stopped? And within each group, what are the raw statuses?
-- ============================================================================

WITH group_level AS (
    -- High-level counts: Active, Completed, Stopped
    SELECT
        status_group,
        COUNT(*) AS group_count
    FROM studies
    GROUP BY status_group
),
detail_level AS (
    -- Detailed counts: every raw status value, with its parent group
    SELECT
        status_group,
        status,
        COUNT(*) AS status_count
    FROM studies
    GROUP BY status_group, status
)

SELECT
    d.status_group,
    d.status,
    d.status_count,

    -- g.group_count comes from the group_level CTE via the JOIN.
    -- This lets us compute what % of its parent group each raw status represents.
    g.group_count,

    -- Percentage of each raw status within its group
    ROUND(100.0 * d.status_count / g.group_count, 1) AS pct_within_group,

    -- Percentage of each raw status out of the entire dataset
    -- SUM(d.status_count) OVER() = total across ALL rows = 5,749
    ROUND(100.0 * d.status_count / SUM(d.status_count) OVER(), 1) AS pct_overall

FROM detail_level d

-- JOIN connects each detail row to its parent group row.
-- The ON clause says: "match rows where status_group is the same".
JOIN group_level g ON d.status_group = g.status_group

-- Primary sort: by group size (largest group first).
-- Secondary sort: within each group, by raw status count (largest first).
ORDER BY g.group_count DESC, d.status_count DESC;


-- ============================================================================
-- QUERY 1C — Distribution by Therapeutic Area
-- ============================================================================
-- What it answers: How many distinct trials target each therapeutic area?

--   One trial can have MULTIPLE conditions (e.g., "COVID-19" AND "Pneumonia").
--   These conditions may belong to DIFFERENT therapeutic areas.
--   So after the JOIN, one study_id can appear in multiple rows.
--
--   the sum of trial_count across all areas will be > 5,749
--   because a trial in 2 areas gets counted once in each.
--   That's correct — it tells us "how many trials are relevant to this area".
--
--   The percentage is calculated against 5,749 (total distinct studies),
--   so percentages will sum to > 100%. This is intentional and standard
--   for multi-label classification.
-- ============================================================================

WITH area_counts AS (
    SELECT
        c.therapeutic_area,

        -- COUNT(DISTINCT ...) = count unique study_ids only.
        -- Without DISTINCT, a trial with 3 conditions in the same area
        -- would be counted 3 times.
        COUNT(DISTINCT s.study_id) AS trial_count

    FROM studies s
    -- One study can have many conditions, so this is a one-to-many join:
    -- each study row gets duplicated for each of its conditions.
    JOIN conditions c ON s.study_id = c.study_id

    GROUP BY c.therapeutic_area
),
total AS (
    -- Subquery to get the total number of distinct studies.
    -- We use this as the denominator for percentages.
    -- We compute it separately because SUM(trial_count) from area_counts
    -- would give us the INFLATED total (due to multi-area studies).
    SELECT COUNT(*) AS n FROM studies
)

SELECT
    a.therapeutic_area,
    a.trial_count,

    -- Cross join with total: every row gets access to total.n
    -- This is a common pattern when you need a single scalar value
    -- available in every row.
    ROUND(100.0 * a.trial_count / t.n, 1) AS pct_of_all_studies

FROM area_counts a

-- CROSS JOIN: combines every row from area_counts with the single row
-- from total. Since total has exactly 1 row, this just adds the column.
CROSS JOIN total t

ORDER BY a.trial_count DESC;


-- ============================================================================
-- QUERY 1D — Temporal Evolution (monthly)
-- ============================================================================
-- What it answers: How many trials started each month, by status group?
--                  What's the cumulative trend?
--
-- Design decisions:
--   1. We use start_date (not completion_date) because it tells us
--      WHEN the trial was launched — this shows the research response timeline.
--   2. We exclude pre_covid_start = TRUE (175 trials started before 2020).
--      These are repurposed trials — including them would create misleading
--      spikes in pre-pandemic months.
--   3. We also exclude rows where start_date IS NULL (can't place them).
--   4. DATE_TRUNC('month', ...) rounds every date to the 1st of its month.
--      e.g., 2020-03-17 → 2020-03-01. This lets us group by month.
--
-- FILTER clause (PostgreSQL-specific):
--   COUNT(*) FILTER (WHERE condition) counts only rows matching the condition.
--   It's equivalent to SUM(CASE WHEN condition THEN 1 ELSE 0 END)
--   but much more readable.
-- ============================================================================

WITH monthly AS (
    SELECT
        -- DATE_TRUNC truncates the date to the specified precision.
        -- 'month' means: keep year and month, set day to 01.
        DATE_TRUNC('month', start_date) AS month,

        -- Total trials started this month (all statuses)
        COUNT(*) AS total_started,

        -- Breakdown by status_group using FILTER:
        -- Each FILTER counts only the rows where the condition is true.
        COUNT(*) FILTER (WHERE status_group = 'Active')    AS active,
        COUNT(*) FILTER (WHERE status_group = 'Completed') AS completed,
        COUNT(*) FILTER (WHERE status_group = 'Stopped')   AS stopped

    FROM studies

    WHERE
        -- Exclude pre-COVID repurposed trials
        pre_covid_start = FALSE
        -- Exclude rows without a start date (can't place them on timeline)
        AND start_date IS NOT NULL

    GROUP BY DATE_TRUNC('month', start_date)
)

SELECT
    month,
    total_started,
    active,
    completed,
    stopped,

    -- Running total: SUM(total_started) OVER(ORDER BY month)
    -- For each row, this sums total_started from the earliest month
    -- up to and including the current row.
    -- Example:
    --   Jan: 50  → cumulative = 50
    --   Feb: 120 → cumulative = 170
    --   Mar: 300 → cumulative = 470
    SUM(total_started) OVER(ORDER BY month) AS cumulative_total

FROM monthly
ORDER BY month;