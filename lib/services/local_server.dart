import 'dart:async';
import 'dart:io';

/// خادم HTTP محلي بسيط يقدّم ملفًا واحدًا على شبكة الواي فاي.
/// اللي يمسح الـ QR وهو على نفس الشبكة يقدر يحمل الملف مباشرة من جهازك.
class LocalFileServer {
  LocalFileServer(this._file) : token = _randomToken();

  final File _file;
  final String token;
  HttpServer? _server;
  int activeDownloads = 0;

  static String _randomToken() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final rnd = DateTime.now().microsecondsSinceEpoch;
    return List.generate(
      6,
      (i) => chars[(rnd >> (i * 3)) % chars.length],
    ).join();
  }

  String get fileName => _file.uri.pathSegments.last;

  Future<String> start() async {
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
    } on SocketException {
      try {
        server = await HttpServer.bind(InternetAddress.anyIPv4, 9090);
      } on SocketException {
        server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      }
    }
    _server = server;
    server.listen(_handle, onError: (_) {});
    final ip = await _localIp();
    return 'http://$ip:${server.port}/f/$token';
  }

  void stop() {
    _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final path = req.uri.path;
      if (path == '/') {
        await _serveLanding(req);
      } else if (path == '/f/$token') {
        await _serveFile(req);
      } else {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    } catch (_) {
      try {
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> _serveLanding(HttpRequest req) async {
    String esc(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
    final safeName = esc(fileName);
    req.response.headers.contentType = ContentType.html;
    req.response.write('''
<!DOCTYPE html><html dir="rtl" lang="ar"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>QR Share</title>
<style>
body{background:#0e0f1a;color:#fff;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
a{background:#7c4dff;color:#fff;text-decoration:none;padding:16px 40px;border-radius:14px;font-size:18px}
</style></head><body>
<div style="text-align:center"><p style="font-size:22px">📦 $safeName</p>
<a href="/f/$token">⬇️ تحميل الملف</a></div>
</body></html>''');
    await req.response.close();
  }

  Future<void> _serveFile(HttpRequest req) async {
    final len = await _file.length();
    final headers = req.response.headers;
    headers.contentType = _mimeFor(fileName);
    headers.set(
      'Content-Disposition',
      "attachment; filename=\"${_asciiName(fileName)}\"; "
          "filename*=UTF-8''${Uri.encodeComponent(fileName)}",
    );

    final range = RangeHeader.parse(req.headers.value(HttpHeaders.rangeHeader));
    if (range != null && range.start < len) {
      final end = (range.end >= 0 && range.end < len - 1) ? range.end : len - 1;
      req.response.statusCode = HttpStatus.partialContent;
      headers.set('Content-Range', 'bytes ${range.start}-$end/$len');
      headers.contentLength = end - range.start + 1;
      activeDownloads++;
      await req.response.addStream(
        _file.openRead(range.start, end + 1),
      );
      activeDownloads--;
      await req.response.close();
      return;
    }

    headers.contentLength = len;
    headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    activeDownloads++;
    await req.response.addStream(_file.openRead());
    activeDownloads--;
    await req.response.close();
  }

  String _asciiName(String name) =>
      name.replaceAll(RegExp(r'[^\x20-\x7E]'), '_').replaceAll('"', '_');

  ContentType _mimeFor(String name) {
    const map = {
      '.mp4': 'video/mp4', '.mkv': 'video/x-matroska', '.mov': 'video/quicktime',
      '.webm': 'video/webm', '.avi': 'video/x-msvideo', '.3gp': 'video/3gpp',
      '.mp3': 'audio/mpeg', '.m4a': 'audio/mp4', '.aac': 'audio/aac',
      '.wav': 'audio/wav', '.ogg': 'audio/ogg', '.opus': 'audio/ogg',
      '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
      '.gif': 'image/gif', '.webp': 'image/webp', '.heic': 'image/heic',
      '.pdf': 'application/pdf', '.txt': 'text/plain', '.csv': 'text/csv',
      '.doc': 'application/msword',
      '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls': 'application/vnd.ms-excel',
      '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt': 'application/vnd.ms-powerpoint',
      '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.zip': 'application/zip', '.rar': 'application/vnd.rar',
      '.apk': 'application/vnd.android.package-archive',
      '.json': 'application/json',
    };
    final ext = name.contains('.') ? name.substring(name.lastIndexOf('.')) : '';
    return ContentType.parse(map[ext] ?? 'application/octet-stream');
  }

  Future<String> _localIp() async {
    final interfaces =
        await NetworkInterface.list(includeLoopback: false, includeLinkLocal: false);
    String? fallback;
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (addr.type != InternetAddressType.IPv4 || addr.isLoopback) continue;
        if (iface.name.startsWith('wlan') || iface.name.startsWith('ap')) {
          return addr.address;
        }
        fallback ??= addr.address;
      }
    }
    if (fallback != null) return fallback;
    throw Exception('لا يوجد اتصال شبكة - شغّل الواي فاي أو الهوت سبوت');
  }
}

class RangeHeader {
  RangeHeader(this.start, this.end);

  final int start;
  final int end;

  static RangeHeader? parse(String? value) {
    if (value == null) return null;
    final m = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(value.trim());
    if (m == null) return null;
    final s = m.group(1), e = m.group(2);
    if (s == null || s.isEmpty) return null;
    return RangeHeader(int.parse(s), (e == null || e.isEmpty) ? -1 : int.parse(e));
  }
}
