const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { URL } = require('url');

const PORT = 8080;
const DIR = __dirname;

function getLocalIP() {
  const ifaces = os.networkInterfaces();
  for (const name of Object.keys(ifaces)) {
    for (const iface of ifaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) return iface.address;
    }
  }
  return '127.0.0.1';
}

const LOCAL_IP = getLocalIP();

// In-memory signaling rooms for P2P (WebRTC) — no external dependencies.
const rooms = new Map(); // room -> [{res, id}]

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

function proxyUpload(targetUrl, formData, filename, provider) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(targetUrl);
    const boundary = '----WebKitFormBoundary' + Math.random().toString(36).slice(2);

    let parts;
    if (provider === 'perm') {
      parts = [
        Buffer.from(
          `--${boundary}\r\nContent-Disposition: form-data; name="reqtype"\r\n\r\nfileupload\r\n` +
          `--${boundary}\r\nContent-Disposition: form-data; name="fileToUpload"; filename="${filename}"\r\nContent-Type: application/octet-stream\r\n\r\n`
        ),
        formData,
        Buffer.from(`\r\n--${boundary}--\r\n`),
      ];
    } else {
      parts = [
        Buffer.from(
          `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="${filename}"\r\nContent-Type: application/octet-stream\r\n\r\n`
        ),
        formData,
        Buffer.from(`\r\n--${boundary}--\r\n`),
      ];
    }

    const body = Buffer.concat(parts);

    const opts = {
      hostname: parsed.hostname,
      port: 443,
      path: parsed.pathname,
      method: 'POST',
      headers: {
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
        'Content-Length': body.length,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0',
      },
      rejectUnauthorized: false,
    };

    const req = https.request(opts, (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(data);
        } else {
          reject(new Error('Server returned ' + res.statusCode + ': ' + data.slice(0, 200)));
        }
      });
    });

    req.on('error', (e) => reject(new Error('Connection failed: ' + e.message)));
    req.write(body);
    req.end();
  });
}

function collectBody(req) {
  return new Promise((resolve) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks)));
  });
}

const handler = async (req, res) => {
  // CORS headers for all responses
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-Provider, X-File-Name');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    return res.end();
  }

  // IP endpoint - returns local IP for mobile connection
  if (req.method === 'GET' && req.url === '/ip') {
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    return res.end(JSON.stringify({ ip: LOCAL_IP, port: PORT }));
  }

  // Upload endpoint
  if (req.method === 'POST' && req.url === '/upload') {
    try {
      const provider = req.headers['x-provider'] || 'temp';
      const filename = decodeURIComponent(req.headers['x-file-name'] || 'file');
      const body = await collectBody(req);

    let targetUrl;
    if (provider === 'perm') {
      targetUrl = 'https://catbox.moe/user/api.php';
    } else {
      targetUrl = 'https://tmpfiles.org/api/v1/upload';
    }

      const responseText = await proxyUpload(targetUrl, body, filename, provider);

      let resultUrl;
      if (provider === 'perm') {
        resultUrl = responseText.trim();
        if (!resultUrl.startsWith('http')) throw new Error('Upload failed: ' + responseText.slice(0, 200));
      } else {
        const json = JSON.parse(responseText);
        if (json.status !== 'success') throw new Error('Upload failed');
        resultUrl = json.data.url.replace('tmpfiles.org/', 'tmpfiles.org/dl/');
      }

      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ ok: true, url: resultUrl }));
    } catch (e) {
      console.error('Upload error:', e.message);
      res.writeHead(500, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ ok: false, error: e.message }));
    }
    return;
  }

  // ===== P2P signaling over SSE (no PeerJS / no external server) =====
  if (req.method === 'GET' && req.url.startsWith('/signal/events')) {
    const u = new URL(req.url, 'http://localhost');
    const room = u.searchParams.get('room') || 'default';
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*',
    });
    res.write('retry: 2000\n\n');
    const id = Math.random().toString(36).slice(2);
    if (!rooms.has(room)) rooms.set(room, []);
    const client = { res, id };
    rooms.get(room).push(client);
    // notify existing peers that someone joined (so sender re-sends the offer)
    for (const c of rooms.get(room)) {
      if (c !== client) c.res.write(`event: ready\ndata: ${id}\n\n`);
    }
    req.on('close', () => {
      const arr = rooms.get(room) || [];
      rooms.set(room, arr.filter((c) => c !== client));
    });
    return;
  }

  if (req.method === 'POST' && req.url.startsWith('/signal/send')) {
    try {
      const u = new URL(req.url, 'http://localhost');
      const room = u.searchParams.get('room') || 'default';
      const from = u.searchParams.get('from') || '';
      const body = await collectBody(req);
      const clients = rooms.get(room) || [];
      for (const c of clients) {
        if (c.id !== from) c.res.write(`data: ${body.toString()}\n\n`);
      }
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ ok: true }));
    } catch (e) {
      res.writeHead(500, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ ok: false, error: e.message }));
    }
    return;
  }

  // Static files
  let filePath = req.url.split('?')[0];
  if (filePath === '/') filePath = '/index.html';
  const fullPath = path.join(DIR, filePath);

  // Security: prevent directory traversal
  if (!fullPath.startsWith(DIR)) {
    res.writeHead(403);
    return res.end('Forbidden');
  }

  fs.readFile(fullPath, (err, data) => {
    if (err) {
      res.writeHead(404);
      return res.end('Not found');
    }
    const ext = path.extname(fullPath);
    res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
    res.end(data);
  });
};

const useHttps = fs.existsSync(path.join(DIR, 'cert.pem')) && fs.existsSync(path.join(DIR, 'key.pem'));
let server;
if (useHttps) {
  try {
    const opt = { key: fs.readFileSync(path.join(DIR, 'key.pem')), cert: fs.readFileSync(path.join(DIR, 'cert.pem')) };
    server = https.createServer(opt, handler);
  } catch (e) {
    console.error('HTTPS failed, falling back to HTTP:', e.message);
    server = http.createServer(handler);
  }
} else {
  server = http.createServer(handler);
}
const PROTO = (server instanceof https.Server) ? 'https' : 'http';

server.listen(PORT, () => {
  console.log('');
  console.log('  ╔══════════════════════════════════════╗');
  console.log('  ║       QR Share — شارك ملفاتك بكود     ║');
  console.log('  ╠══════════════════════════════════════╣');
  console.log('  ║                                      ║');
  console.log('  ║   على الموبايل افتح الرابط ده:       ║');
  console.log('  ║                                      ║');
  console.log('  ║     ' + PROTO + '://' + LOCAL_IP + ':' + PORT + '        ║');
  console.log('  ║                                      ║');
  console.log('  ║   (لو ظهر تحذير شهادة اضغط «متقدم»   ║');
  console.log('  ║    ثم «المتابعة رغم المخاطرة»)        ║');
  console.log('  ╚══════════════════════════════════════╝');
  console.log('');
  console.log('  لوقف السيرفر: Ctrl+C');
  console.log('');
});
