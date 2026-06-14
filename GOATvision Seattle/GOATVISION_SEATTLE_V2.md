# GOATvision Seattle — Complete Project Reference (V2)

> **File:** `goatvision-seattle.html` (single-file, no build toolchain)
> **Deployment:** Vercel static hosting — `index.html` at repo root kept in sync
> **Last updated:** May 2026

---

## SECTION 1 — PROJECT SUMMARY

GOATvision Seattle is a single-page city intelligence dashboard that aggregates live public data feeds into one read-at-a-glance view. It is a single self-contained `.html` file with no npm, no build step, no framework, and no server-side code. Open the file in a browser and it runs.

**Design philosophy:** Every piece of information on screen either came from a real API call in the last few minutes, or from a deterministic calculation (schedule estimator, index scoring) that is clearly labeled as such. Nothing is made up.

**Visual style:** Dark terminal aesthetic — near-black background (`#0b0d0f`), monospace fonts (IBM Plex Mono + system monospace), color-coded status dots (green / amber / red / gray), subtle glow effects.

**Tech:** Vanilla HTML + CSS + JavaScript (ES2020). Zero dependencies, zero node_modules. Runs in any modern browser.

---

## SECTION 2 — LIVE DATA SOURCES

### API Keys

| Key | Where it lives | Required? |
|---|---|---|
| `CONFIG.WSDOT_KEY` | Hardcoded in `CONFIG` block (line ~1116) | **Yes** — all WSDOT calls (traffic, incidents, ferry, cameras) need this |
| `CONFIG.OBA_KEY` | Set to `'TEST'` — OBA public test key | Soft — TEST key is rate-limited (~30 req/min); get a real key for production |
| `CONFIG.TICKETMASTER_KEY` | Hardcoded | Optional — events panel falls back to ESPN-only without it |
| `CONFIG.SUPABASE_URL` / `CONFIG.SUPABASE_ANON_KEY` | Hardcoded (currently blank strings) | Optional — historical baseline feature inactive until populated |

### Data Sources by Panel

| Panel | Source | Endpoint / API | Key Required | CORS |
|---|---|---|---|---|
| Weather | Open-Meteo | `api.open-meteo.com/v1/forecast` | No | Yes (no proxy) |
| Air Quality | Open-Meteo | `air-quality-api.open-meteo.com/v1/air-quality` | No | Yes |
| NWS Alerts | National Weather Service | `api.weather.gov/alerts/active?point=` | No | Yes |
| Highway Travel Times | WSDOT | `wsdot.wa.gov/Traffic/api/TravelTimes/...` | `WSDOT_KEY` | Via proxy |
| Highway Incidents | WSDOT | `wsdot.wa.gov/Traffic/api/HighwayAlerts/...` | `WSDOT_KEY` | Via proxy |
| Ferry Status | WSDOT Ferries | `wsdot.wa.gov/ferries/api/vessels/rest/vessellocations` | `WSDOT_KEY` | Via proxy |
| Scenic Cameras | WSDOT | `wsdot.wa.gov/Traffic/api/HighwayCameras/...` | `WSDOT_KEY` | Via proxy |
| Link Rail Arrivals | OneBusAway Puget Sound | `api.pugetsound.onebusaway.org/api/where/arrivals-and-departures-for-stop/` | `OBA_KEY` | Yes (no proxy) |
| King County Metro | Static schedule estimator | — (no API call) | No | N/A |
| Seattle Fire Dispatch | Seattle Open Data | `data.seattle.gov/resource/kzjm-xkqj.json` | No | Yes |
| Sports Events | ESPN public API | `site.api.espn.com/apis/site/v2/sports/...` | No | Yes (direct + proxy fallback) |
| Events (concerts etc.) | Ticketmaster Discovery API | `app.ticketmaster.com/discovery/v2/events.json` | `TICKETMASTER_KEY` | Yes |
| NOAA Tide | NOAA CO-OPS | `api.tidesandcurrents.noaa.gov/api/prod/datagetter` | No | Yes |
| Earthquakes | USGS FDSN | `earthquake.usgs.gov/fdsnws/event/1/query` | No | Yes |
| Volcano Status | USGS Volcano Hazards | `volcanoes.usgs.gov/vsc/api/volcanoInfo/` | No | Yes |
| SEA-TAC Airport | FAA NAS Status | `nasstatus.faa.gov/api/airport-status-information/airport-delay-groups` | No | Via proxy |
| Historical Baselines | Supabase | Custom `condition_snapshots` table | `SUPABASE_ANON_KEY` | Yes |

### CORS Proxy System

WSDOT and FAA endpoints don't send CORS headers. All WSDOT fetches go through `wsdotFetch(url)`, which tries a 4-URL chain:

```
1. https://corsproxy.io/?<encoded-url>
2. https://api.allorigins.win/raw?url=<encoded-url>
3. https://api.codetabs.com/v1/proxy/?quest=<encoded-url>
4. <direct URL> (works in environments with no CORS enforcement)
```

`fetchSEA()` (FAA airport status) uses the same 4-proxy chain with `AbortSignal.timeout(5000)` per attempt. First non-empty 200 response wins.

ESPN fetches try direct first, then fall back to `wsdotFetch()`.

### Refresh Intervals

| Data Type | Refresh Cadence |
|---|---|
| Weather + Air Quality | Every 5 minutes |
| NWS Alerts | Every 5 minutes |
| Highway Travel Times | Every 2 minutes |
| Highway Incidents | Every 2 minutes |
| Ferry vessel positions | Every 2 minutes |
| Seattle Fire Dispatches | Every 5 minutes |
| Link Rail arrivals (OBA) | Every 90 seconds |
| Link Rail vehicle positions | Every 60 seconds (derived from arrivals data) |
| Metro schedule display | Every 60 seconds (recalculates next departures) |
| Scenic cameras (image refresh) | Every 60 seconds |
| Scenic cameras (list re-fetch) | Every 10 minutes |
| NOAA Tide | Every 10 minutes |
| Earthquakes | Every 5 minutes |
| Volcano status | Every 30 minutes |
| SEA-TAC airport status | Every 5 minutes |
| Sports/events schedule | Every 60 minutes |
| Ops Brief synthesis | Every 2 minutes |

---

## SECTION 3 — PANEL BY PANEL BREAKDOWN

### Header Strip

- City name, live clock (updates every second), date line
- `startClock()` runs `setInterval` at 1000ms
- Quote of the day — `CITY_CONFIG.quotes` array, seeded daily (same quote all day)

### Ops Brief

Rule-based synthesis panel — evaluates up to 9 signal categories and writes plain-English bullets. Runs 2 seconds after init (to let panels populate) then every 2 minutes.

Categories evaluated:
1. **Traffic** — worst WSDOT travel time segment vs. average; threshold: +15 min = red, +5 min = amber
2. **Weather current** — precip probability >60% or wind >20 mph = amber
3. **Drive window** — hourly forecast scores from weather; finds degradation/recovery edges
4. **Ferry** — checks if vessel data is missing for any of the 4 monitored routes
5. **Link Rail** — live predictions available vs. schedule-only
6. **Events today** — home games or concerts at major venues
7. **Rainier visibility** — inferred from cloud cover and weather code
8. **NWS Alerts** — highest-severity active alert headline
9. **SFD Fire/Hazmat** — elevated if >3 fire/hazmat incidents in last 2 hours

Status dots on each bullet: green dot, amber dot, red dot (CSS `.ops-indicator`).

Readiness gating: if fewer than 3 data sources have loaded (`_brief` flags), shows "Awaiting data streams…" instead.

### Weather

Source: Open-Meteo `forecast` endpoint. Fetches current conditions + hourly forecast for 12 hours.

**Rendered content:**
- Current: temperature (°F), feels-like, humidity, precipitation probability, wind speed/direction, cloud cover, weather description
- `wmoDesc(code)` maps WMO weather codes to human-readable strings
- `wmoSeverity(code)` returns 0.0–1.0 severity scale (used by ops brief and other panels)
- Drive Window: 12-hour bar chart of composite driving conditions (traffic delay ratio + weather severity combined)
- `driveWindowScores` — module-level array populated by `fetchWeather()`, consumed by ops brief
- Dot: green if clear, amber if rain likely, red if severe weather

### Air Quality

Source: Open-Meteo air quality API. Shows US AQI (calculated from PM2.5, PM10, ozone, NO2).

**Rendered content:**
- AQI number + category (Good / Moderate / Unhealthy for Sensitive Groups / Unhealthy / Hazardous)
- Color-coded badge by AQI level
- Fires/smoke toggle information when AQI is elevated (inferred from PM2.5 vs. ozone ratio)
- `snapshotCondition('aqi', ...)` called if Supabase is configured

### NWS Weather Alerts

Source: NWS API `alerts/active?point=47.6062,-122.3321`. No key required.

**Rendered content:**
- If no active alerts: green check mark "No active NWS alerts for Seattle area"
- If alerts: each alert as a card with severity badge, event name, headline, area description
- Severity color: Extreme/Severe = red, Moderate = amber, Minor = green

### Highway Travel Times

Source: WSDOT Travel Times API. Filtered to bounding box 47.30–47.85°N, 122.55–121.60°W. HOV/Express Lane segments filtered out.

**Rendered content:**
- Road filter tabs: ALL / I-5 / I-90 / SR-520 / I-405 / SR-522
- Each segment row: road + direction arrow, segment name, current time (min), average time (min), badge (ON TIME / +Xm)
- Color: green ≤110% of average, amber ≤150%, red >150%
- Historical baseline column: `getHistoricalBaseline()` pulls 7-day average from Supabase `condition_snapshots` (shows "7d avg: Xm" if available, falls back to "avg Xm")
- Traffic Flow Map: SVG schematic of I-5, I-90, SR-520, I-405 colored by travel time ratios. Updated by `updateTrafficMap()` whenever travel times fetch completes.

### Highway Incidents

Source: WSDOT HighwayAlerts API. Same CORS proxy chain as travel times.

**Rendered content:**
- Up to 30 incidents sorted by severity: HIGH (closure/serious), MEDIUM (construction/accident), LOW (everything else)
- Each row: severity badge, road name + direction, headline description, location, start time

### Ferry Status

Source: WSDOT Ferries vessel locations API. Monitors 4 routes:
- Mukilteo / Clinton
- Seattle / Bainbridge Island
- Fauntleroy / Vashon Island / Southworth
- Point Defiance / Tahlequah

**Rendered content:**
- Each route: vessel name, at-dock vs. underway status, speed in knots, ETA or departure time
- Progress bar: GPS-based position (Haversine distance from departure terminal ÷ total route distance). Falls back to time-based (elapsed since left dock ÷ total crossing time) when coordinates unavailable.
- `shortTerm()` strips "Island", "Terminal" from terminal names for compact display

### Scenic Cameras (Ferry Cams)

Source: WSDOT HighwayCameras API, filtered to `cameraRoadName: 'Ferries'` and lat range specified in `CITY_CONFIG`.

**Rendered content:**
- Grid of camera thumbnails (clickable to expand in lightbox)
- `fetchScenicCams()` selects one camera per terminal (using `cameraTerminalOrder` keywords from `CITY_CONFIG`), then fills remaining slots with any unused cameras
- Images are cache-busted with `?_t=Date.now()` on every refresh
- `refreshAllCams()` re-loads images every 60s without re-fetching the camera list

### Link Light Rail Arrivals

Source: OneBusAway Puget Sound API. Fetches `arrivals-and-departures-for-stop` for all stops in `LINK_KEY_STOPS`, throttled at 300ms between requests.

**Panel structure:**

Route diagram strip at top showing all 3 lines (1 Line / 2 Line / T Line) with official Sound Transit colors.

3-column layout — one column per line:

**1 Line** (blue `#00a1de`) — Lynnwood ↔ Federal Way via Downtown Seattle & SeaTac
- 8 key stops: Lynnwood City Center, Northgate, U District, Capitol Hill, Westlake, SODO, SeaTac/Airport, Federal Way

**2 Line** (red `#e31837`) — Downtown Redmond ↔ Intl District via Bellevue
- 6 stops: Downtown Redmond, Redmond Technology, Overlake Village, Bellevue Downtown, Mercer Island, Intl Dist/Chinatown

**T Line** (purple `#6f2c91`) — Tacoma Dome ↔ Hilltop
- 3 stops listed (no OBA data — T Line not in Puget Sound OBA feed; shows "—" for all)

Each station row shows: next arrival in minutes (green "NOW" if ≤1 min, no color if >5 min), superscript `s` if scheduled (no live prediction), destination headsign.

Footer note: `s = scheduled (no live prediction) · T Line not in OBA feed`

**Internal data flow:**
- `_transitArrivals` — module-level array of raw OBA arrival objects (with `tripStatus.position.lat/lon` included)
- Populated by `fetchTransit()`, consumed by `fetchLinkVehicles()` for vehicle positions
- This means vehicle position data costs zero additional API calls

### Link Light Rail Live Map

Schematic SVG map (`720×460` viewBox). Shows:

**1 Line:** Vertical track at `x=200`, `y=20` (Lynnwood) to `y=435` (Federal Way). 23 stations.

**2 Line:** Polyline branching east (northeast geometry) from `x=300,y=395` through 8 stations to `x=590,y=260` (Downtown Redmond).

**Station types:**
- Transfer stations (`ix:true`): white circle with colored border, radius 7
- Regular stations (`ix:false`): colored dot on background, radius 4

**Label placement:** `ls` property on each station — `'r'` (right), `'l'` (left), `'b'` (below), `'a'` (above). Override with `lx`/`ly` for custom positioning, `lsize` for custom font size.

**Live vehicles:** `fetchLinkVehicles()` reads `_transitArrivals`, extracts `tripStatus.position.lat/lon` for each unique trip on route `40_100479` (1 Line) or `40_102576` (2 Line). Deduplicates by `tripId`. Converts GPS coordinates to SVG coords via:
```javascript
function lmLatToY(lat) { return ((47.92 - lat) / (47.92 - 47.15)) * 620 + 30; }
function lmLonToX(lon) { return ((lon - (-122.45)) / ((-122.10) - (-122.45))) * 520 - 20; }
```
Vehicle direction arrow inferred from `tripHeadsign` text.

T Line note at SVG bottom: "T Line (Tacoma Link) operates as a separate system · not shown"

### King County Metro Bus

No API calls. Static frequency table (`METRO_SCHEDULES`) with 8 key routes:

| Route | Description | Peak | Off-Peak | Night |
|---|---|---|---|---|
| 7 | Prentice St / Rainier Beach | 10 min | 15 min | 30 min |
| 8 | Mt Baker / Uptown | 12 min | 15 min | 30 min |
| 40 | Northgate / South Lake Union | 10 min | 15 min | 20 min |
| 44 | Ballard / Montlake | 12 min | 15 min | 30 min |
| 48 | U District / Columbia City | 12 min | 15 min | 30 min |
| 62 | Sand Point / Downtown | 12 min | 15 min | 30 min |
| 101 | Renton / Downtown Seattle | 10 min | 20 min | 30 min |
| 150 | Kent / Downtown Seattle | 10 min | 20 min | 30 min |

**Time periods:**
- Peak: weekdays 6–9 AM and 3–7 PM
- Night: weekends all day, or weekdays before 6 AM / after 10 PM
- Off-peak: everything else

`getNextDepartures(freqMins)` uses elapsed time within the current frequency cycle to estimate next 3 departures. Dot set to amber (schedule only — no live data).

### Seattle Fire Dispatch

Source: Seattle Open Data portal, SFD CAD dispatches endpoint, last 2 hours.

**Rendered content:**
- Summary grid: dispatch counts by category (Fire, Medical, Aid, Alarm, etc.)
- List of up to 25 most recent dispatches: type badge, street name (block numbers stripped), time
- `sfdCategory(type)` maps raw dispatch type strings to display categories + CSS classes
- `snapshotCondition('traffic', ...)` not called here — this feed is local to SFD panel

### Seattle Events & Sports

Sources: ESPN public API (sports team schedules) + Ticketmaster Discovery API (concerts/events).

**ESPN:** Fetches schedule for all 5 teams in `CITY_CONFIG.teams` (Mariners, Seahawks, Sounders, Kraken, Storm). Home games only (away games don't impact Seattle traffic). 14-day lookahead.

**Ticketmaster:** 50 events, 15-mile radius, 14-day lookahead. Filters out ballpark tours, sightseeing events, and admin/team events. Deduplicates against ESPN events by date + venue key. Venue-based traffic impact classification:
- LARGE_VENUES (Climate Pledge, T-Mobile Park, Lumen Field, etc.) → HIGH impact
- SMALL_VENUES (Neumos, Tractor Tavern, Crocodile, etc.) → LOW impact
- Default → MEDIUM

**Rendered content:**
- Chronological list grouped by date
- MULTI-EVENT DAY banner when multiple events fall on same day
- Traffic impact badge: SEVERE (multi-event day) / HIGH / MED / LOW
- Sport emoji by classification: ⚾ ⚽ 🏈 🏒 🏀 🎤 🎭 😂 🤼 🥊 🎪 🎟️

### Coffee Index

Composite demand score (0–100) calculated entirely from other panels' data. No separate API call.

**Inputs:** current weather (code, temp, precipitation probability, wind), day of week, time of day, federal holidays, traffic ratio from WSDOT travel times, home game today from events data.

**Score bands:** CRITICAL ≥85, ELEVATED ≥65, MODERATE ≥40, NOMINAL <40.

**Daily coffee shop rotation:** 3 shops selected daily from `CITY_CONFIG.coffeeShops` (22 entries) using seeded Fisher-Yates shuffle (seed = `year * 1000 + dayOfYear`). Same 3 shops all day, different set each calendar day.

Wait time estimates: synthetic (high demand = 14/9/5 min, moderate = 5/3/0 min, nominal = 0).

### Bicycle Index

Composite ridability score (0–100) from 4 factors, each scored 0–25:

| Factor | Full score condition |
|---|---|
| Temperature | 55–75°F = 25 pts |
| Wind | ≤8 mph = 25 pts |
| Precipitation probability | ≤15% = 25 pts |
| WMO weather severity | 0 severity = 25 pts |

Labels: GO (≥75), DECENT (≥50), ROUGH (≥30), STAY IN (<30). Pip indicators (●●●, ●●○, ●○○, ○○○) per factor.

### Puget Sound Tide

Source: NOAA CO-OPS predictions API, station `9447130` (Seattle). MLLW datum, today + tomorrow, high/low only.

**Rendered content:**
- Current water level (interpolated from most recent past prediction)
- Rising ▲ or Falling ▼ trend
- Next 6 high/low predictions; past predictions shown at 45% opacity

### Seismic & Volcanic

**Earthquakes:** USGS FDSN query, M1.5+, 300 km radius from Seattle center, last 8 events. Dot: red if max ≥M4.0, amber if max ≥M2.5, green otherwise.

**Volcanoes:** USGS Volcano Hazards API. Monitors: Mount Rainier, Mount Baker, Mount St. Helens. Alert levels: Normal (green), Advisory (amber), Watch/Warning (red). Static fallback to "Normal" if API unavailable.

### SEA-TAC Airport Status

Source: FAA NAS Status API, XML response. Parses `<Delay_type>` elements, finds any with `<ARPT>` = "SEA". Extracts delay name, reason, and average delay duration.

4-proxy retry chain with 5s timeout per attempt. Dot: green (no delays), amber (delay active), red (ground stop), gray (data unavailable).

---

## SECTION 4 — ARCHITECTURE

### File Structure

```
GOATvision Seattle/
├── goatvision-seattle.html    ← Primary development file (all code here)
├── index.html                 ← Vercel deployment target (kept in sync)
├── GOATVISION_PROJECT_OVERVIEW.md
├── GOATVISION_SEATTLE_V2.md   ← This file
└── supabase/
    └── migrations/
        └── 20260525_condition_snapshots.sql
```

**There is no `src/`, no `package.json`, no `node_modules`.** Everything is in the one HTML file.

### Module-Level State Variables

These live at script scope and are read by multiple functions:

```javascript
let weatherData          = null;    // Open-Meteo current + hourly response
let driveWindowScores    = [];      // 12-hour drive condition scores [{label, score}]
let allTravelTimes       = [];      // WSDOT travel time segments (filtered)
let ttRoadFilter         = 'ALL';   // Active road tab filter
let ttFetchedAt          = null;    // Date of last travel times fetch
let ferryVessels         = [];      // WSDOT vessel location array
let eventsData           = [];      // Merged ESPN + Ticketmaster events
let sfdDispatches        = [];      // SFD CAD dispatch array
let nwsAlerts            = [];      // NWS alert GeoJSON features
let scenicCams           = [];      // WSDOT camera objects
let _seismicQuakes       = null;    // USGS earthquake features
let _volcanoStatuses     = null;    // Volcano alert status array
let _transitArrivals     = [];      // Raw OBA arrival objects (with tripStatus.position)
let transitHasLivePredictions = false;

// Ops Brief readiness flags
const _brief = { weather:false, tt:false, ferry:false, transit:false, events:false, nws:false, sfd:false };
```

### CITY_CONFIG — The Portability Layer

All Seattle-specific values live here. To replicate for another city, replace this object:

```javascript
const CITY_CONFIG = {
  name:            'Seattle',
  lat:             47.6062,
  lon:             -122.3321,
  timezone:        'America/Los_Angeles',
  tideStationId:   '9447130',         // NOAA station ID
  tideLabel:       'Elliott Bay · MLLW',
  obaBaseUrl:      'https://api.pugetsound.onebusaway.org/api/where',
  transitAgencyId: '40',              // OBA agency ID
  airportCode:     'SEA',             // FAA airport code (3-letter)
  airportName:     'Seattle-Tacoma International',
  sfdUrl:          'https://data.seattle.gov/resource/kzjm-xkqj.json',
  snapshotLocationKey: 'SEA-TAC',
  cameraRoadName:  'Ferries',
  cameraLatMin:    47.3,
  cameraLatMax:    48.0,
  cameraTerminalOrder: ['seattle','edmonds','mukilteo','fauntleroy','point defiance','southworth','vashon','clinton','bainbridge'],
  teams:           [ /* 5 ESPN team objects with sport/league/id/name/venue/color */ ],
  quotes:          [ /* 20 Seattle-specific quote strings */ ],
  coffeeShops:     [ /* 22 {name, hood} objects */ ],
};
```

### Fetch Helper Pattern

All WSDOT/proxy fetches use `wsdotFetch(url)`:
```javascript
async function wsdotFetch(url) {
  const PROXIES = [corsproxy, allorigins, codetabs, direct];
  for (const proxy of PROXIES) {
    try { ... return await res.json(); } catch(e) { continue; }
  }
  throw new Error('All proxies failed');
}
```

OBA fetches use `obaFetch(path)` which appends `?key=OBA_KEY` and validates the `data.data` envelope.

### Status Dot System

Every panel has a colored LED (`setDot(id, color)`):
- `green` — live data loaded successfully
- `amber` — degraded (schedule-only, partial data, or soft error)
- `red` — fetch failed
- `gray` — data unavailable by design (e.g., FAA returned no response)

### Supabase Historical Baselines (Optional)

Two functions wrap all Supabase interaction:

- `snapshotCondition(category, location_key, value, raw_json)` — INSERT a row into `condition_snapshots`. Called by travel times (`fetchTravelTimes`) and air quality (`fetchAirQuality`).
- `getHistoricalBaseline(category, location_key)` — SELECT the last 7 days of snapshots, return `{ avg, min, max, count }`. Used by `renderTravelTimes()` to show "7d avg: Xm".

If `CONFIG.SUPABASE_URL` is empty, both functions return `null` silently. The rest of the UI adapts — travel times show "avg Xm" (from WSDOT's own average) instead of the 7-day baseline.

The SQL migration at `supabase/migrations/20260525_condition_snapshots.sql` creates the table with anon read/write RLS policy (no auth).

---

## SECTION 5 — REPLICATION GUIDE

To clone this dashboard for a different city:

### Step 1 — Replace CITY_CONFIG

Update every field in `CITY_CONFIG`:
- `lat`/`lon` — city center coordinates (used for weather, NWS, earthquake radius)
- `timezone` — IANA timezone string
- `tideStationId` — look up at tidesandcurrents.noaa.gov/stations.html
- `obaBaseUrl` + `transitAgencyId` — find your city's OBA API instance (many cities have one)
- `airportCode` — 3-letter FAA code (e.g. `LAX`, `ORD`)
- `sfdUrl` — Socrata open data endpoint for local fire dispatch (varies by city)
- `cameraRoadName`/`cameraLatMin`/`cameraLatMax` — WSDOT-specific; replace entire camera logic for non-WA cities
- `teams` — update ESPN team IDs (find at `site.api.espn.com/apis/site/v2/sports/...`)
- `quotes`, `coffeeShops` — replace with city-specific content

### Step 2 — Replace WSDOT Calls

WSDOT APIs are Washington-specific. For other states:
- **Travel times:** Find state DOT API or use Google Maps Distance Matrix API (requires key)
- **Incidents:** Check state DOT or 511 APIs; many follow similar REST patterns
- **Ferry:** Remove or replace with local ferry authority API
- **Cameras:** WSDOT camera API is specific; other DOTs have similar endpoints

### Step 3 — Replace Link Light Rail Panel

- Update `LINK_LINES` with local transit line configuration
- Update `LINK_KEY_STOPS` with local OBA stop IDs (prefix `AGENCY_ID_` before stop number)
- Update `LINK_MAP_STNS` with schematic coordinates for your city's system
- Update `LINK_VEHICLE_ROUTES` route IDs for `fetchLinkVehicles()`

### Step 4 — Replace Static Lists

- `METRO_SCHEDULES` — update with local key bus routes
- `FERRY_ROUTE_KEYWORDS` — remove or replace with local ferry routes
- `CITY_CONFIG.coffeeShops` — replace with 20–30 local coffee shops by neighborhood

### Step 5 — Update CONFIG

Get a fresh WSDOT key (or equivalent state DOT key), new Ticketmaster key, and optionally a real OBA key.

### Step 6 — CSS Tweaks

The dashboard has no city-specific CSS. The only city-specific visual element is the quote strip. Everything else adapts from `CITY_CONFIG`.

---

## SECTION 6 — KNOWN ISSUES AND LIMITATIONS

### OBA Test Key Rate Limiting

`CONFIG.OBA_KEY = 'TEST'` — the OBA public test key allows ~30 requests per minute. `fetchTransit()` makes up to 14 OBA calls (one per stop in `LINK_KEY_STOPS`), throttled at 300ms apart = ~4.2 seconds total. Under normal conditions this is fine, but if multiple browser tabs are open or refresh intervals overlap, you may hit the rate limit. Fix: register for a real OBA API key at api.pugetsound.onebusaway.org.

### T Line Has No OBA Data

The T Line (Tacoma Link) is operated on a separate OBA instance or is not included in the Puget Sound OBA feed. All T Line stops have `stopId: null` and show "—" in the arrivals panel. The live map explicitly excludes T Line vehicles. This is a data availability limitation, not a code bug.

### Link Rail Vehicle Positions Depend on OBA Trip Status

`fetchLinkVehicles()` extracts vehicle positions from `tripStatus.position` within OBA arrival objects. OBA only includes `tripStatus` when a trip is actively running (vehicle has departed). Scheduled future trips don't carry position data. This means: during off-peak hours or if OBA's real-time feed is stale, the map may show 0 active trains even though trains are running. The "No live vehicle data available" message in the map legend covers this case.

### CORS Proxy Reliability

The 4-proxy chain helps but is not foolproof:
- `corsproxy.io` — occasionally rate-limits heavy users or returns errors for some domains
- `allorigins.win` — may be slow or down
- `codetabs.com` — least reliable of the three; the direct fallback rarely works from browsers due to missing CORS headers

If all proxies fail for WSDOT data, the affected panel shows a red error message. Travel times and incidents are the most impactful; ferry and cameras degrade gracefully.

### FAA Airport Data is XML

The NAS Status API returns XML, not JSON. The XML parser is handled by the browser's built-in `DOMParser`. If the XML structure changes upstream, `fetchSEA()` may silently return "No active delays" even during an actual ground stop. The proxy chain also adds latency; the 5-second timeout per proxy means total wait time can reach 20 seconds if 3 proxies fail.

### Supabase Historical Baselines Currently Inactive

`CONFIG.SUPABASE_URL` and `CONFIG.SUPABASE_ANON_KEY` are blank strings. The `snapshotCondition()` and `getHistoricalBaseline()` functions exist and are wired up in the code, but do nothing until keys are populated. To activate: create a Supabase project, run the migration SQL, paste the project URL and anon key into CONFIG.

### Metro Schedule Estimator is an Approximation

`METRO_SCHEDULES` contains hardcoded frequency values based on typical published schedules. Actual real-time arrivals are not fetched. The "next departure" calculation assumes perfectly even headways (every N minutes). Reality: buses are not evenly spaced. Treat as a rough guide, not a live prediction. The dot is amber by design.

### Ticketmaster Events May Overlap With ESPN

Deduplication between ESPN sports events and Ticketmaster events uses a key of `localDate + venue.slice(0,12)`. This catches most duplicates but can miss cases where Ticketmaster uses a slightly different venue name. When duplicates slip through, the event appears twice in the list.

### Volcano API Response Shape May Vary

`fetchVolcano()` handles multiple possible field name variants (`alert_level`, `alertLevel`, `alert`; `pub_date`, `updated`, `lastUpdate`) because the USGS API response shape has shifted in the past. If USGS changes the API again, the static fallback (Normal for all three) activates silently.

---

## SECTION 7 — DEPLOYMENT

### Current Setup

- Git remote: `origin` = GitHub repo
- Local branch: `master` (tracks `origin/main`)
- Vercel watches `origin/main` and deploys automatically on push
- Deployed as a static site (no serverless functions)

### Sync and Deploy Workflow

```powershell
# 1. Add git to PATH if needed (only required once per session)
$env:PATH += ";C:\Program Files\Git\cmd"

# 2. Navigate to project
cd "C:\Users\mjhin\OneDrive\Desktop\GOATvision Seattle"

# 3. Sync index.html from the development file
Copy-Item "goatvision-seattle.html" "index.html" -Force

# 4. Stage, commit, push
git add -A
git commit -m "describe what changed"
git push origin HEAD:main
```

Vercel deploys automatically within ~30 seconds of the push landing on `origin/main`.

### Local Development

No build step. Open `goatvision-seattle.html` directly in a browser:

```powershell
Start-Process "C:\Users\mjhin\OneDrive\Desktop\GOATvision Seattle\goatvision-seattle.html"
```

Or drag the file into a browser window.

Some APIs (NOAA tide, USGS, OBA, Open-Meteo, ESPN) work fine from `file://`. WSDOT calls go through proxies and work from file too. Ticketmaster requires a deployed URL for its API key domain restrictions in some configurations.

### index.html vs. goatvision-seattle.html

`goatvision-seattle.html` is the working file — edit this one. `index.html` is the Vercel entry point. They must be kept identical. Always run the `Copy-Item -Force` sync step before every git push. There is no automated sync; it is a manual step.

### No Environment Variables

There is no `.env` file. All keys are hardcoded directly in the `CONFIG` block inside the HTML file. This is intentional for a simple single-file static deployment — there is no build step to inject env vars. The WSDOT key is not a secret in practice (it's a public data API). The Ticketmaster key has rate limits but is not secret-sensitive. If this were a production build with sensitive keys, a Vercel serverless proxy function would be the appropriate solution.

### Supabase (Optional)

To activate the historical baselines feature:
1. Create a Supabase project at supabase.com
2. Run `supabase/migrations/20260525_condition_snapshots.sql` in the Supabase SQL Editor
3. Copy the Project URL and anon key into `CONFIG.SUPABASE_URL` and `CONFIG.SUPABASE_ANON_KEY`
4. Sync and deploy

Data will accumulate in `condition_snapshots` on every travel times and AQI fetch. After 7+ days, the "7d avg" baseline column in the travel times panel will populate.
