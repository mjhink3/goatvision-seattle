export default async function handler(req, res) {
  const { url } = req.query;
  if (!url) return res.status(400).json({ error: 'No URL provided' });

  const allowed = ['wsdot.wa.gov', 'wsdot.com', 'nasstatus.faa.gov'];
  try {
    const urlObj = new URL(url);
    if (!allowed.some(d => urlObj.hostname.endsWith(d))) {
      return res.status(403).json({ error: 'Domain not allowed' });
    }
  } catch(e) {
    return res.status(400).json({ error: 'Invalid URL' });
  }

  try {
    const response = await fetch(url);
    const text = await response.text();
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Content-Type', response.headers.get('content-type') || 'text/plain');
    res.status(response.status).send(text);
  } catch(e) {
    res.status(500).json({ error: e.message });
  }
}
