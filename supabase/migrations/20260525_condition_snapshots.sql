-- GOATvision Seattle: historical condition snapshots
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor > New query)

CREATE TABLE condition_snapshots (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  captured_at  timestamptz NOT NULL    DEFAULT now(),
  category     text        NOT NULL,   -- 'traffic' | 'ferry' | 'weather' | 'aqi'
  location_key text        NOT NULL,   -- e.g. 'I-405-N', 'BAINBRIDGE', 'SEA-TAC'
  value        numeric     NOT NULL,   -- raw metric: delay minutes, drive score, AQI number, etc.
  raw_json     jsonb       NOT NULL    DEFAULT '{}'
);

CREATE INDEX idx_condition_snapshots_lookup
  ON condition_snapshots (category, location_key, captured_at DESC);

-- Row Level Security: enabled, anon role can read and write (public dashboard, no auth yet)
ALTER TABLE condition_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_read_write" ON condition_snapshots
  FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);
