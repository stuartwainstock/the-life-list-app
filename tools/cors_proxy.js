/*
 * Minimal local CORS proxy for eBird API calls during web development.
 *
 * Why this exists: eBird's public API is built for server-side and mobile
 * use. It may not send Access-Control-Allow-Origin headers, which means a
 * browser (i.e. `flutter run -d chrome`) could refuse to let our app read
 * the response even though the request itself succeeds. This proxy sits
 * between the Flutter web app and eBird, forwards the request untouched,
 * and adds the CORS headers a browser needs.
 *
 * Only needed for `flutter run -d chrome` / web testing. Android/iOS
 * builds talk to api.ebird.org directly and never touch this.
 *
 * Usage:
 *   node tools/cors_proxy.js
 *   (listens on http://localhost:3000, forwards to https://api.ebird.org)
 *
 * No dependencies beyond Node's built-in http/https modules.
 */

const http = require('http');
const https = require('https');

const PORT = 3000;
const TARGET_HOST = 'api.ebird.org';

const server = http.createServer((req, res) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'X-eBirdApiToken, Content-Type',
  };

  if (req.method === 'OPTIONS') {
    res.writeHead(204, corsHeaders);
    res.end();
    return;
  }

  const options = {
    hostname: TARGET_HOST,
    path: req.url,
    method: req.method,
    headers: {
      ...req.headers,
      host: TARGET_HOST,
    },
  };

  const proxyReq = https.request(options, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, {
      ...proxyRes.headers,
      ...corsHeaders,
    });
    proxyRes.pipe(res, { end: true });
  });

  proxyReq.on('error', (err) => {
    console.error('Proxy request failed:', err.message);
    res.writeHead(502, corsHeaders);
    res.end(`Proxy error: ${err.message}`);
  });

  req.pipe(proxyReq, { end: true });
});

server.listen(PORT, () => {
  console.log(`eBird CORS proxy listening on http://localhost:${PORT}`);
  console.log(`Forwarding to https://${TARGET_HOST}`);
});
