-- GOATvision (shared project across Philly/Seattle/DMV): lock the anon key down to
-- SELECT-only. All writes now go through each app's /api/telemetry proxy using the
-- service-role key server-side, matching the client-secret-vs-server-secret separation
-- already applied to every other credential (WMATA, Ticketmaster, HERE, PennDOT, WSDOT).
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor > New query).

-- condition_snapshots previously granted anon full CRUD via a single "FOR ALL" policy —
-- anyone holding the public anon key (it ships in every page's source, across all three
-- sites) could delete or overwrite any row, not just insert new telemetry. Replace with
-- SELECT-only.
DROP POLICY IF EXISTS "anon_read_write" ON condition_snapshots;

CREATE POLICY "anon_select_only" ON condition_snapshots
  FOR SELECT TO anon
  USING (true);

-- transit_telemetry / ferry_telemetry / sfd_telemetry / aqi_telemetry already had a
-- correctly-scoped SELECT policy for anon (unchanged) and a service_role INSERT policy
-- (unchanged, and redundant in Supabase since service_role bypasses RLS by default — kept
-- as-is rather than removed, to avoid touching anything not part of this fix). Only the
-- anon INSERT policy needs to go, since writes now happen server-side.
DROP POLICY IF EXISTS "anon_insert" ON transit_telemetry;
DROP POLICY IF EXISTS "anon_insert" ON ferry_telemetry;
DROP POLICY IF EXISTS "anon_insert" ON sfd_telemetry;
DROP POLICY IF EXISTS "anon_insert" ON aqi_telemetry;

-- traffic_snapshot needs no change — it already has zero anon policies of any kind (RLS
-- enabled, default-deny), confirmed empirically: a direct anon-key SELECT returns an empty
-- result even though the table has real, current rows (visible via the service-role-backed
-- /api/traveltimes endpoint). Only server-side cron/proxy code touches this table.
