-- ============================================================
-- Query 06: Comprehensive Zone Efficiency Scorecard
-- Purpose : Single composite score per zone combining
--           all KPIs — the master zone health metric
-- ============================================================

WITH zone_kpis AS (
    SELECT
        pickup_zone_id                                   AS zone_id,
        pickup_zone_name                                 AS zone_name,
        pickup_zone_type                                 AS zone_type,
        COUNT(*)                                         AS total_rides,
        ROUND(COUNT(CASE WHEN status = 'completed'
            THEN 1 END) * 100.0
            / NULLIF(COUNT(*), 0), 1)                    AS completion_rate,
        ROUND(COUNT(CASE WHEN status = 'no_driver_found'
            THEN 1 END) * 100.0
            / NULLIF(COUNT(*), 0), 1)                    AS unmet_rate,
        ROUND(AVG(wait_time_min)::NUMERIC, 1)            AS avg_wait,
        ROUND(AVG(fare_amount)
            FILTER (WHERE status = 'completed')
            ::NUMERIC, 0)                                AS avg_fare,
        ROUND(AVG(surge_multiplier)::NUMERIC, 2)         AS avg_surge,
        ROUND(SUM(fare_amount)
            FILTER (WHERE status = 'completed')
            ::NUMERIC, 0)                                AS total_revenue,
        ROUND(AVG(ride_rating)::NUMERIC, 2)              AS avg_rating,
        COUNT(CASE WHEN is_raining = TRUE
            THEN 1 END)                                  AS rainy_rides,
        COUNT(CASE WHEN active_event_id IS NOT NULL
            THEN 1 END)                                  AS event_rides
    FROM rides
    GROUP BY
        pickup_zone_id,
        pickup_zone_name,
        pickup_zone_type
),

-- Normalize each KPI to 0-100 scale
normalized AS (
    SELECT
        *,
        -- Completion score: higher is better
        ROUND((completion_rate - MIN(completion_rate) OVER())
            / NULLIF(MAX(completion_rate) OVER()
                - MIN(completion_rate) OVER(), 0)
            * 100, 1)                                    AS completion_score,

        -- Wait score: lower wait is better (inverted)
        ROUND((1 - (avg_wait - MIN(avg_wait) OVER())
            / NULLIF(MAX(avg_wait) OVER()
                - MIN(avg_wait) OVER(), 0))
            * 100, 1)                                    AS wait_score,

        -- Revenue score: higher is better
        ROUND((total_revenue - MIN(total_revenue) OVER())
            / NULLIF(MAX(total_revenue) OVER()
                - MIN(total_revenue) OVER(), 0)
            * 100, 1)                                    AS revenue_score,

        -- Demand score: lower unmet is better (inverted)
        ROUND((1 - (unmet_rate - MIN(unmet_rate) OVER())
            / NULLIF(MAX(unmet_rate) OVER()
                - MIN(unmet_rate) OVER(), 0))
            * 100, 1)                                    AS demand_score,

        -- Rating score: higher is better
        ROUND((avg_rating - MIN(avg_rating) OVER())
            / NULLIF(MAX(avg_rating) OVER()
                - MIN(avg_rating) OVER(), 0)
            * 100, 1)                                    AS rating_score
    FROM zone_kpis
)

SELECT
    zone_id,
    zone_name,
    zone_type,
    total_rides,
    completion_rate,
    unmet_rate,
    avg_wait,
    avg_fare,
    avg_surge,
    total_revenue,
    avg_rating,
    completion_score,
    wait_score,
    revenue_score,
    demand_score,
    rating_score,

    -- Composite efficiency score (weighted)
    ROUND((
        completion_score * 0.25 +
        wait_score       * 0.20 +
        revenue_score    * 0.30 +
        demand_score     * 0.15 +
        rating_score     * 0.10
    ), 1)                                                AS efficiency_score,

    -- Grade
    CASE
        WHEN (completion_score * 0.25 + wait_score * 0.20 +
              revenue_score * 0.30 + demand_score * 0.15 +
              rating_score  * 0.10) >= 75 THEN 'A — EXCELLENT'
        WHEN (completion_score * 0.25 + wait_score * 0.20 +
              revenue_score * 0.30 + demand_score * 0.15 +
              rating_score  * 0.10) >= 55 THEN 'B — GOOD'
        WHEN (completion_score * 0.25 + wait_score * 0.20 +
              revenue_score * 0.30 + demand_score * 0.15 +
              rating_score  * 0.10) >= 35 THEN 'C — AVERAGE'
        ELSE 'D — POOR'
    END                                                  AS efficiency_grade

FROM normalized
ORDER BY efficiency_score DESC;