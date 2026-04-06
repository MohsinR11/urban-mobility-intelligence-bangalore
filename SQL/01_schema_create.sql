-- ============================================================
-- URBAN MOBILITY INTELLIGENCE SYSTEM
-- Script 01: Database Schema — Tables & Indexes
-- Run this first before any analysis queries
-- ============================================================

-- ── 1. ZONES TABLE ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS zones (
    zone_id         VARCHAR(10)  PRIMARY KEY,
    zone_name       VARCHAR(100) NOT NULL,
    latitude        DECIMAL(9,6) NOT NULL,
    longitude       DECIMAL(9,6) NOT NULL,
    h3_index        VARCHAR(20)  NOT NULL,
    h3_resolution   INTEGER      NOT NULL,
    zone_type       VARCHAR(30)  NOT NULL,
    demand_weight   DECIMAL(4,2) NOT NULL,
    peak_hours      VARCHAR(50),
    city            VARCHAR(50)  NOT NULL,
    is_active       BOOLEAN      DEFAULT TRUE,
    created_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ── 2. DRIVERS TABLE ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS drivers (
    driver_id            VARCHAR(10)  PRIMARY KEY,
    vehicle_type         VARCHAR(20)  NOT NULL,
    is_ev                BOOLEAN      NOT NULL,
    status               VARCHAR(20)  NOT NULL,
    rating               DECIMAL(3,1),
    experience_months    INTEGER,
    home_zone_id         VARCHAR(10)  REFERENCES zones(zone_id),
    current_zone_id      VARCHAR(10)  REFERENCES zones(zone_id),
    daily_trip_target    INTEGER,
    battery_capacity_kwh DECIMAL(4,1),
    avg_daily_earnings   INTEGER,
    preferred_shift      VARCHAR(20),
    join_date            DATE,
    city                 VARCHAR(50),
    created_at           TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ── 3. WEATHER TABLE ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS weather (
    weather_id         SERIAL       PRIMARY KEY,
    timestamp          TIMESTAMP    NOT NULL,
    date               DATE         NOT NULL,
    hour               INTEGER      NOT NULL,
    month              INTEGER      NOT NULL,
    temperature_c      DECIMAL(5,1),
    humidity_pct       INTEGER,
    wind_speed_kmh     DECIMAL(5,1),
    rainfall_mm        DECIMAL(6,1),
    is_raining         BOOLEAN,
    rain_intensity     VARCHAR(20),
    visibility_km      DECIMAL(5,1),
    condition          VARCHAR(30),
    demand_multiplier  DECIMAL(4,2),
    city               VARCHAR(50),
    created_at         TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ── 4. EVENTS TABLE ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS events (
    event_id               VARCHAR(10)  PRIMARY KEY,
    event_name             VARCHAR(150) NOT NULL,
    event_date             DATE         NOT NULL,
    day_of_week            VARCHAR(15),
    is_weekend             BOOLEAN,
    month                  INTEGER,
    venue_zone_id          VARCHAR(10)  REFERENCES zones(zone_id),
    venue_zone_name        VARCHAR(100),
    venue_lat              DECIMAL(9,6),
    venue_lng              DECIMAL(9,6),
    venue_h3_index         VARCHAR(20),
    event_type             VARCHAR(30),
    expected_attendance    INTEGER,
    demand_multiplier      DECIMAL(4,2),
    affected_radius_km     DECIMAL(5,1),
    duration_hours         INTEGER,
    start_hour             INTEGER,
    city                   VARCHAR(50),
    created_at             TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ── 5. CHARGING STATIONS TABLE ─────────────────────────────
CREATE TABLE IF NOT EXISTS charging_stations (
    station_id           VARCHAR(10)  PRIMARY KEY,
    network              VARCHAR(50)  NOT NULL,
    zone_id              VARCHAR(10)  REFERENCES zones(zone_id),
    zone_name            VARCHAR(100),
    zone_type            VARCHAR(30),
    latitude             DECIMAL(9,6),
    longitude            DECIMAL(9,6),
    h3_index             VARCHAR(20),
    charger_type         VARCHAR(20),
    total_ports          INTEGER,
    power_kw             DECIMAL(6,1),
    cost_per_kwh         DECIMAL(5,1),
    operating_hours      VARCHAR(20),
    is_24hr              BOOLEAN,
    avg_utilization      DECIMAL(4,2),
    monthly_revenue_inr  INTEGER,
    install_year         INTEGER,
    is_operational       BOOLEAN,
    city                 VARCHAR(50),
    created_at           TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ── 6. RIDES TABLE ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS rides (
    ride_id               VARCHAR(15)  PRIMARY KEY,
    ride_datetime         TIMESTAMP    NOT NULL,
    date                  DATE         NOT NULL,
    hour                  INTEGER      NOT NULL,
    day_of_week           VARCHAR(15),
    is_weekend            BOOLEAN,
    month                 INTEGER,
    pickup_zone_id        VARCHAR(10)  REFERENCES zones(zone_id),
    pickup_zone_name      VARCHAR(100),
    pickup_zone_type      VARCHAR(30),
    pickup_h3_index       VARCHAR(20),
    dropoff_zone_id       VARCHAR(10)  REFERENCES zones(zone_id),
    dropoff_zone_name     VARCHAR(100),
    dropoff_zone_type     VARCHAR(30),
    dropoff_h3_index      VARCHAR(20),
    driver_id             VARCHAR(10)  REFERENCES drivers(driver_id),
    vehicle_type          VARCHAR(20),
    distance_km           DECIMAL(6,1),
    duration_min          DECIMAL(6,1),
    wait_time_min         DECIMAL(5,1),
    fare_amount           DECIMAL(10,2),
    surge_multiplier      DECIMAL(4,2),
    status                VARCHAR(30),
    payment_mode          VARCHAR(20),
    ride_rating           DECIMAL(3,1),
    cancellation_reason   VARCHAR(50),
    weather_condition     VARCHAR(30),
    rainfall_mm           DECIMAL(6,1),
    is_raining            BOOLEAN,
    temperature_c         DECIMAL(5,1),
    active_event_id       VARCHAR(10),
    active_event_type     VARCHAR(30),
    city                  VARCHAR(50),
    created_at            TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ── 7. INDEXES ─────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_rides_date
    ON rides(date);
CREATE INDEX IF NOT EXISTS idx_rides_hour
    ON rides(hour);
CREATE INDEX IF NOT EXISTS idx_rides_pickup_zone
    ON rides(pickup_zone_id);
CREATE INDEX IF NOT EXISTS idx_rides_dropoff_zone
    ON rides(dropoff_zone_id);
CREATE INDEX IF NOT EXISTS idx_rides_driver
    ON rides(driver_id);
CREATE INDEX IF NOT EXISTS idx_rides_status
    ON rides(status);
CREATE INDEX IF NOT EXISTS idx_rides_datetime
    ON rides(ride_datetime);
CREATE INDEX IF NOT EXISTS idx_rides_h3_pickup
    ON rides(pickup_h3_index);
CREATE INDEX IF NOT EXISTS idx_weather_date_hour
    ON weather(date, hour);
CREATE INDEX IF NOT EXISTS idx_events_date
    ON events(event_date);
CREATE INDEX IF NOT EXISTS idx_drivers_status
    ON drivers(status);
CREATE INDEX IF NOT EXISTS idx_drivers_zone
    ON drivers(current_zone_id);