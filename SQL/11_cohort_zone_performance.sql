-- ============================================================
-- Query 11: Monthly Zone Performance Cohort Analysis
-- Purpose : Track how zone performance changes month
--           over month — identify improving vs declining zones
-- ============================================================

WITH monthly_zone AS (
    SELECT
        month,
        pickup_zone_id                                   AS zone_id,
        pickup_zone_name                                 AS zone_name,
        pickup_zone_type                                 AS zone_type,
        COUNT(*)                                         AS total_rides,
        ROUND(COUNT(CASE WHEN status = 'completed'
            THEN 1 END) * 100.0
            / NULLIF(COUNT(*), 0), 1)                    AS completion_rate,
        ROUND(AVG(wait_time_min)::NUMERIC, 1)            AS avg_wait,
        ROUND(SUM(fare_amount)
            FILTER (WHERE status = 'completed')
            ::NUMERIC, 0)                                AS monthly_revenue,
        ROUND(AVG(surge_multiplier)::NUMERIC, 2)         AS avg_surge,
        COUNT(CASE WHEN status = 'no_driver_found'
            THEN 1 END)                                  AS unmet_rides
    FROM rides
    GROUP BY
        month,
        pickup_zone_id,
        pickup_zone_name,
        pickup_zone_type
),

with_lag AS (
    SELECT
        *,
        LAG(monthly_revenue) OVER (
            PARTITION BY zone_id
            ORDER BY month
        )                                                AS prev_month_revenue,
        LAG(completion_rate) OVER (
            PARTITION BY zone_id
            ORDER BY month
        )                                                AS prev_completion_rate,
        LAG(avg_wait) OVER (
            PARTITION BY zone_id
            ORDER BY month
        )                                                AS prev_avg_wait
    FROM monthly_zone
)

SELECT
    month,
    zone_id,
    zone_name,
    zone_type,
    total_rides,
    completion_rate,
    avg_wait,
    monthly_revenue,
    avg_surge,
    unmet_rides,
    prev_month_revenue,
    prev_completion_rate,
    prev_avg_wait,

    -- Month over month revenue change
    ROUND((monthly_revenue - prev_month_revenue)
        ::NUMERIC, 0)                                    AS revenue_mom_change,
    ROUND((monthly_revenue - prev_month_revenue)
        * 100.0 / NULLIF(prev_month_revenue, 0)
        ::NUMERIC, 1)                                    AS revenue_mom_pct,

    -- Completion rate change
    ROUND((completion_rate - prev_completion_rate)
        ::NUMERIC, 1)                                    AS completion_mom_change,

    -- Wait time change
    ROUND((avg_wait - prev_avg_wait)::NUMERIC, 1)        AS wait_mom_change,

    -- Zone trajectory
    CASE
        WHEN (monthly_revenue - prev_month_revenue) > 0
             AND (completion_rate - prev_completion_rate) > 0
             THEN 'IMPROVING'
        WHEN (monthly_revenue - prev_month_revenue) < 0
             AND (completion_rate - prev_completion_rate) < 0
             THEN 'DECLINING'
        WHEN (monthly_revenue - prev_month_revenue) > 0
             THEN 'REVENUE GROWING'
        WHEN (completion_rate - prev_completion_rate) > 0
             THEN 'QUALITY IMPROVING'
        ELSE 'STABLE'
    END                                                  AS zone_trajectory

FROM with_lag
WHERE prev_month_revenue IS NOT NULL
ORDER BY
    zone_id,
    month;