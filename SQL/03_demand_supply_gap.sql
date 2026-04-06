-- ============================================================
-- URBAN MOBILITY INTELLIGENCE SYSTEM
-- Query 02: Hourly Demand-Supply Gap Analysis
-- Purpose : Find which hours have worst mismatch between
--           rider demand and driver availability
-- ============================================================

WITH hourly_demand AS (
    SELECT
        hour,
        day_of_week,
        is_weekend,
        COUNT(*)                                        AS total_requests,
        COUNT(CASE WHEN status = 'completed'
                   THEN 1 END)                          AS completed,
        COUNT(CASE WHEN status = 'no_driver_found'
                   THEN 1 END)                          AS unmet_demand,
        COUNT(CASE WHEN status = 'cancelled_by_rider'
                   THEN 1 END)                          AS rider_cancelled,
        ROUND(AVG(wait_time_min)::NUMERIC, 1)           AS avg_wait_min,
        ROUND(AVG(fare_amount)
            FILTER (WHERE status = 'completed')
            ::NUMERIC, 0)                               AS avg_fare,
        ROUND(AVG(surge_multiplier)::NUMERIC, 2)        AS avg_surge,
        ROUND(SUM(fare_amount)
            FILTER (WHERE status = 'completed')
            ::NUMERIC, 0)                               AS total_revenue
    FROM rides
    GROUP BY hour, day_of_week, is_weekend
),

hourly_summary AS (
    SELECT
        hour,
        is_weekend,
        SUM(total_requests)                             AS total_requests,
        SUM(completed)                                  AS completed,
        SUM(unmet_demand)                               AS unmet_demand,
        SUM(rider_cancelled)                            AS rider_cancelled,
        ROUND(AVG(avg_wait_min)::NUMERIC, 1)            AS avg_wait_min,
        ROUND(AVG(avg_fare)::NUMERIC, 0)                AS avg_fare,
        ROUND(AVG(avg_surge)::NUMERIC, 2)               AS avg_surge,
        SUM(total_revenue)                              AS total_revenue,

        -- Fulfillment rate
        ROUND(
            SUM(completed) * 100.0
            / NULLIF(SUM(total_requests), 0)
        , 1)                                            AS fulfillment_rate_pct,

        -- Demand gap rate
        ROUND(
            SUM(unmet_demand) * 100.0
            / NULLIF(SUM(total_requests), 0)
        , 1)                                            AS demand_gap_rate_pct,

        -- Revenue lost to unmet demand
        ROUND((
            SUM(unmet_demand)
            * AVG(avg_fare)
        )::NUMERIC, 0)                                  AS revenue_lost_inr

    FROM hourly_demand
    GROUP BY hour, is_weekend
)

SELECT
    hour,
    CASE WHEN is_weekend THEN 'Weekend' ELSE 'Weekday' END  AS day_type,
    total_requests,
    completed,
    unmet_demand,
    rider_cancelled,
    fulfillment_rate_pct,
    demand_gap_rate_pct,
    avg_wait_min,
    avg_fare,
    avg_surge,
    total_revenue,
    revenue_lost_inr,

    -- Hour classification
    CASE
        WHEN hour BETWEEN 7  AND 10 THEN 'MORNING PEAK'
        WHEN hour BETWEEN 17 AND 21 THEN 'EVENING PEAK'
        WHEN hour BETWEEN 22 AND 23
          OR hour BETWEEN 0  AND 5  THEN 'LATE NIGHT'
        WHEN hour BETWEEN 11 AND 16 THEN 'MIDDAY'
        ELSE 'EARLY MORNING'
    END                                                     AS hour_category,

    -- Supply action needed
    CASE
        WHEN demand_gap_rate_pct >= 8
             AND avg_wait_min >= 12
             THEN 'CRITICAL — SURGE DRIVER DEPLOYMENT'
        WHEN demand_gap_rate_pct >= 5
             AND avg_wait_min >= 10
             THEN 'HIGH — INCREASE DRIVER SUPPLY'
        WHEN fulfillment_rate_pct >= 85
             AND avg_surge <= 1.05
             THEN 'OPTIMAL — MAINTAIN SUPPLY'
        WHEN fulfillment_rate_pct >= 80
             THEN 'GOOD — MINOR ADJUSTMENT NEEDED'
        ELSE 'MONITOR'
    END                                                     AS supply_action

FROM hourly_summary
ORDER BY
    is_weekend,
    demand_gap_rate_pct DESC,
    revenue_lost_inr DESC;