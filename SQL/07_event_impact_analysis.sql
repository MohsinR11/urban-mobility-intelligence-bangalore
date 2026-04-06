-- ============================================================
-- Query 07: Event Impact on Ride Demand Analysis
-- Purpose : Quantify how each event type affects demand,
--           revenue, and surge pricing
-- ============================================================

WITH event_rides AS (
    SELECT
        r.active_event_id,
        r.active_event_type,
        e.event_name,
        e.event_date,
        e.venue_zone_name,
        e.expected_attendance,
        e.demand_multiplier                              AS planned_multiplier,
        COUNT(*)                                         AS total_rides,
        COUNT(CASE WHEN r.status = 'completed'
                   THEN 1 END)                           AS completed,
        COUNT(CASE WHEN r.status = 'no_driver_found'
                   THEN 1 END)                           AS unmet_demand,
        ROUND(AVG(r.surge_multiplier)::NUMERIC, 2)       AS actual_surge,
        ROUND(AVG(r.wait_time_min)::NUMERIC, 1)          AS avg_wait,
        ROUND(AVG(r.fare_amount)
            FILTER (WHERE r.status = 'completed')
            ::NUMERIC, 0)                                AS avg_fare,
        ROUND(SUM(r.fare_amount)
            FILTER (WHERE r.status = 'completed')
            ::NUMERIC, 0)                                AS event_revenue
    FROM rides r
    JOIN events e ON r.active_event_id = e.event_id
    WHERE r.active_event_id IS NOT NULL
    GROUP BY
        r.active_event_id,
        r.active_event_type,
        e.event_name,
        e.event_date,
        e.venue_zone_name,
        e.expected_attendance,
        e.demand_multiplier
),

baseline AS (
    SELECT
        ROUND(AVG(fare_amount)
            FILTER (WHERE status = 'completed')
            ::NUMERIC, 0)                                AS baseline_fare,
        ROUND(AVG(wait_time_min)::NUMERIC, 1)            AS baseline_wait,
        ROUND(COUNT(*) * 1.0 / 365, 0)                  AS avg_daily_rides
    FROM rides
    WHERE active_event_id IS NULL
)

SELECT
    er.active_event_id                                   AS event_id,
    er.event_name,
    er.event_date,
    er.active_event_type                                 AS event_type,
    er.venue_zone_name,
    er.expected_attendance,
    er.planned_multiplier,
    er.total_rides,
    er.completed,
    er.unmet_demand,
    er.actual_surge,
    er.avg_wait,
    er.avg_fare,
    er.event_revenue,
    b.baseline_fare,
    b.baseline_wait,

    -- Fare lift vs non-event baseline
    ROUND((er.avg_fare - b.baseline_fare)::NUMERIC, 0)   AS fare_lift_inr,
    ROUND((er.avg_fare - b.baseline_fare)
        * 100.0 / NULLIF(b.baseline_fare, 0)
        ::NUMERIC, 1)                                    AS fare_lift_pct,

    -- Wait time delta
    ROUND((er.avg_wait - b.baseline_wait)::NUMERIC, 1)   AS wait_delta_min,

    -- Completion rate
    ROUND(er.completed * 100.0
        / NULLIF(er.total_rides, 0), 1)                  AS completion_pct,

    -- Surge accuracy: planned vs actual
    ROUND((er.actual_surge
        - er.planned_multiplier)::NUMERIC, 2)            AS surge_accuracy_delta,

    -- Revenue per attendee
    ROUND(er.event_revenue
        / NULLIF(er.expected_attendance, 0)
        ::NUMERIC, 2)                                    AS revenue_per_attendee

FROM event_rides er
CROSS JOIN baseline b
ORDER BY er.event_revenue DESC;