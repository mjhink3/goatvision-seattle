# GOATvision Seattle — Project Overview V3

> **Written:** May 26 2026  
> **Version:** v2.1 (codebase tag in `goatvision-seattle.html`)  
> **Purpose:** Complete onboarding document for a new Claude session or any new collaborator.  
> **Rule:** All information here was read from actual code — nothing is inferred or guessed.

---

## 1. What Is GOATvision Seattle

GOATvision Seattle is a **real-time situational awareness dashboard** for the Seattle metro area. It aggregates roughly a dozen live data APIs — traffic, transit, ferries, weather, fire dispatch, seismic, flight delays, tides — into a single scrollable web page with no login, no account, no ads.

### What it is NOT
- Not a native app or PWA (no service worker, no manifest)
- Not a React/Vue/Angular project — zero npm, zero build step
- Not connected to a back end server — it is a static HTML file that runs entirely client-side
- Not designed for anonymous public traffic (keys are embedded; use at your own risk)

### What makes it special
- **One file.** The entire app is `goatvision-seattle.html` (~3,800 lines). Copy it anywhere with an internet connection and it works.
- **Ops Brief.** A rule-based synthesis panel at the top reads all other panels and generates a plain-English situational summary — no AI, purely conditional logic.
- **Telemetry layer.** Every fetch silently writes a record to Supabase so baseline comparisons improve over time.
- **Replication intent.** The architecture is factored so a new city can be stood up by changing `CITY_CONFIG` and swapping API keys.

### Current deployment
- Local file: `C:\Users\mjhin\OneDrive\Desktop\GOATvision Seattle\goatvision-seattle.html`
- GitHub Pages copy: `index.html` (always synced from the main file before each commit)
- Git repo at: `C:\Users\mjhin\OneDrive\Desktop\GOATvision Seattle` (no remote origin shown in local history; pushed via `git push`)

---

## 2. Live Data Sources — Complete and Current

| Source | API / URL | Key Required | Refresh |
|--------|-----------|-------------|---------|
| **Weather (current + hourly forecast)** | Open-Meteo `api.open-meteo.com` | No | 5 min |
| **Air Quality / AQI** | Open-Meteo Air Quality `air-quality-api.open-meteo.com` | No | 5 min |
| **NWS Active Alerts** | `api.weather.gov/alerts/active?area=WA` | No | 5 min |
| **WSDOT Highway Travel Times** | WSDOT Traffic REST API | `CONFIG.WSDOT_KEY` | 2 min |
| **WSDOT Active Incidents** | WSDOT Traffic REST API | `CONFIG.WSDOT_KEY` | 2 min |
| **WSDOT Ferry Vessel Locations** | WSDOT Ferries REST API | `CONFIG.WSDOT_KEY` | 2 min |
| **WSDOT Scenic Cameras** | WSDOT Highway Cameras REST API | `CONFIG.WSDOT_KEY` | 10 min (list); 60s (images) |
| **Link Light Rail Arrivals** | OneBusAway Puget Sound API | `CONFIG.OBA_KEY` (TEST) | 90s |
| **Link Live Train Positions** | OBA trip status (position from `fetchTransit`) | `CONFIG.OBA_KEY` | 60s |
| **Seattle Fire Dispatch** | Seattle Open Data `data.seattle.gov/resource/kzjm-xkqj.json` | No | 5 min |
| **Seattle Sports Events** | ESPN `site.api.espn.com` (schedules) | No | 1 hr |
| **Concerts / Events** | Ticketmaster Discovery API | `CONFIG.TICKETMASTER_KEY` | 1 hr |
| **Puget Sound Tides** | NOAA CO-OPS `api.tidesandcurrents.noaa.gov` (station 9447130) | No | 10 min |
| **Earthquakes** | USGS FDSNWS `earthquake.usgs.gov` | No | 5 min |
| **Cascade Volcano Alerts** | USGS Volcano Hazards `volcanoes.usgs.gov/vsc/api/volcanoInfo/` | No | 30 min |
| **SEA-TAC Airport Delays** | FAA NAS Status `nasstatus.faa.gov` | No | 5 min |
| **Telemetry reads** | Supabase REST (anon key) | `CONFIG.SUPABASE_ANON_KEY` | On-demand per panel |

### CORS proxy chain
WSDOT APIs block direct browser requests. A three-proxy fallback chain is tried in order:
```javascript
const PROXIES = [
  'https://api.allorigins.win/raw?url=',
  'https://corsproxy.io/?',
  'https://api.codetabs.com/v1/proxy?quest=',
];
```
FAA also uses a CORS proxy (same three services, but the FAA `fetchSEA` function defines its own local proxy array with a slightly different parameter format).

### API keys embedded in CONFIG (line ~1324)
```javascript
const CONFIG = {
  WSDOT_KEY:        '<redacted — now server-side only, see api/wsdot.js>',
  OBA_KEY:          'TEST',
  TICKETMASTER_KEY: '<redacted — now server-side only, see api/ticketmaster.js>',
  SUPABASE_URL:     'https://scsdstpabzkiqnvsskts.supabase.co',
  SUPABASE_ANON_KEY:'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNjc2RzdHBhYnpraXFudnNza3RzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk3MTUxNzcsImV4cCI6MjA5NTI5MTE3N30.HMo41UCsWsCwk75GxoujLcIlwlZDhXPNnLZ1x7K8VV8',
  REFRESH_WEATHER_MS:   5 * 60 * 1000,
  REFRESH_TT_MS:        2 * 60 * 1000,
  REFRESH_INCIDENTS_MS: 2 * 60 * 1000,
  REFRESH_FERRY_MS:     2 * 60 * 1000,
};
```
The `OBA_KEY = 'TEST'` is rate-limited to ~30 req/min. A 300ms throttle (`_obaThrottle`) spaces stop fetches to avoid hitting it.

---

## 3. Panel-by-Panel Breakdown (Display Order)

Panels appear in the following DOM order. Each has a `#panel-id` and a status dot (`setDot(id, color)`).

### 1. `#ops-brief-panel` — Seattle Ops Brief
- **What:** Rule-based synthesis of all other panels. Generates 1–8 plain-English bullets.
- **Renders:** 2 seconds after `init()`, then every 2 minutes.
- **Readiness gate:** `_brief` object — must have ≥3 flags set to `true` before rendering.
- **Bullet categories (in priority order):** Traffic worst route, current weather, drive window forecast, ferry gaps, Link rail status, today's events, Rainier visibility, NWS alerts, SFD fire/hazmat spike.
- **Color coding:** green/amber/red dot per bullet, blinking cursor after last bullet.

### 2. `#conditions-strip` — Current Conditions
- **What:** Compact strip: temperature, feels-like, sky description, wind, precipitation probability, AQI, cloud cover.
- **Source:** Open-Meteo current weather + air quality.
- **Dot:** green/amber/red based on WMO severity and AQI value.

### 3. `#nws-panel` — NWS Active Weather Alerts
- **What:** Live NWS alert cards for Washington State.
- **Footer:** Subtle link to NWS Seattle Forecast Office (`forecast.weather.gov/MapClick.php?CityName=Seattle`).
- **Dot:** red if Extreme/Severe alerts present, amber for Moderate, green if none.

### 4. `#incidents-panel` — Active Incidents & Alerts
- **What:** WSDOT traffic incidents (crashes, closures, construction) near Seattle metro bounding box.
- **Dot:** red if High/Severe severity, amber if Minor/Moderate, green if clear.

### 5. `#traveltimes-panel` — Highway Travel Times
- **What:** WSDOT travel time rows for I-5, I-90, SR-520, I-405, SR-522 filtered to Seattle metro bounding box (lat 47.30–47.85, lon -122.55 to -121.60). HOV and Express Lane routes excluded.
- **Layout:** Filter buttons (ALL / I-5 / I-90 / SR-520 / I-405) above route rows. Each row: road+direction tag, segment name, current minutes, 7-day baseline or live average, badge (ON TIME / +Xm).
- **Historical badge:** `tt-pred-*` span — populated non-blocking from Supabase `get_transit_baseline()`. Shows `Hist: +Xm` or `Hist: On time` with confidence class.
- **Low-confidence footnote:** Appended to list bottom when any route has `confidence='low'`.
- **Dot:** red if worst route > 50% above average, amber if > 10%, green otherwise.

### 6. `#drive-window` — 12-Hour Drive Quality Window
- **What:** 12 hourly bars scoring current + next 11 hours. Score 0–100 (lower = better conditions).
- **Score formula:** `precip×0.4 + windSeverity×0.3 + wmoSeverity×0.3` (all scaled 0–100).
- **Bars:** green < 40, amber 40–69, red ≥ 70.
- **Ops Brief integration:** Reports when score crosses 40 threshold (good → bad or bad → good).

### 7. `#trafficmap-panel` — Seattle Metro Traffic Flow
- **What:** Static SVG schematic of major Seattle corridors (I-5 N/S, SR-520, I-90 E/B, I-405 N/S). Segment stroke colors update live from travel times data.
- **Colors:** green ≤ 1.1× average, amber ≤ 1.5×, red > 1.5×.
- **Segment IDs:** `seg-i5-n`, `seg-i5-s`, `seg-520`, `seg-i90-e`, `seg-i90-b`, `seg-405-n`, `seg-405-s`.
- **Updated:** Every time `fetchTravelTimes()` completes (every 2 min).

### 8. `#ferry-panel` — WSF Ferry Status
- **What:** WSDOT vessel positions for 4 monitored routes. Progress bar (0–1) per vessel via GPS Haversine or time-based fallback. AtDock = 0.03.
- **Routes (FERRY_ROUTE_KEYWORDS):**
  - Mukilteo / Clinton — `every` match
  - Seattle / Bainbridge Island — `every` match
  - Fauntleroy / Vashon Island / Southworth — `matchAny: true` (triangle route: `.some()` match, skips vessels with empty terminal names)
  - Point Defiance / Tahlequah — `every` match
- **Footer:** `Verify schedules at wsdot.com/ferries ↗`
- **Dot:** green if all routes have vessel data (5–23h), amber if missing routes, gray off-hours.

### 9. `#transit-panel` — Link Light Rail — Key Stations
- **What:** OBA real-time arrivals for selected stops on 1 Line, 2 Line, T Line.
- **LINK_LINES config (line ~2720):**
  - 1 Line (blue `#00a1de`): Northgate `40_99260`, U District `40_99111`, Capitol Hill `40_99101`, Westlake `40_990006`, SeaTac/Airport `40_99904`
  - 2 Line (red `#e31837`): Redmond Technology `40_99914`, Bellevue Downtown `40_99610`
  - T Line (purple `#6f2c91`): Tacoma Dome / Stadium / Hilltop — `stopId: null` (no OBA coverage)
- **OBA throttle:** 300ms between stop fetches (`_obaThrottle`).
- **`transitHasLivePredictions`:** Boolean set true if any arrival has `predictedArrivalTime` non-null.
- **Dot:** green if live predictions, amber if schedule-only, gray if no data.

### 10. `#link-map-panel` — Link Light Rail — Live Train Positions
- **What:** SVG schematic map (~720×460) with geographically placed train icons.
- **1 Line:** Positions from `_transitArrivals` (already fetched by `fetchTransit`). Renders `↑`/`↓` arrow glyphs based on headsign.
- **2 Line:** No OBA position data available — legend notes this explicitly.
- **T Line:** Not shown (separate Tacoma system, no OBA coverage).
- **Refresh:** `fetchLinkVehicles()` every 60s; first call delayed 10s after init to let `fetchTransit` complete.

### 11. `#metro-panel` — King County Metro — Key Routes [EST]
- **What:** Schedule-frequency estimator for 8 high-frequency routes. Not live GPS tracking.
- **Routes:** 7, 8, 40, 44, 48, 62, 101, 150 — each with peak/offpeak/night headway minutes.
- **Frequency selection:** Peak (6–9am, 3–7pm weekdays), Offpeak (weekday midday), Night (weekends + before 6am + after 10pm).
- **Departure format:** `in ~Xm · ~Ym · ~Zm` — cycle-based estimate from current minute.
- **Header badge:** `EST` in amber border signals these are estimates, not live.
- **Footer:** `⚠ Schedule estimates only — not live GPS tracking · For real-time arrivals: pugetsound.onebusaway.org`
- **Dot:** always amber (schedule-only, never live).

### 12. `#events-panel` — Events & Game Day
- **What:** Today's and upcoming home games for Seattle teams + Ticketmaster concerts at major venues.
- **Teams (CITY_CONFIG.teams):** Mariners (MLB), Seahawks (NFL), Sounders (MLS), Kraken (NHL), Storm (WNBA).
- **ESPN endpoint:** `site.api.espn.com/apis/site/v2/sports/{sport}/{league}/teams/{id}/schedule`
- **Ticketmaster:** Discovery API `app.ticketmaster.com/discovery/v2/events.json` filtered to Seattle lat/lon radius.
- **Dot:** amber if game today, green otherwise.

### 13. `#sea-panel` — Seattle-Tacoma International
- **What:** FAA NAS Status XML parsed for SEA-TAC delays and ground stops.
- **Source:** `nasstatus.faa.gov/api/airport-status-information/airport-delay-groups` via CORS proxy.
- **Footer links:** `flysea.org ↗` and `FlightAware SEA ↗`
- **Dot:** green = no delays, amber = delays, red = ground stop, gray = data unavailable.

### 14. `#sfd-panel` — Seattle Fire & Aid Dispatches — Last 2 Hours
- **What:** Last 2 hours of Seattle Fire Department dispatch records, categorized into Medical, Fire/Hazmat, Other.
- **Source:** Seattle Open Data Socrata API (`kzjm-xkqj.json`), filtered to `datetime >= now - 2h`.
- **Telemetry:** Writes aggregate to `sfd_telemetry` after each fetch.
- **Dot:** red if fire/hazmat > 3 in window, amber if medical calls elevated, green if quiet.

### 15. `#seismic-panel` — Seismic & Volcanic Activity — PNW
- **What:** M1.5+ earthquakes within 300km of Seattle (last 8, ordered by time) + alert levels for Mount Rainier, Baker, St. Helens.
- **Earthquake source:** USGS FDSNWS — no key, no proxy.
- **Volcano source:** USGS Volcano Hazards API — no key, no proxy. Falls back to static "Normal" if API fails.
- **Footer links:** `USGS Earthquake Map ↗` and `USGS Volcano Notifications ↗`
- **Dot:** red if any M4+, amber if any M2.5+, green otherwise.

### 16. `#extras-grid` — Coffee Index, Tide, Bicycle Conditions
Three side-by-side cards (each is its own rendered section):

**Coffee Index:** Demand score 0–100 from time-of-day peak (morning rush, afternoon slump), weekday vs. weekend, weather (cold/rainy = higher demand), nearby events, traffic congestion level. Pure client-side computation.

**Puget Sound Tide:** NOAA CO-OPS API, station 9447130 (Elliott Bay MLLW). Shows current water level, next high and next low with times.

**Bicycle Conditions:** Score 0–100 (higher = better). Temp 25pts + wind 25pts + precip 25pts + sky/visibility 25pts. Also shows "great / decent / rough / not advised" label.

### 17. `#scenic-panel` — Live Camera Feeds
- **What:** WSDOT highway camera images near ferry terminals, updated every 60s.
- **Filter:** `CITY_CONFIG.cameraRoadName`, `cameraLatMin`, `cameraLatMax`. Prioritizes terminals listed in `CITY_CONFIG.cameraTerminalOrder`.
- **Layout:** CSS grid of thumbnail cards. Click any card → lightbox fullscreen.
- **Lightbox:** `#cam-lightbox` overlay with `closeLightbox()`.

### 18. `#hospitals-panel` — Regional Trauma & Major Medical Centers
Static informational cards for 6 hospitals. All names link to hospital websites; phone shown below address. Green `LEVEL I TRAUMA` / `LEVEL II` / etc. tags.

| Hospital | Phone | Tag |
|----------|-------|-----|
| Harborview Medical Center | (206) 744-3000 | Level I Trauma, Burn Center |
| UW Medical Center | (206) 598-3300 | Level I Trauma, Transplant |
| Swedish Medical Center | (206) 386-6000 | Level II Trauma, Cardiac |
| Virginia Mason | (206) 223-6600 | Orthopedics, Cancer |
| Overlake Medical Center | (425) 688-5000 | Level III Trauma, Bellevue |
| Seattle Children's | (206) 987-2000 | Pediatric Level I Trauma |

### 19. `#vet-panel` — Emergency Veterinary & Animal Services
Static informational cards for 6 facilities. Amber tags indicate service type. Same CSS pattern as hospitals but amber color scheme.

| Facility | Address | Phone | Tag |
|----------|---------|-------|-----|
| BluePearl Pet Hospital | 4020 Stone Way N | (206) 448-6479 | 24/7 Emergency |
| VCA Animal Emergency | 16554 NE 74th St, Redmond | (425) 827-8727 | 24/7 Emergency |
| AVS Kirkland | 13020 NE 85th St | (425) 823-9111 | Emergency, Surgery |
| ACCES | 11536 Lake City Way NE | (206) 364-1660 | 24/7, Blood Bank |
| South Seattle Veterinary | 11033 1st Ave S, Seattle WA 98168 | (206) 242-8338 | Veterinary Care |
| Seattle Animal Shelter | 2061 15th Ave W | (206) 386-7387 | Lost & Found |

Footer: ASPCA Animal Poison Control link (888-426-4435, aspca.org/pet-care/animal-poison-control).

### 20. `#links-panel` — Regional Quick Links
5 categorized groups of `.link-btn` styled buttons (same look as `.tt-filter-btn`). Mono 9px bold, bg3, border, hover → blue.

| Category | Links |
|----------|-------|
| Emergency & Health | WA 211, ASPCA Poison Control, King County Public Health |
| Transportation | WA 511, WSDOT Traffic Cameras, Sound Transit Trip Planner, KC Metro Trip Planner, NOAA Marine Forecast |
| City & County | Seattle City Light Outage, PSE Outage, AlertSeattle, SDOT, Seattle Parks Reservations |
| Schools | Seattle Public Schools, Bellevue School District, Northshore SD |
| Regional | Visit Seattle, Port of Seattle/Sea-Tac, Sound Transit |

---

## 4. Architecture

### File structure
```
GOATvision Seattle/
├── goatvision-seattle.html       ← THE app (everything in one file)
├── index.html                    ← Exact copy, synced before every git commit
├── GOATVISION_SEATTLE_V3.md      ← This document
├── GOATVISION_PROJECT_OVERVIEW.md ← Older V1/V2 doc (superseded)
├── GOATvision Seattle Claude.bat  ← Launcher batch file
├── GOATvision_Seattle_logo.png    ← Logo asset
├── seattle-ops-dashboard.html     ← Legacy/prototype file, not in active use
└── supabase/
    └── migrations/
        ├── 20260525_condition_snapshots.sql  ← Original table schema
        └── 20260526_telemetry_v2.sql         ← Current v2 telemetry schema
```

### Internal structure of `goatvision-seattle.html`
```
Lines 1–722    CSS (custom properties, panel styles, status dots, animations)
Lines 724–1314 HTML (all panels in DOM order, static + dynamic containers)
Lines 1315–end JavaScript (no bundling, no modules — all in one <script> tag)
  ├─ 1324  CONFIG  { API keys, refresh intervals }
  ├─ 1337  CITY_CONFIG  { Seattle-specific: lat/lon, teams, stations, quotes }
  ├─ 1443  Supabase client init (_supa)
  ├─ 1460  Telemetry helpers (_twx, _tnow, _todayEvs)
  ├─ 1480  Telemetry write functions (telemetryTransit, telemetryFerry, etc.)
  ├─ 1550  Supabase read (snapshotCondition, getHistoricalBaseline)
  ├─ 1594  CORS proxy chain + wsdotFetch()
  ├─ 1640  Utility functions (ts, minsAgo, parseDotNetDate, haversine, etc.)
  ├─ 1700  Clock + Quote of the day
  ├─ 1720  Weather (fetchWeather, renderConditionsStrip, driveWindowScores)
  ├─ 1850  AQI (fetchAirQuality)
  ├─ 1900  NWS Alerts (fetchNWSAlerts)
  ├─ 1950  SFD Dispatch (fetchSFD)
  ├─ 2000  Incidents (fetchIncidents)
  ├─ 2030  Ferry (FERRY_ROUTE_KEYWORDS, matchRoute, vesselProgress, fetchFerry, renderFerry)
  ├─ 2200  Events (fetchEvents ESPN, fetchTicketmaster)
  ├─ 2350  Coffee Index
  ├─ 2400  Tide (fetchTide)
  ├─ 2450  Bicycle Index
  ├─ 2500  Transit / OBA (fetchTransit, LINK_LINES, _transitArrivals, _obaThrottle)
  ├─ 2720  Link map (LINK_MAP_STNS, renderLinkMap, fetchLinkVehicles)
  ├─ 3024  Metro schedule (METRO_SCHEDULES, getMetroFreq, getNextDepartures, renderMetroSchedule)
  ├─ 3080  Highway Travel Times (fetchTravelTimes, renderTravelTimes, getWeatherBucket, getTransitPrediction)
  ├─ 3249  Scenic cameras (fetchScenicCams, renderScenicGrid, openLightbox, closeLightbox)
  ├─ 3338  Traffic flow map SVG (updateTrafficMap)
  ├─ 3365  Ops Brief (generateOpsBrief)
  ├─ 3529  Seismic (fetchSeismic, fetchVolcano, renderSeismic)
  ├─ 3665  SEA-TAC / FAA (fetchSEA)
  └─ 3753  init() + setInterval schedule + DOMContentLoaded
```

### Key global state variables
| Variable | Type | Purpose |
|----------|------|---------|
| `weatherData` | object | Current + hourly Open-Meteo response |
| `driveWindowScores` | array | 12 hourly drive quality scores `{label, score}` |
| `nwsAlerts` | array | Raw NWS alert feature objects |
| `allTravelTimes` | array | Filtered+enriched WSDOT travel time rows |
| `ttRoadFilter` | string | Active filter button: `'ALL'`, `'I-5'`, etc. |
| `ferryVessels` | array | Raw WSDOT vessel response objects |
| `eventsData` | array | Combined ESPN + Ticketmaster events |
| `sfdDispatches` | array | Last 2h SFD dispatch records |
| `_transitArrivals` | array | Raw OBA arrival objects (with `tripStatus.position`) |
| `transitHasLivePredictions` | boolean | True if any OBA arrival has live predicted time |
| `scenicCams` | array | WSDOT camera objects currently displayed |
| `_seismicQuakes` | array/null | USGS earthquake features (null = not yet loaded) |
| `_volcanoStatuses` | array/null | Parsed volcano alert objects |
| `_brief` | object | Readiness flags: `{weather, tt, ferry, transit, nws, sfd, events}` |

### Status dot system
`setDot(id, color)` sets a CSS class on the dot element for green/amber/red/gray glow. Dot IDs follow the pattern `{panel}-dot` (e.g., `transit-dot`, `sea-dot`, `seismic-dot`).

### `addTargetBlank(html)` utility
Regex adds `target="_blank" rel="noopener noreferrer"` to any `<a>` tag that does not already have `target=`. Used on dynamically generated content from API responses.

### Mobile responsiveness
Single breakpoint: `@media (max-width: 480px)`. Switches to single column. Hides some secondary elements. No tablet-specific styles.

---

## 5. Supabase Telemetry Layer

### Supabase project
- **URL:** `https://scsdstpabzkiqnvsskts.supabase.co`
- **Anon key:** embedded in `CONFIG.SUPABASE_ANON_KEY`
- **Client:** `supabase.createClient()` from CDN `@supabase/supabase-js@2` — initialized as `_supa` (null if keys missing)

### Tables

#### `condition_snapshots` (migration: `20260525_condition_snapshots.sql`)
Original rolling-baseline table. Still used by `snapshotCondition()` and `getHistoricalBaseline()`.
```sql
condition_snapshots (
  id           uuid PRIMARY KEY,
  captured_at  timestamptz DEFAULT now(),
  category     text NOT NULL,     -- 'traffic' | 'ferry' | 'weather' | 'aqi'
  location_key text NOT NULL,     -- e.g. 'I-405-N', 'BAINBRIDGE', 'SEA-TAC'
  value        numeric NOT NULL,
  raw_json     jsonb DEFAULT '{}'
)
```
RLS: anon read+write (FOR ALL).

#### `transit_telemetry` (migration: `20260526_telemetry_v2.sql`)
Written by `telemetryTransit(routes)` after each WSDOT travel times fetch.
```sql
transit_telemetry (
  route_id, route_name,
  current_minutes, average_minutes, delta_minutes, delta_percent,
  hour_of_day, day_of_week, weather_code, precipitation,
  is_game_day, game_type
)
```

#### `ferry_telemetry`
Written by `telemetryFerry(vessels)` after each ferry fetch.
```sql
ferry_telemetry (
  route_name, vessel_name, is_delayed, minutes_late,
  scheduled_departure, actual_departure,
  weather_code, wind_speed, precipitation,
  hour_of_day, day_of_week
)
```

#### `sfd_telemetry`
Written by `telemetrySFD(dispatches)` after each SFD fetch.
```sql
sfd_telemetry (
  window_start, total_dispatches,
  medical_count, fire_hazmat_count, other_count,
  hour_of_day, day_of_week, weather_code, precipitation, is_game_day
)
```

#### `aqi_telemetry`
Written by `telemetryAQI(aqiValue, smokeValue)` after each air quality fetch.
```sql
aqi_telemetry (
  aqi_value, smoke_pm25, weather_code, wind_speed,
  hour_of_day, day_of_week, month
)
```

### RLS policies (all four v2 tables)
- `anon SELECT` — public read
- `anon INSERT` — public write (dashboard writes directly)
- `service_role INSERT` — for server-side use if needed later

### `get_transit_baseline()` SQL function
Called by `getTransitPrediction(routeId)` → displayed as `Hist:` badge in travel times panel.
```sql
get_transit_baseline(p_route_id, p_hour, p_dow, p_weather_bucket)
→ { avg_delta, avg_delta_percent, sample_count, confidence }
```
- `p_weather_bucket` → mapped to WMO codes: `clear=[0,1,2]`, `rain=[51,53,61,63,80,81]`, `heavy_rain=[55,65,82]`, `snow=[71,73,75,77,85,86]`
- 90-day rolling window
- Confidence: `low` (<10 samples), `medium` (<50), `high` (<200), `very_high` (≥200)

### Telemetry helper functions
```javascript
function _twx()  { return weatherData?.current ?? {}; }        // current weather
function _tnow() { return { h: now.getHours(), dow: now.getDay(), mo: now.getMonth()+1 }; }
function _todayEvs() { return eventsData.filter(e => e.date.toDateString() === today); }
```

### Known telemetry behavior
- All writes are fire-and-forget with `await _supa.from(...).insert(...)` wrapped in try/catch. Failures are logged to console but never surface to the user.
- The Supabase URL was broken in early commits (duplicate `/rest/v1` path). Fixed in commit `eb82c88`. Telemetry confirmed operational after that commit.
- `_supa` is `null` if either key is missing — all telemetry and prediction calls gracefully no-op.

---

## 6. Replication Guide for New Cities

To stand up GOATvision for a different city, the primary changes are in `CITY_CONFIG` and `CONFIG`.

### Step 1: Replace `CITY_CONFIG` values
```javascript
const CITY_CONFIG = {
  lat: 47.6062,               // ← city center latitude
  lon: -122.3321,             // ← city center longitude
  timezone: 'America/Los_Angeles',

  // NOAA tide station — find at tidesandcurrents.noaa.gov/stations.html
  tideStationId: '9447130',

  // OneBusAway (if available) — or swap for a different transit API
  obaBaseUrl:       'https://api.pugetsound.onebusaway.org/api/where',
  transitAgencyId:  '40',

  // Airport
  airportCode: 'SEA',
  airportName: 'SEA-TAC',

  // Seattle Open Data fire dispatch — swap for city-specific dataset
  sfdUrl: 'https://data.seattle.gov/resource/kzjm-xkqj.json',

  snapshotLocationKey: 'SEA-TAC',

  // ESPN team IDs — find at site.api.espn.com
  teams: [
    { sport:'baseball',   league:'mlb',    id:28,   name:'Mariners',  venue:'T-Mobile Park' },
    // add teams for new city...
  ],

  coffeeShops: [ /* local shops for Coffee Index flavor text */ ],
  quotes:      [ /* city-themed quotes */ ],

  // WSDOT camera filter — only relevant for WA state
  cameraRoadName:      'SR 520',
  cameraLatMin:        47.50,
  cameraLatMax:        47.65,
  cameraTerminalOrder: ['bainbridge', 'bremerton', 'kingston'],
};
```

### Step 2: Replace `LINK_LINES`
Map the city's transit stops to OBA stop IDs (or swap the entire OBA integration for a different API).

### Step 3: Replace `FERRY_ROUTE_KEYWORDS`
Only relevant if the city has ferry service. Replace or remove entirely.

### Step 4: Replace `METRO_SCHEDULES`
Swap for city-specific bus routes and their headways.

### Step 5: Replace `LINK_MAP_STNS`
The SVG station coordinate data. May need to rebuild the schematic SVG for a different rail system.

### Step 6: Update `#trafficmap-panel` SVG
The traffic flow map SVG is hardcoded for Seattle corridors. Rebuild for the new city's highways.

### Step 7: Update `updateTrafficMap()` segment IDs
Change the `segs` array to match the new SVG element IDs and road names.

### Step 8: Update static panels
`#hospitals-panel`, `#vet-panel`, `#links-panel` are fully static HTML. Replace card content for the new city.

### Step 9: Supabase
Either reuse the same project (tables are city-agnostic) or create a new one and update `CONFIG.SUPABASE_URL` and `CONFIG.SUPABASE_ANON_KEY`. Run both migration SQL files in the new project's SQL Editor.

### Step 10: WSDOT-specific APIs
If the new city is outside Washington State, the WSDOT travel times, incidents, ferry, and camera APIs won't apply. Swap for equivalent regional APIs (e.g., Caltrans for California, TxDOT for Texas).

---

## 7. Known Issues and Limitations

### OBA rate limits
`OBA_KEY = 'TEST'` is rate-limited. With 7 stations across 1 Line and 2 Line, each 90-second fetch cycle fires 7 requests spaced 300ms apart (~2.1 seconds total). If OBA starts returning 429s, increase the throttle interval or obtain a production key.

### 2 Line train positions unavailable
The 2 Line route ID (`40_102576`) does not return position data through OBA. The link map legend notes this explicitly. There is no fix without a different data source.

### T Line not monitored
Tacoma Link Light Rail (`T Line`) has no OBA stop IDs assigned. Stop IDs are `null` in `LINK_LINES` and the line is excluded from the link map.

### CORS proxies are third-party
All three proxies (allorigins, corsproxy.io, codetabs) are free public services. They can go down, rate-limit, or change behavior at any time. The proxy chain retries all three before failing.

### Metro schedule is NOT live
King County Metro departures are purely cycle-based estimates derived from headway intervals. They are not pulled from OBA or GTFS-RT. The EST badge and footer warning communicate this, but it is still a common source of confusion.

### Scenic camera images are WSDOT JPEGs
Images are loaded directly from `cam.ImageURL` (no proxy needed). If WSDOT rotates the image hosting or adds CORS restrictions, the `<img>` src may stop working. The `onerror` handler shows a placeholder.

### Volcano API
`volcanoes.usgs.gov/vsc/api/volcanoInfo/` has no documented SLA. If it returns non-array data or goes offline, `fetchVolcano` falls back to static "Normal" status for all three volcanoes.

### Supabase anon key is public
The anon key in `CONFIG` is readable by anyone who opens devtools. This is expected and acceptable for public read/write. Do not store anything sensitive in Supabase, and do not upgrade the anon role to service_role.

### No offline mode
There is no service worker, no cached data, no graceful degradation beyond per-panel error messages. If a user opens the page offline, all dynamic panels show error states.

### Git workflow requires manual PATH setup each session
`C:\Program Files\Git\cmd` must be added to `$env:PATH` at the start of each PowerShell session:
```powershell
$env:PATH += ";C:\Program Files\Git\cmd"
```
The `GOATvision Seattle Claude.bat` launcher may handle this — check its contents.

### index.html sync is manual
`index.html` must be manually copied from `goatvision-seattle.html` before each commit:
```powershell
Copy-Item "goatvision-seattle.html" "index.html" -Force
```
Forgetting this step means GitHub Pages serves a stale version.

---

## 8. Sharing and Legal

### API terms
- **Open-Meteo:** Free for non-commercial use, no attribution required. Commercial use requires a subscription.
- **WSDOT APIs:** Public data from Washington State DOT. No commercial restrictions stated, but intended for public benefit.
- **OneBusAway:** Open API, TEST key is for development only. For production use, apply for a key at `api.pugetsound.onebusaway.org`.
- **Ticketmaster Discovery API:** Developer tier — limited to non-commercial personal projects. Keys are per-developer.
- **ESPN:** Unofficial public endpoint (`site.api.espn.com`) — not in official developer program. Use is at risk of being blocked without notice.
- **NOAA CO-OPS:** Public domain US government data.
- **USGS (earthquakes + volcanoes):** Public domain US government data.
- **FAA NAS Status:** Public domain US government data.
- **Seattle Open Data:** Open data under the City of Seattle's open data license.
- **Supabase:** Free tier — 500MB storage, 2GB bandwidth/month. If traffic grows, upgrade the project plan.

### Embedded API keys
All keys are visible in the HTML source. Do not post the HTML file to a public location with production keys unless you accept that anyone can scrape and reuse them.

### Logo and branding
`GOATvision Seattle™` — The ™ is informal. The logo (`GOATvision_Seattle_logo.png`) is a local asset.

---

## 9. What to Build Next

These are potential improvements roughly ordered by impact-to-effort ratio.

### High impact, moderate effort
1. **OBA production key** — Replace `TEST` with a real key to remove rate limit risk. Apply at `api.pugetsound.onebusaway.org`.
2. **Supabase baseline maturity badges** — Once enough data accumulates (>200 samples = `very_high` confidence), the `Hist:` badges in travel times become genuinely useful. Add a panel-level "data age" indicator so users know how mature the model is.
3. **Push alerts** — Use the Notification API or a PWA service worker to push critical ops brief bullets (ground stop, M4+ quake, severe NWS alert) as browser notifications.
4. **SFD live map** — Overlay active SFD incidents on a Leaflet or Mapbox map within the SFD panel (dispatch records include lat/lon in the Socrata API response).

### Medium impact, lower effort
5. **Automatic index.html sync** — Add a pre-commit hook or batch script that runs the `Copy-Item` automatically before `git push`.
6. **Ferry delay tracking** — Add a "minutes late" derived field from `scheduled_departure` vs. `actual_departure` in the ferry panel (data is available in the WSDOT API but currently unused in the UI).
7. **Dark/light mode toggle** — The dashboard is dark-only. Adding a `prefers-color-scheme` variant or a manual toggle button would be straightforward.
8. **Bicycle Index weather source** — Currently uses the same Open-Meteo call as weather. Could add `wind_gusts_10m` for more accuracy.
9. **Earthquake depth coloring** — Shallow quakes (<20km) are more felt than deep ones. Color-code or badge depth separately from magnitude.

### Exploratory / future
10. **Multi-city toggle** — Allow switching between `CITY_CONFIG` presets (Seattle, Portland, Tacoma) without leaving the page.
11. **Telemetry dashboard** — A second page or modal that visualizes the accumulated Supabase data as trend charts (traffic delta by hour, ferry delays by route, AQI by month).
12. **GTFS-RT direct integration** — Replace OBA schedule fallback with a direct GTFS-RT feed for Metro and Sound Transit for true real-time bus positions.
13. **Incident severity heat map** — Overlay WSDOT incidents on the traffic flow SVG schematic with colored markers.

---

## 10. Deployment Checklist

Use this checklist each time you push an update.

### Before editing
- [ ] Confirm working directory: `C:\Users\mjhin\OneDrive\Desktop\GOATvision Seattle`
- [ ] If using PowerShell: `$env:PATH += ";C:\Program Files\Git\cmd"`
- [ ] Read the current file state before editing (never edit from memory alone)

### After editing `goatvision-seattle.html`
- [ ] Verify the edit looks correct with `Read` (check changed lines)
- [ ] Sync to index.html: `Copy-Item "goatvision-seattle.html" "index.html" -Force`
- [ ] Stage both files: `git add goatvision-seattle.html index.html`
- [ ] If any other files changed (migrations, docs): `git add .`
- [ ] Commit with a specific message: `git commit -m "brief description of what changed"`
- [ ] Push: `git push`
- [ ] Verify push succeeded (no error output, branch shows updated commit)

### After adding a new Supabase table or function
- [ ] Run the migration SQL in Supabase Dashboard → SQL Editor → New query
- [ ] Confirm no errors in SQL Editor output
- [ ] Verify RLS policies exist for anon read and anon insert
- [ ] Save the migration SQL to `supabase/migrations/YYYYMMDD_description.sql`
- [ ] Commit the migration file

### Periodic health checks
- [ ] WSDOT key — confirm travel times and ferry are returning data (not 401)
- [ ] OBA TEST key — confirm arrival data is loading (watch for 429 errors in console)
- [ ] Supabase — Dashboard → Table Editor → check rows are accumulating in all four v2 tables
- [ ] CORS proxies — if panels are failing, check browser console for proxy errors and which fallback succeeded
- [ ] GitHub Pages — confirm `index.html` at the Pages URL reflects the latest commit

---

*End of GOATVISION_SEATTLE_V3.md — generated May 26 2026 from direct code reads.*
