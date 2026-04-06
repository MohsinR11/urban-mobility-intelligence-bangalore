-- ============================================================
-- URBAN MOBILITY INTELLIGENCE SYSTEM
-- Query 08: Weather Impact on Mobility Demand (Fixed)
-- Purpose : Quantify rain and temperature effect on
--           ride volume, surge, and revenue
-- ============================================================

WITH weather_rides AS (
    SELECT
        r.weather_condition,
        r.is_raining,
        CASE
            WHEN r.rainfall_mm = 0                THEN 'none'
            WHEN r.rainfall_mm BETWEEN 0.1 AND 5  THEN 'light'
            WHEN r.rainfall_mm BETWEEN 5.1 AND 40 THEN 'moderate'
            ELSE                                       'heavy'
        END                                              AS rain_intensity,
        CASE
            WHEN r.temperature_c < 20              THEN 'Cool (<20C)'
            WHEN r.temperature_c BETWEEN 20 AND 25 THEN 'Mild (20-25C)'
            WHEN r.temperature_c BETWEEN 25 AND 30 THEN 'Warm (25-30C)'
            ELSE                                        'Hot (>30C)'
        END                                              AS temp_band,
        COUNT(*)                                         AS total_rides,
        COUNT(CASE WHEN r.status = 'completed'
                   THEN 1 END)                           AS completed,
        COUNT(CASE WHEN r.status = 'no_driver_found'
                   THEN 1 END)                           AS unmet,
        ROUND(AVG(r.surge_multiplier)::NUMERIC, 2)       AS avg_surge,
        ROUND(AVG(r.wait_time_min)::NUMERIC, 1)          AS avg_wait,
        ROUND(AVG(r.fare_amount)
            FILTER (WHERE r.status = 'completed')
            ::NUMERIC, 0)                                AS avg_fare,
        ROUND(SUM(r.fare_amount)
            FILTER (WHERE r.status = 'completed')
            ::NUMERIC, 0)                                AS total_revenue,
        ROUND(AVG(r.distance_km)::NUMERIC, 1)            AS avg_distance
    FROM rides r
    GROUP BY
        r.weather_condition,
        r.is_raining,
        CASE
            WHEN r.rainfall_mm = 0                THEN 'none'
            WHEN r.rainfall_mm BETWEEN 0.1 AND 5  THEN 'light'
            WHEN r.rainfall_mm BETWEEN 5.1 AND 40 THEN 'moderate'
            ELSE                                       'heavy'
        END,
        CASE
            WHEN r.temperature_c < 20              THEN 'Cool (<20C)'
            WHEN r.temperature_c BETWEEN 20 AND 25 THEN 'Mild (20-25C)'
            WHEN r.temperature_c BETWEEN 25 AND 30 THEN 'Warm (25-30C)'
            ELSE                                        'Hot (>30C)'
        END
),

baseline_clear AS (
    SELECT
        ROUND(AVG(fare_amount)
            FILTER (WHERE status = 'completed')
            ::NUMERIC, 0)                                AS clear_avg_fare,
        ROUND(AVG(wait_time_min)::NUMERIC, 1)            AS clear_avg_wait,
        COUNT(*)                                         AS clear_total_rides
    FROM rides
    WHERE weather_condition = 'clear'
)

SELECT
    wr.weather_condition,
    wr.rain_intensity,
    wr.is_raining,
    wr.temp_band,
    wr.total_rides,
    wr.completed,
    wr.unmet,
    ROUND(wr.completed * 100.0
        / NULLIF(wr.total_rides, 0), 1)                  AS completion_pct,
    wr.avg_surge,
    wr.avg_wait,
    wr.avg_fare,
    wr.total_revenue,
    wr.avg_distance,
    bc.clear_avg_fare                                    AS baseline_fare,
    bc.clear_avg_wait                                    AS baseline_wait,

    ROUND((wr.avg_fare - bc.clear_avg_fare)
        ::NUMERIC, 0)                                    AS fare_premium_inr,
    ROUND((wr.avg_fare - bc.clear_avg_fare)
        * 100.0 / NULLIF(bc.clear_avg_fare, 0)
        ::NUMERIC, 1)                                    AS fare_premium_pct,

    ROUND((wr.avg_wait - bc.clear_avg_wait)
        ::NUMERIC, 1)                                    AS wait_increase_min,

    ROUND(wr.total_rides * 100.0
        / NULLIF(bc.clear_total_rides, 0)
        ::NUMERIC, 1)                                    AS demand_index

FROM weather_rides wr
CROSS JOIN baseline_clear bc
ORDER BY
    wr.is_raining DESC,
    wr.avg_surge DESC;