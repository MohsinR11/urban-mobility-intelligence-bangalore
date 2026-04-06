-- ============================================================
-- URBAN MOBILITY INTELLIGENCE SYSTEM
-- Query 01: Dead Zone Detection (Calibrated + Type Fixed)
-- ============================================================

WITH peak_hour_rides AS (
    SELECT
        pickup_zone_id,
        pickup_zone_name,
        pickup_zone_type,
        pickup_h3_index,
        COUNT(*)                                      AS total_rides,
        COUNT(CASE WHEN status = 'completed'
                   THEN 1 END)                        AS completed_rides,
        COUNT(CASE WHEN status = 'no_driver_found'
                   THEN 1 END)                        AS no_driver_rides,
        ROUND(AVG(wait_time_min)::NUMERIC, 1)         AS avg_wait_time,
        ROUND(AVG(fare_amount)
            FILTER (WHERE status = 'completed')
            ::NUMERIC, 0)                             AS avg_fare
    FROM rides
    WHERE hour IN (8,9,10,17,18,19,20)
    GROUP BY
        pickup_zone_id,
        pickup_zone_name,
        pickup_zone_type,
        pickup_h3_index
),

driver_presence AS (
    SELECT
        current_zone_id                              AS zone_id,
        COUNT(*)                                     AS drivers_in_zone,
        COUNT(CASE WHEN is_ev = TRUE THEN 1 END)     AS ev_drivers_in_zone,
        ROUND(AVG(rating)::NUMERIC, 2)               AS avg_driver_rating
    FROM drivers
    WHERE status = 'active'
    GROUP BY current_zone_id
),

zone_efficiency AS (
    SELECT
        p.pickup_zone_id,
        p.pickup_zone_name,
        p.pickup_zone_type,
        p.pickup_h3_index,
        p.total_rides,
        p.completed_rides,
        p.no_driver_rides,
        p.avg_wait_time,
        p.avg_fare,
        COALESCE(d.drivers_in_zone, 0)               AS drivers_in_zone,
        COALESCE(d.ev_drivers_in_zone, 0)            AS ev_drivers_in_zone,
        COALESCE(d.avg_driver_rating, 0)             AS avg_driver_rating,

        ROUND(
            p.completed_rides * 100.0
            / NULLIF(p.total_rides, 0)
        , 1)                                         AS completion_rate_pct,

        ROUND(
            p.total_rides * 1.0
            / NULLIF(d.drivers_in_zone, 0)
        , 2)                                         AS rides_per_driver,

        -- Idle pressure: more drivers vs fewer rides = more idle
        ROUND((
            COALESCE(d.drivers_in_zone, 0) * 1.0
            / NULLIF(p.total_rides, 0) * 100
        )::NUMERIC, 2)                               AS idle_pressure_score,

        -- Demand gap: unmet demand signals
        ROUND((
            (p.no_driver_rides * 1.0
            / NULLIF(p.total_rides, 0) * 100)
            + (p.avg_wait_time - 8)
        )::NUMERIC, 2)                               AS demand_gap_score

    FROM peak_hour_rides p
    LEFT JOIN driver_presence d
        ON p.pickup_zone_id = d.zone_id
),

percentiles AS (
    SELECT
        PERCENTILE_CONT(0.75) WITHIN GROUP
            (ORDER BY idle_pressure_score)           AS p75_idle,
        PERCENTILE_CONT(0.90) WITHIN GROUP
            (ORDER BY idle_pressure_score)           AS p90_idle,
        PERCENTILE_CONT(0.75) WITHIN GROUP
            (ORDER BY demand_gap_score)              AS p75_gap,
        PERCENTILE_CONT(0.90) WITHIN GROUP
            (ORDER BY demand_gap_score)              AS p90_gap,
        PERCENTILE_CONT(0.25) WITHIN GROUP
            (ORDER BY rides_per_driver)              AS p25_rpd,
        PERCENTILE_CONT(0.10) WITHIN GROUP
            (ORDER BY rides_per_driver)              AS p10_rpd
    FROM zone_efficiency
    WHERE drivers_in_zone > 0
)

SELECT
    z.pickup_zone_id                                 AS zone_id,
    z.pickup_zone_name                               AS zone_name,
    z.pickup_zone_type                               AS zone_type,
    z.total_rides,
    z.completed_rides,
    z.no_driver_rides,
    z.drivers_in_zone,
    z.ev_drivers_in_zone,
    z.completion_rate_pct,
    z.avg_wait_time,
    z.avg_fare,
    z.rides_per_driver,
    z.idle_pressure_score,
    z.demand_gap_score,

    CASE
        WHEN z.idle_pressure_score >= p.p90_idle
             AND z.rides_per_driver <= p.p10_rpd
             THEN 'CRITICAL DEAD ZONE'
        WHEN z.idle_pressure_score >= p.p75_idle
             AND z.rides_per_driver <= p.p25_rpd
             THEN 'HIGH IDLE ZONE'
        WHEN z.demand_gap_score    >= p.p90_gap
             AND z.rides_per_driver >= 2.5
             THEN 'CRITICAL DEMAND GAP'
        WHEN z.demand_gap_score    >= p.p75_gap
             AND z.rides_per_driver >= 2.0
             THEN 'HIGH DEMAND GAP'
        WHEN z.rides_per_driver    >= 3.0
             THEN 'HIGH EFFICIENCY ZONE'
        ELSE 'BALANCED ZONE'
    END                                              AS zone_classification,

    CASE
        WHEN z.idle_pressure_score >= p.p90_idle
             AND z.rides_per_driver <= p.p10_rpd
             THEN 'MOVE DRIVERS OUT IMMEDIATELY'
        WHEN z.idle_pressure_score >= p.p75_idle
             AND z.rides_per_driver <= p.p25_rpd
             THEN 'REDUCE DRIVER ALLOCATION'
        WHEN z.demand_gap_score    >= p.p90_gap
             THEN 'SEND DRIVERS HERE IMMEDIATELY'
        WHEN z.demand_gap_score    >= p.p75_gap
             THEN 'INCREASE DRIVER ALLOCATION'
        ELSE 'MAINTAIN CURRENT ALLOCATION'
    END                                              AS recommended_action,

    -- Estimated daily revenue loss from idle drivers
    ROUND((
        z.drivers_in_zone
        * GREATEST(0.0, (p.p25_rpd - z.rides_per_driver))
        * z.avg_fare::FLOAT
    )::NUMERIC, 0)                                   AS est_daily_revenue_loss_inr,

    ROUND(p.p90_idle::NUMERIC, 2)                    AS threshold_critical_idle,
    ROUND(p.p75_idle::NUMERIC, 2)                    AS threshold_high_idle,
    ROUND(p.p10_rpd::NUMERIC,  2)                    AS threshold_low_rpd

FROM zone_efficiency z
CROSS JOIN percentiles p
WHERE z.drivers_in_zone > 0
ORDER BY
    CASE
        WHEN z.idle_pressure_score >= p.p90_idle
             AND z.rides_per_driver <= p.p10_rpd
             THEN 1
        WHEN z.idle_pressure_score >= p.p75_idle
             AND z.rides_per_driver <= p.p25_rpd
             THEN 2
        WHEN z.demand_gap_score    >= p.p90_gap
             AND z.rides_per_driver >= 2.5
             THEN 3
        WHEN z.demand_gap_score    >= p.p75_gap
             AND z.rides_per_driver >= 2.0
             THEN 4
        ELSE 5
    END,
    z.idle_pressure_score DESC;