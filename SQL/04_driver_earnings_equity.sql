-- ============================================================
-- URBAN MOBILITY INTELLIGENCE SYSTEM
-- Query 03: Driver Earnings Equity Analysis
-- ============================================================

WITH driver_ride_stats AS (
    SELECT
        r.driver_id,
        r.pickup_zone_id,
        r.pickup_zone_name,
        r.pickup_zone_type,
        COUNT(*)                                         AS total_rides,
        COUNT(CASE WHEN r.status = 'completed'
                   THEN 1 END)                           AS completed_rides,
        ROUND(SUM(r.fare_amount)
            FILTER (WHERE r.status = 'completed')
            ::NUMERIC, 0)                                AS total_earnings,
        ROUND(AVG(r.fare_amount)
            FILTER (WHERE r.status = 'completed')
            ::NUMERIC, 0)                                AS avg_fare_per_ride,
        ROUND(AVG(r.wait_time_min)::NUMERIC, 1)          AS avg_wait_time,
        ROUND(AVG(r.surge_multiplier)::NUMERIC, 2)       AS avg_surge,
        COUNT(CASE WHEN r.status = 'cancelled_by_driver'
                   THEN 1 END)                           AS driver_cancellations,
        d.vehicle_type,
        d.is_ev,
        d.rating                                         AS driver_rating,
        d.experience_months,
        d.preferred_shift,
        d.avg_daily_earnings                             AS expected_daily_earnings
    FROM rides r
    JOIN drivers d ON r.driver_id = d.driver_id
    GROUP BY
        r.driver_id,
        r.pickup_zone_id,
        r.pickup_zone_name,
        r.pickup_zone_type,
        d.vehicle_type,
        d.is_ev,
        d.rating,
        d.experience_months,
        d.preferred_shift,
        d.avg_daily_earnings
),

zone_earnings_summary AS (
    SELECT
        pickup_zone_id                                   AS zone_id,
        pickup_zone_name                                 AS zone_name,
        pickup_zone_type                                 AS zone_type,
        COUNT(DISTINCT driver_id)                        AS unique_drivers,
        SUM(total_rides)                                 AS total_rides,
        SUM(completed_rides)                             AS total_completed,
        ROUND(AVG(total_earnings)::NUMERIC, 0)           AS avg_driver_earnings,
        ROUND(MIN(total_earnings)::NUMERIC, 0)           AS min_driver_earnings,
        ROUND(MAX(total_earnings)::NUMERIC, 0)           AS max_driver_earnings,
        ROUND(AVG(avg_fare_per_ride)::NUMERIC, 0)        AS avg_fare,
        ROUND(AVG(avg_wait_time)::NUMERIC, 1)            AS avg_wait_time,
        ROUND(AVG(avg_surge)::NUMERIC, 2)                AS avg_surge,
        SUM(driver_cancellations)                        AS total_cancellations,
        ROUND(
            SUM(driver_cancellations) * 100.0
            / NULLIF(SUM(total_rides), 0)
        , 1)                                             AS cancellation_rate_pct,
        ROUND(AVG(driver_rating)::NUMERIC, 2)            AS avg_driver_rating,
        ROUND(AVG(completed_rides * 1.0
            / NULLIF(total_rides, 0) * 100)
            ::NUMERIC, 1)                                AS avg_completion_rate
    FROM driver_ride_stats
    GROUP BY
        pickup_zone_id,
        pickup_zone_name,
        pickup_zone_type
),

benchmark AS (
    SELECT
        ROUND(AVG(avg_driver_earnings)::NUMERIC, 0)      AS city_avg_earnings,
        ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP
            (ORDER BY avg_driver_earnings)
            ::NUMERIC, 0)                                AS p25_earnings,
        ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP
            (ORDER BY avg_driver_earnings)
            ::NUMERIC, 0)                                AS p75_earnings,
        ROUND(PERCENTILE_CONT(0.10) WITHIN GROUP
            (ORDER BY avg_driver_earnings)
            ::NUMERIC, 0)                                AS p10_earnings
    FROM zone_earnings_summary
),

final AS (
    SELECT
        z.zone_id,
        z.zone_name,
        z.zone_type,
        z.unique_drivers,
        z.total_rides,
        z.total_completed,
        z.avg_driver_earnings,
        z.min_driver_earnings,
        z.max_driver_earnings,
        z.avg_fare,
        z.avg_wait_time,
        z.avg_surge,
        z.cancellation_rate_pct,
        z.avg_driver_rating,
        z.avg_completion_rate,
        b.city_avg_earnings,
        b.p25_earnings,
        b.p75_earnings,

        ROUND((z.avg_driver_earnings - b.city_avg_earnings)
            ::NUMERIC, 0)                                AS earnings_vs_city_avg,

        ROUND((
            (z.avg_driver_earnings - b.city_avg_earnings)
            * 100.0 / NULLIF(b.city_avg_earnings, 0)
        )::NUMERIC, 1)                                   AS earnings_gap_pct,

        CASE
            WHEN z.avg_driver_earnings <= b.p10_earnings
                 THEN 'CRITICAL UNDERPAID ZONE'
            WHEN z.avg_driver_earnings <= b.p25_earnings
                 THEN 'UNDERPAID ZONE'
            WHEN z.avg_driver_earnings >= b.p75_earnings
                 THEN 'HIGH EARNING ZONE'
            ELSE 'FAIR EARNING ZONE'
        END                                              AS earnings_equity_class,

        CASE
            WHEN z.avg_driver_earnings <= b.p10_earnings
                 AND z.cancellation_rate_pct >= 7
                 THEN 'CRITICAL RETENTION RISK'
            WHEN z.avg_driver_earnings <= b.p25_earnings
                 THEN 'HIGH RETENTION RISK'
            WHEN z.avg_driver_earnings >= b.p75_earnings
                 THEN 'LOW RETENTION RISK'
            ELSE 'MODERATE RETENTION RISK'
        END                                              AS retention_risk,

        ROUND(
            GREATEST(0, b.city_avg_earnings - z.avg_driver_earnings)
            ::NUMERIC, 0)                                AS monthly_earnings_shortfall,

        ROUND((
            z.unique_drivers
            * GREATEST(0, b.city_avg_earnings - z.avg_driver_earnings)
        )::NUMERIC, 0)                                   AS zone_total_shortfall_inr

    FROM zone_earnings_summary z
    CROSS JOIN benchmark b
)

-- ── Final SELECT wraps alias so ORDER BY can reference it ───
SELECT *
FROM final
ORDER BY
    CASE earnings_equity_class
        WHEN 'CRITICAL UNDERPAID ZONE' THEN 1
        WHEN 'UNDERPAID ZONE'          THEN 2
        WHEN 'FAIR EARNING ZONE'       THEN 3
        WHEN 'HIGH EARNING ZONE'       THEN 4
    END,
    avg_driver_earnings ASC;