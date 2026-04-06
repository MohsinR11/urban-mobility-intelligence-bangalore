-- ============================================================
-- Query 12: Executive Summary View
-- Purpose : Single-page C-suite summary of entire
--           fleet intelligence system
-- ============================================================

WITH summary AS (
    SELECT
        COUNT(*)                                         AS total_rides,
        COUNT(CASE WHEN status = 'completed'
                   THEN 1 END)                           AS completed_rides,
        COUNT(CASE WHEN status = 'no_driver_found'
                   THEN 1 END)                           AS unmet_rides,
        COUNT(CASE WHEN status LIKE 'cancelled%'
                   THEN 1 END)                           AS cancelled_rides,
        ROUND(SUM(fare_amount)
            FILTER (WHERE status = 'completed')
            ::NUMERIC, 0)                                AS total_revenue,
        ROUND(AVG(fare_amount)
            FILTER (WHERE status = 'completed')
            ::NUMERIC, 0)                                AS avg_fare,
        ROUND(AVG(wait_time_min)::NUMERIC, 1)            AS avg_wait,
        ROUND(AVG(surge_multiplier)::NUMERIC, 2)         AS avg_surge,
        COUNT(DISTINCT driver_id)                        AS unique_drivers,
        COUNT(DISTINCT pickup_zone_id)                   AS zones_served,
        COUNT(CASE WHEN is_raining = TRUE
                   THEN 1 END)                           AS rainy_rides,
        COUNT(CASE WHEN active_event_id IS NOT NULL
                   THEN 1 END)                           AS event_rides,
        COUNT(CASE WHEN vehicle_type IN
                ('EV Bike','EV Auto') THEN 1 END)        AS ev_rides
    FROM rides
),

dead_zone_count AS (
    SELECT COUNT(DISTINCT pickup_zone_id)                AS dead_zones
    FROM rides
    WHERE hour IN (8,9,10,17,18,19,20)
    GROUP BY pickup_zone_id
    HAVING COUNT(*) * 1.0
        / NULLIF(COUNT(DISTINCT
            CASE WHEN status = 'completed'
                 THEN ride_id END), 0) < 1.3
),

top_zone AS (
    SELECT pickup_zone_name, SUM(fare_amount) AS rev
    FROM rides
    WHERE status = 'completed'
    GROUP BY pickup_zone_name
    ORDER BY rev DESC
    LIMIT 1
),

worst_zone AS (
    SELECT pickup_zone_name,
           COUNT(CASE WHEN status = 'no_driver_found'
                      THEN 1 END) * 100.0
           / COUNT(*) AS unmet_pct
    FROM rides
    GROUP BY pickup_zone_name
    ORDER BY unmet_pct DESC
    LIMIT 1
),

peak_hour AS (
    SELECT hour, COUNT(*) AS cnt
    FROM rides
    GROUP BY hour
    ORDER BY cnt DESC
    LIMIT 1
)

SELECT
    '=== URBAN MOBILITY INTELLIGENCE — EXECUTIVE SUMMARY ==='
                                                         AS report_title,
    CURRENT_DATE                                         AS report_date,
    '--- FLEET OVERVIEW ---'                             AS section_1,
    s.total_rides,
    s.unique_drivers,
    s.zones_served,
    s.ev_rides,
    ROUND(s.ev_rides * 100.0
        / NULLIF(s.total_rides, 0), 1)                   AS ev_share_pct,
    '--- DEMAND & SERVICE ---'                           AS section_2,
    s.completed_rides,
    s.unmet_rides,
    s.cancelled_rides,
    ROUND(s.completed_rides * 100.0
        / NULLIF(s.total_rides, 0), 1)                   AS completion_rate_pct,
    ROUND(s.unmet_rides * 100.0
        / NULLIF(s.total_rides, 0), 1)                   AS unmet_rate_pct,
    s.avg_wait                                           AS avg_wait_min,
    '--- REVENUE ---'                                    AS section_3,
    s.total_revenue,
    s.avg_fare,
    s.avg_surge,
    s.event_rides,
    s.rainy_rides,
    '--- KEY ZONES ---'                                  AS section_4,
    tz.pickup_zone_name                                  AS top_revenue_zone,
    ROUND(tz.rev::NUMERIC, 0)                            AS top_zone_revenue,
    wz.pickup_zone_name                                  AS highest_unmet_zone,
    ROUND(wz.unmet_pct::NUMERIC, 1)                      AS highest_unmet_pct,
    ph.hour                                              AS peak_demand_hour

FROM summary s
CROSS JOIN top_zone tz
CROSS JOIN worst_zone wz
CROSS JOIN peak_hour ph;