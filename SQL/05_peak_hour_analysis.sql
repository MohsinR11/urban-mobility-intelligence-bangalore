-- ============================================================
-- Query 05: Peak Hour Zone Performance Analysis
-- Purpose : Which zones perform best and worst during
--           morning and evening peak hours specifically
-- ============================================================

WITH peak_rides AS (
    SELECT
        pickup_zone_id,
        pickup_zone_name,
        pickup_zone_type,
        CASE
            WHEN hour BETWEEN 7  AND 10 THEN 'MORNING_PEAK'
            WHEN hour BETWEEN 17 AND 21 THEN 'EVENING_PEAK'
        END                                              AS peak_period,
        COUNT(*)                                         AS total_rides,
        COUNT(CASE WHEN status = 'completed'
                   THEN 1 END)                           AS completed,
        COUNT(CASE WHEN status = 'no_driver_found'
                   THEN 1 END)                           AS unmet,
        ROUND(AVG(wait_time_min)::NUMERIC, 1)            AS avg_wait,
        ROUND(AVG(fare_amount)
            FILTER (WHERE status = 'completed')
            ::NUMERIC, 0)                                AS avg_fare,
        ROUND(AVG(surge_multiplier)::NUMERIC, 2)         AS avg_surge,
        ROUND(SUM(fare_amount)
            FILTER (WHERE status = 'completed')
            ::NUMERIC, 0)                                AS total_revenue
    FROM rides
    WHERE hour BETWEEN 7 AND 10
       OR hour BETWEEN 17 AND 21
    GROUP BY
        pickup_zone_id,
        pickup_zone_name,
        pickup_zone_type,
        CASE
            WHEN hour BETWEEN 7  AND 10 THEN 'MORNING_PEAK'
            WHEN hour BETWEEN 17 AND 21 THEN 'EVENING_PEAK'
        END
),

ranked AS (
    SELECT
        *,
        ROUND(completed * 100.0
            / NULLIF(total_rides, 0), 1)                 AS completion_pct,
        ROUND(unmet * 100.0
            / NULLIF(total_rides, 0), 1)                 AS unmet_demand_pct,
        RANK() OVER (
            PARTITION BY peak_period
            ORDER BY total_revenue DESC
        )                                                AS revenue_rank,
        RANK() OVER (
            PARTITION BY peak_period
            ORDER BY avg_wait DESC
        )                                                AS worst_wait_rank
    FROM peak_rides
)

SELECT
    peak_period,
    pickup_zone_id                                       AS zone_id,
    pickup_zone_name                                     AS zone_name,
    pickup_zone_type                                     AS zone_type,
    total_rides,
    completed,
    unmet,
    completion_pct,
    unmet_demand_pct,
    avg_wait,
    avg_fare,
    avg_surge,
    total_revenue,
    revenue_rank,
    worst_wait_rank,
    CASE
        WHEN revenue_rank    <= 10 THEN 'TOP REVENUE ZONE'
        WHEN worst_wait_rank <= 10 THEN 'HIGH WAIT ZONE'
        WHEN unmet_demand_pct >= 8 THEN 'DEMAND SHORTAGE'
        WHEN completion_pct  >= 82 THEN 'HIGH PERFORMER'
        ELSE 'STANDARD'
    END                                                  AS zone_peak_class
FROM ranked
ORDER BY
    peak_period,
    total_revenue DESC;