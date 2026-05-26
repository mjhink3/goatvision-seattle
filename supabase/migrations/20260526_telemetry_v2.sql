-- GOATvision Seattle: historical telemetry v2
-- Replaces condition_snapshots with purpose-built time-bucket telemetry tables
-- Run in Supabase SQL Editor (Dashboard > SQL Editor > New query)

-- ╔══════════════════════════════════════════════════════════╗
--  TRANSIT TELEMETRY (WSDOT highway travel times)
-- ╚══════════════════════════════════════════════════════════╝
CREATE TABLE transit_telemetry (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  captured_at      timestamptz NOT NULL    DEFAULT now(),
  route_id         text        NOT NULL,
  route_name       text,
  current_minutes  integer,
  average_minutes  integer,
  delta_minutes    integer,                -- current_minutes - average_minutes
  delta_percent    numeric,                -- delta / average * 100
  hour_of_day      integer,               -- 0-23
  day_of_week      integer,               -- 0-6, 0=Sunday
  weather_code     integer,               -- Open-Meteo WMO code
  precipitation    numeric,
  is_game_day      boolean     DEFAULT false,
  game_type        text                    -- nullable: 'MLB', 'WNBA', 'NHL', etc.
);

CREATE INDEX idx_transit_telemetry_time_bucket
  ON transit_telemetry (hour_of_day, day_of_week);

CREATE INDEX idx_transit_telemetry_captured_at
  ON transit_telemetry (captured_at DESC);

CREATE INDEX idx_transit_telemetry_composite
  ON transit_telemetry (hour_of_day, day_of_week, weather_code);

ALTER TABLE transit_telemetry ENABLE ROW LEVEL SECURITY;

CREATE POLICY "transit_anon_read" ON transit_telemetry
  FOR SELECT TO anon USING (true);

CREATE POLICY "transit_service_write" ON transit_telemetry
  FOR INSERT TO service_role WITH CHECK (true);

CREATE POLICY "anon_insert" ON transit_telemetry
  FOR INSERT TO anon WITH CHECK (true);

-- ╔══════════════════════════════════════════════════════════╗
--  FERRY TELEMETRY (WSDOT vessel locations)
-- ╚══════════════════════════════════════════════════════════╝
CREATE TABLE ferry_telemetry (
  id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  captured_at          timestamptz NOT NULL    DEFAULT now(),
  route_name           text        NOT NULL,
  vessel_name          text,
  is_delayed           boolean,
  minutes_late         integer,
  scheduled_departure  timestamptz,
  actual_departure     timestamptz,
  weather_code         integer,
  wind_speed           numeric,
  precipitation        numeric,
  hour_of_day          integer,
  day_of_week          integer
);

CREATE INDEX idx_ferry_telemetry_time_bucket
  ON ferry_telemetry (hour_of_day, day_of_week);

CREATE INDEX idx_ferry_telemetry_captured_at
  ON ferry_telemetry (captured_at DESC);

CREATE INDEX idx_ferry_telemetry_composite
  ON ferry_telemetry (hour_of_day, day_of_week, weather_code);

ALTER TABLE ferry_telemetry ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ferry_anon_read" ON ferry_telemetry
  FOR SELECT TO anon USING (true);

CREATE POLICY "ferry_service_write" ON ferry_telemetry
  FOR INSERT TO service_role WITH CHECK (true);

CREATE POLICY "anon_insert" ON ferry_telemetry
  FOR INSERT TO anon WITH CHECK (true);

-- ╔══════════════════════════════════════════════════════════╗
--  SFD TELEMETRY (Seattle Fire Dispatch aggregates)
-- ╚══════════════════════════════════════════════════════════╝
CREATE TABLE sfd_telemetry (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  captured_at       timestamptz NOT NULL    DEFAULT now(),
  window_start      timestamptz,
  total_dispatches  integer,
  medical_count     integer,
  fire_hazmat_count integer,
  other_count       integer,
  hour_of_day       integer,
  day_of_week       integer,
  weather_code      integer,
  precipitation     numeric,
  is_game_day       boolean     DEFAULT false
);

CREATE INDEX idx_sfd_telemetry_time_bucket
  ON sfd_telemetry (hour_of_day, day_of_week);

CREATE INDEX idx_sfd_telemetry_captured_at
  ON sfd_telemetry (captured_at DESC);

ALTER TABLE sfd_telemetry ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sfd_anon_read" ON sfd_telemetry
  FOR SELECT TO anon USING (true);

CREATE POLICY "sfd_service_write" ON sfd_telemetry
  FOR INSERT TO service_role WITH CHECK (true);

CREATE POLICY "anon_insert" ON sfd_telemetry
  FOR INSERT TO anon WITH CHECK (true);

-- ╔══════════════════════════════════════════════════════════╗
--  AQI TELEMETRY (Open-Meteo air quality)
-- ╚══════════════════════════════════════════════════════════╝
CREATE TABLE aqi_telemetry (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  captured_at  timestamptz NOT NULL    DEFAULT now(),
  aqi_value    integer,
  smoke_pm25   numeric,
  weather_code integer,
  wind_speed   numeric,
  hour_of_day  integer,
  day_of_week  integer,
  month        integer                 -- 1-12, for seasonal smoke patterns
);

CREATE INDEX idx_aqi_telemetry_time_bucket
  ON aqi_telemetry (hour_of_day, day_of_week);

CREATE INDEX idx_aqi_telemetry_captured_at
  ON aqi_telemetry (captured_at DESC);

ALTER TABLE aqi_telemetry ENABLE ROW LEVEL SECURITY;

CREATE POLICY "aqi_anon_read" ON aqi_telemetry
  FOR SELECT TO anon USING (true);

CREATE POLICY "aqi_service_write" ON aqi_telemetry
  FOR INSERT TO service_role WITH CHECK (true);

CREATE POLICY "anon_insert" ON aqi_telemetry
  FOR INSERT TO anon WITH CHECK (true);

-- ╔══════════════════════════════════════════════════════════╗
--  TIME-BUCKET BASELINE QUERY FUNCTION
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION get_transit_baseline(
  p_route_id      text,
  p_hour          integer,
  p_dow           integer,
  p_weather_bucket text  -- 'clear', 'rain', 'heavy_rain', 'snow'
)
RETURNS TABLE(
  avg_delta        numeric,
  avg_delta_percent numeric,
  sample_count     integer,
  confidence       text
) AS $$
DECLARE
  weather_codes integer[];
BEGIN
  -- Map weather bucket to WMO codes
  weather_codes := CASE p_weather_bucket
    WHEN 'clear'      THEN ARRAY[0,1,2]
    WHEN 'rain'       THEN ARRAY[51,53,61,63,80,81]
    WHEN 'heavy_rain' THEN ARRAY[55,65,82]
    WHEN 'snow'       THEN ARRAY[71,73,75,77,85,86]
    ELSE                   ARRAY[0,1,2,3]
  END;

  RETURN QUERY
  SELECT
    ROUND(AVG(delta_minutes)::numeric, 1),
    ROUND(AVG(delta_percent)::numeric, 1),
    COUNT(*)::integer,
    CASE
      WHEN COUNT(*) < 10  THEN 'low'
      WHEN COUNT(*) < 50  THEN 'medium'
      WHEN COUNT(*) < 200 THEN 'high'
      ELSE                     'very_high'
    END
  FROM transit_telemetry
  WHERE route_id    = p_route_id
    AND hour_of_day = p_hour
    AND day_of_week = p_dow
    AND weather_code = ANY(weather_codes)
    AND captured_at > now() - interval '90 days';
END;
$$ LANGUAGE plpgsql;
