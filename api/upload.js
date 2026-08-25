const https = require('https');
const { URL } = require('url');

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  try {
    const chunks = [];
    for await (const chunk of req) chunks.push(chunk);
    const rawBody = Buffer.concat(chunks);

    const contentType = req.headers['content-type'] || '';
    const provider = req.headers['x-provider'] || 'temp';

    let targetUrl;
    if (provider === 'perm') {
      targetUrl = 'https://catbox.moe/user/api.php';
    } else {
      targetUrl = 'https://litterbox.catbox.moe/resources/internals/api.php';
    }

    const parsed = new URL(targetUrl);
    const boundary = '----VercelBoundary' + Math.random().toString(36).slice(2);

    let parts;
    if (provider === 'perm') {
      parts = [
        Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="reqtype"\r\n\r\nfileupload\r\n--${boundary}\r\nContent-Disposition: form-data; name="fileToUpload"; filename="file"\r\nContent-Type: application/octet-stream\r\n\r\n`),
        rawBody,
        Buffer.from(`\r\n--${boundary}--\r\n`),
      ];
    } else {
      parts = [
        Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="reqtype"\r\n\r\nfileupload\r\n--${boundary}\r\nContent-Disposition: form-data; name="time"\r\n\r\n24h\r\n--${boundary}\r\nContent-Disposition: form-data; name="fileToUpload"; filename="file"\r\nContent-Type: application/octet-stream\r\n\r\n`),
        rawBody,
        Buffer.from(`\r\n--${boundary}--\r\n`),
      ];
    }

    const body = Buffer.concat(parts);

    const result = await new Promise((resolve, reject) => {
      const r = https.request({
        hostname: parsed.hostname,
        port: 443,
        path: parsed.pathname,
        method: 'POST',
        headers: {
          'Content-Type': `multipart/form-data; boundary=${boundary}`,
          'Content-Length': body.length,
          'User-Agent': 'Mozilla/5.0',
        },
        rejectUnauthorized: false,
      }, (res) => {
        let data = '';
        res.on('data', c => data += c);
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) resolve(data.trim());
          else reject(new Error('Upload failed: ' + res.statusCode));
        });
      });
      r.on('error', reject);
      r.write(body);
      r.end();
    });

    if (!result.startsWith('http')) throw new Error('Invalid response');
    return res.status(200).json({ ok: true, url: result });
  } catch (e) {
    return res.status(500).json({ ok: false, error: e.message });
  }
};
