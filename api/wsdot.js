const ENDPOINTS = {
  alerts:         'https://www.wsdot.wa.gov/Traffic/api/HighwayAlerts/HighwayAlertsREST.svc/GetAlertsAsJson',
  'travel-times': 'https://www.wsdot.wa.gov/Traffic/api/TravelTimes/TravelTimesREST.svc/GetTravelTimesAsJson',
  cameras:        'https://www.wsdot.wa.gov/Traffic/api/HighwayCameras/HighwayCamerasREST.svc/GetCamerasAsJson',
  ferries:        'https://www.wsdot.wa.gov/ferries/api/vessels/rest/vessellocations',
};
const KEY_PARAM = { ferries: 'apiaccesscode' }; // WSDOT uses a different param name for this one endpoint

export default async function handler(req, res) {
  const type = req.query.type;
  const base = ENDPOINTS[type];
  if (!base) return res.status(400).json({ error: 'Unknown or missing type' });

  const param = KEY_PARAM[type] || 'AccessCode';
  try {
    const response = await fetch(`${base}?${param}=${process.env.WSDOT_KEY}`);
    if (!response.ok) throw new Error(`WSDOT request failed: HTTP ${response.status}`);

    const data = await response.json();
    res.setHeader('Cache-Control', 's-maxage=60, stale-while-revalidate=300');
    res.status(200).json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}
