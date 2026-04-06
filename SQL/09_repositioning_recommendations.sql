-- ============================================================
-- Query 09: Fleet Repositioning Recommendations
-- Purpose : Generate actionable driver movement instructions
--           from dead zones to demand gap zones
-- ============================================================

WITH zone_status AS (
    SELECT
        pickup_zone_id                                   AS zone_id,
        pickup_zone_name                                 AS zone_name,
        pickup_zone_type                                 AS zone_type,
        COUNT(*)                                         AS total_rides,
        COUNT(CASE WHEN status = 'no_driver_found'
                   THEN 1 END)                           AS unmet_rides,
        ROUND(AVG(wait_time_min)::NUMERIC, 1)            AS avg_wait,
        ROUND(SUM(fare_amount)
            FILTER (WHERE status = 'completed')
            ::NUMERIC, 0)                                AS zone_revenue
    FROM rides
    WHERE hour IN (7,8,9,10,17,18,19,20)
    GROUP BY
        pickup_zone_id,
        pickup_zone_name,
        pickup_zone_type
),

driver_counts AS (
    SELECT
        current_zone_id                                  AS zone_id,
        COUNT(*)                                         AS drivers_available,
        COUNT(CASE WHEN is_ev = TRUE
                   THEN 1 END)                           AS ev_drivers
    FROM drivers
    WHERE status = 'active'
    GROUP BY current_zone_id
),

zone_combined AS (
    SELECT
        z.zone_id,
        z.zone_name,
        z.zone_type,
        z.total_rides,
        z.unmet_rides,
        z.avg_wait,
        z.zone_revenue,
        COALESCE(d.drivers_available, 0)                 AS drivers_available,
        COALESCE(d.ev_drivers, 0)                        AS ev_drivers,
        ROUND(z.total_rides * 1.0
            / NULLIF(d.drivers_available, 0), 2)         AS rides_per_driver,
        ROUND(z.unmet_rides * 100.0
            / NULLIF(z.total_rides, 0), 1)               AS unmet_pct
    FROM zone_status z
    LEFT JOIN driver_counts d ON z.zone_id = d.zone_id
),

city_medians AS (
    SELECT
        PERCENTILE_CONT(0.5) WITHIN GROUP
            (ORDER BY rides_per_driver)                  AS median_rpd,
        PERCENTILE_CONT(0.75) WITHIN GROUP
            (ORDER BY unmet_pct)                         AS p75_unmet,
        PERCENTILE_CONT(0.25) WITHIN GROUP
            (ORDER BY rides_per_driver)                  AS p25_rpd
    FROM zone_combined
    WHERE drivers_available > 0
),

supply_zones AS (
    SELECT
        zc.*,
        'SUPPLY_SURPLUS' AS zone_role,
        GREATEST(0, zc.drivers_available - 8)            AS excess_drivers
    FROM zone_combined zc
    CROSS JOIN city_medians cm
    WHERE zc.rides_per_driver <= cm.p25_rpd
      AND zc.drivers_available >= 8
),

demand_zones AS (
    SELECT
        zc.*,
        'DEMAND_SHORTAGE' AS zone_role,
        LEAST(15, GREATEST(2,
            CEIL(zc.unmet_rides * 1.0 / 10)
        ))::INTEGER                                      AS drivers_needed
    FROM zone_combined zc
    CROSS JOIN city_medians cm
    WHERE zc.unmet_pct >= cm.p75_unmet
       OR (zc.avg_wait >= 13
           AND zc.rides_per_driver >= cm.median_rpd)
)

-- Final repositioning plan
SELECT
    s.zone_id                                            AS from_zone_id,
    s.zone_name                                          AS from_zone_name,
    s.zone_type                                          AS from_zone_type,
    s.drivers_available                                  AS from_drivers,
    s.rides_per_driver                                   AS from_rides_per_driver,
    s.excess_drivers                                     AS drivers_to_move,
    d.zone_id                                            AS to_zone_id,
    d.zone_name                                          AS to_zone_name,
    d.zone_type                                          AS to_zone_type,
    d.unmet_rides                                        AS to_unmet_rides,
    d.unmet_pct                                          AS to_unmet_pct,
    d.avg_wait                                           AS to_avg_wait,
    d.drivers_needed,
    d.zone_revenue                                       AS destination_revenue,

    -- Priority score for this reposition
    ROUND((d.unmet_pct * 0.4
         + d.avg_wait  * 0.3
         + (d.zone_revenue / 10000.0) * 0.3)
         ::NUMERIC, 2)                                   AS reposition_priority_score,

    -- Estimated revenue gain from repositioning
    ROUND((
        LEAST(s.excess_drivers, d.drivers_needed)
        * (d.zone_revenue / NULLIF(d.drivers_available, 1))
    )::NUMERIC, 0)                                       AS est_revenue_gain_inr,

    CURRENT_TIMESTAMP                                    AS recommendation_generated_at

FROM supply_zones s
CROSS JOIN demand_zones d
WHERE s.zone_id <> d.zone_id
  AND s.excess_drivers > 0
ORDER BY
    reposition_priority_score DESC,
    est_revenue_gain_inr DESC
LIMIT 30;