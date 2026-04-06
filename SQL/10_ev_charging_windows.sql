-- ============================================================
-- Query 10: EV Fleet Charging Window Optimizer
-- Purpose : Find optimal charging windows for EV drivers
--           that minimize peak-hour service disruption
-- ============================================================

WITH hourly_ev_demand AS (
    SELECT
        hour,
        day_of_week,
        is_weekend,
        COUNT(*)                                         AS total_rides,
        COUNT(CASE WHEN vehicle_type IN ('EV Bike','EV Auto')
                   THEN 1 END)                           AS ev_rides,
        ROUND(COUNT(CASE WHEN vehicle_type IN
                ('EV Bike','EV Auto') THEN 1 END)
            * 100.0 / NULLIF(COUNT(*), 0), 1)            AS ev_share_pct,
        ROUND(AVG(surge_multiplier)::NUMERIC, 2)         AS avg_surge,
        ROUND(SUM(fare_amount)
            FILTER (WHERE status = 'completed'
                AND vehicle_type IN ('EV Bike','EV Auto'))
            ::NUMERIC, 0)                                AS ev_revenue
    FROM rides
    GROUP BY hour, day_of_week, is_weekend
),

hourly_summary AS (
    SELECT
        hour,
        is_weekend,
        ROUND(AVG(total_rides)::NUMERIC, 0)              AS avg_hourly_rides,
        ROUND(AVG(ev_rides)::NUMERIC, 0)                 AS avg_ev_rides,
        ROUND(AVG(ev_share_pct)::NUMERIC, 1)             AS avg_ev_share,
        ROUND(AVG(avg_surge)::NUMERIC, 2)                AS avg_surge,
        ROUND(AVG(ev_revenue)::NUMERIC, 0)               AS avg_ev_revenue
    FROM hourly_ev_demand
    GROUP BY hour, is_weekend
),

demand_bands AS (
    SELECT
        *,
        NTILE(4) OVER (
            PARTITION BY is_weekend
            ORDER BY avg_hourly_rides
        )                                                AS demand_quartile
    FROM hourly_summary
)

SELECT
    hour,
    CASE WHEN is_weekend THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    avg_hourly_rides,
    avg_ev_rides,
    avg_ev_share,
    avg_surge,
    avg_ev_revenue,
    demand_quartile,

    -- Charging window classification
    CASE
        WHEN demand_quartile = 1
             THEN 'OPTIMAL CHARGING WINDOW'
        WHEN demand_quartile = 2
             THEN 'ACCEPTABLE CHARGING WINDOW'
        WHEN demand_quartile = 3
             THEN 'AVOID IF POSSIBLE'
        ELSE 'DO NOT CHARGE — PEAK DEMAND'
    END                                                  AS charging_recommendation,

    -- How many EVs can safely charge this hour
    -- Assume 30% of EVs can charge without service impact
    ROUND(avg_ev_rides * 0.30)::INTEGER                  AS safe_ev_charge_count,

    -- Revenue risk if EVs pulled for charging
    ROUND(avg_ev_revenue * 0.30)::INTEGER                AS revenue_at_risk_inr,

    -- Best charging hours flag
    CASE
        WHEN demand_quartile = 1
             AND hour BETWEEN 1 AND 6
             THEN TRUE
        ELSE FALSE
    END                                                  AS is_best_charging_hour

FROM demand_bands
ORDER BY
    is_weekend,
    demand_quartile,
    hour;