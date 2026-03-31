-- ============================================================================
-- Q4 — GEOGRAPHIC INSIGHTS
-- ============================================================================
-- Goal: Analyze the global distribution of trials and identify regional
--        specializations in therapeutic areas.
--
-- KEY DECISIONS:
--   1. A trial can have MULTIPLE locations (multi-site trials).
--      locations table has ~23,703 rows for 5,749 studies.
--      We use COUNT(DISTINCT study_id) to avoid inflation.
--   2. Country is the primary geographic unit (city/facility are NULL).
--   3. Continent is derived from a lookup — gives a higher-level view.
--   4. 3 unmapped countries (~0.8%) are parsing artifacts — excluded
--      with WHERE continent IS NOT NULL.
-- ============================================================================


-- ============================================================================
-- QUERY 4A — Trial Count by Continent
-- ============================================================================
-- What it answers: How are trials distributed globally at continent level?
--
--   A multi-site trial in France AND Germany counts once for Europe.
--   But if it's in France AND USA, it counts once for Europe, once
--   for North America.
-- ============================================================================

WITH continent_counts AS (
    SELECT
        l.continent,
        COUNT(DISTINCT l.study_id) AS trial_count
    FROM locations l
    WHERE l.continent IS NOT NULL
    GROUP BY l.continent
),
total AS (
    SELECT COUNT(DISTINCT study_id) AS n FROM locations
    WHERE continent IS NOT NULL
)
SELECT
    c.continent,
    c.trial_count,
    ROUND(100.0 * c.trial_count / t.n, 1) AS pct_of_trials

FROM continent_counts c
CROSS JOIN total t
ORDER BY c.trial_count DESC;


-- ============================================================================
-- QUERY 4B — Regional Specialization by Therapeutic Area
-- ============================================================================
-- What it answers: Do certain continents focus on specific therapeutic areas
--                  more than the global average?
--
-- This is the most complex query in the project. The logic:
--   1. For each continent, count trials per therapeutic area
--   2. Compute each area's share within that continent
--   3. Compute each area's share globally
--
--
-- ============================================================================

WITH regional AS (
    -- Count distinct trials per continent × therapeutic area
    SELECT
        l.continent,
        c.therapeutic_area,
        COUNT(DISTINCT s.study_id) AS area_trials
    FROM studies s
    JOIN locations l ON s.study_id = l.study_id
    JOIN conditions c ON s.study_id = c.study_id
    WHERE l.continent IS NOT NULL
    GROUP BY l.continent, c.therapeutic_area
),
continent_totals AS (
    -- Total distinct trials per continent (denominator for local %)
    SELECT
        l.continent,
        COUNT(DISTINCT l.study_id) AS continent_trials
    FROM locations l
    WHERE l.continent IS NOT NULL
    GROUP BY l.continent
),
global_area AS (
    -- Global share of each therapeutic area (baseline for comparison)
    SELECT
        c.therapeutic_area,
        COUNT(DISTINCT s.study_id) AS global_trials,
        -- Total studies globally
        (SELECT COUNT(*) FROM studies) AS total_studies
    FROM studies s
    JOIN conditions c ON s.study_id = c.study_id
    GROUP BY c.therapeutic_area
)

SELECT
    r.continent,
    r.therapeutic_area,
    r.area_trials,

    -- Local share: what % of this continent's trials are in this area?
    ROUND(100.0 * r.area_trials / ct.continent_trials, 1) AS local_pct,

    -- Global share: what % of ALL trials globally are in this area?
    ROUND(100.0 * ga.global_trials / ga.total_studies, 1) AS global_pct,

    -- Specialization index: local_pct / global_pct
    -- > 1.0 = over-represented (specialization)
    -- < 1.0 = under-represented
    -- = 1.0 = exactly at global average
    ROUND(
        (100.0 * r.area_trials / ct.continent_trials)
        / NULLIF(100.0 * ga.global_trials / ga.total_studies, 0),
        2
    ) AS specialization_index

FROM regional r

-- Join continent totals for the denominator
JOIN continent_totals ct ON r.continent = ct.continent

-- Join global averages for comparison
JOIN global_area ga ON r.therapeutic_area = ga.therapeutic_area

-- Only show meaningful combinations (at least 5 trials)
-- HAVING filters AFTER grouping, but here we filter the joined result.
WHERE r.area_trials >= 5

ORDER BY r.continent, specialization_index DESC;


