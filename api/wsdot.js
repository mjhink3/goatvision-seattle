const ENDPOINTS = {
  alerts:         'https://www.wsdot.wa.gov/Traffic/api/HighwayAlerts/HighwayAlertsREST.svc/GetAlertsAsJson',
  'travel-times': 'https://www.wsdot.wa.gov/Traffic/api/TravelTimes/TravelTimesREST.svc/GetTravelTimesAsJson',
  cameras:        'https://www.wsdot.wa.gov/Traffic/api/HighwayCameras/HighwayCamerasREST.svc/GetCamerasAsJson',
  ferries:        'https://www.wsdot.wa.gov/ferries/api/vessels/rest/vessellocations',
  // WSF Terminals — real-time vehicle capacity per sailing, confirmed live to need no
  // access code (same as schedule below). Static URL, no date/routeId path, so unlike
  // schedule it fits the existing map directly.
  sailingspace:   'https://www.wsdot.wa.gov/ferries/api/terminals/rest/terminalsailingspace',
  // WSF Vessels — published fleet specs (RegDeckSpace etc.), used as static background
  // capacity where terminalsailingspace has no live coverage at all (e.g. the
  // Fauntleroy/Vashon/Southworth triangle). Also confirmed live to need no access code.
  vesselspecs:    'https://www.wsdot.wa.gov/ferries/api/vessels/rest/vesselverbose',
};
const NO_KEY_ENDPOINTS = new Set(['sailingspace', 'vesselspecs']); // confirmed live: neither needs a key/param
const KEY_PARAM = { ferries: 'apiaccesscode' }; // WSDOT uses a different param name for this one endpoint

export default async function handler(req, res) {
  const type = req.query.type;

  // WSF Schedule — separate product from the vessel-locations endpoint above, confirmed
  // live to need no access code at all (tested with and without one, identical result).
  // Needs a date + routeId path, not a static base URL, so it can't reuse the ENDPOINTS map.
  if (type === 'schedule') {
    const { date, routeId } = req.query;
    if (!date || !routeId) return res.status(400).json({ error: 'Missing date or routeId' });
    try {
      const response = await fetch(`https://www.wsdot.wa.gov/ferries/api/schedule/rest/schedule/${date}/${routeId}`);
      if (!response.ok) throw new Error(`WSF Schedule request failed: HTTP ${response.status}`);
      const data = await response.json();
      res.setHeader('Cache-Control', 's-maxage=300, stale-while-revalidate=600'); // schedules rarely change within a day
      return res.status(200).json(data);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  }

  const base = ENDPOINTS[type];
  if (!base) return res.status(400).json({ error: 'Unknown or missing type' });

  const url = NO_KEY_ENDPOINTS.has(type) ? base : `${base}?${KEY_PARAM[type] || 'AccessCode'}=${process.env.WSDOT_KEY}`;
  try {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`WSDOT request failed: HTTP ${response.status}`);

    const data = await response.json();
    res.setHeader('Cache-Control', 's-maxage=60, stale-while-revalidate=300');
    res.status(200).json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}
