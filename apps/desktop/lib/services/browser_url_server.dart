import 'dart:convert';
import 'dart:io';

/// 已知浏览器可执行名（小写）。前台是它们时才取缓存 URL。
const Set<String> kBrowserExes = {
  'chrome.exe',
  'msedge.exe',
  'brave.exe',
  'vivaldi.exe',
  'opera.exe',
  'firefox.exe',
};

/// 本地回环 HTTP 服务：接收浏览器扩展推送的「当前聚焦标签页 URL」并缓存。
/// 纯 Dart，无原生 COM，绝不崩溃；扩展未装/未运行时缓存为空，URL 留空即可。
class BrowserUrlServer {
  HttpServer? _server;
  String _url = '';
  bool _focused = false;
  DateTime _at = DateTime.fromMillisecondsSinceEpoch(0);

  /// 固定端口（扩展里硬编码同一个）。
  static const int port = 49219;

  /// 截图时取用的浏览器 URL：仅当浏览器聚焦中、且推送较新才有效。
  String get currentUrl {
    if (!_focused || _url.isEmpty) return '';
    if (DateTime.now().difference(_at) > const Duration(seconds: 60)) return '';
    return _url;
  }

  Future<void> start() async {
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _server!.listen(_handle, onError: (_) {});
    } catch (_) {
      // 端口被占等：URL 功能不可用，但绝不影响 app 本体。
    }
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final origin = req.headers.value('origin') ?? '';
      req.response.headers
        ..set('Access-Control-Allow-Origin', origin.isEmpty ? '*' : origin)
        ..set('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
        ..set('Access-Control-Allow-Headers', 'Content-Type');

      if (req.method == 'OPTIONS') {
        req.response.statusCode = 204;
        await req.response.close();
        return;
      }
      if (req.method == 'GET' && req.uri.path == '/ping') {
        req.response.write('SnapMind');
        await req.response.close();
        return;
      }
      if (req.method == 'POST' && req.uri.path == '/url') {
        // 只收浏览器扩展来源，挡掉本地网页的随意 POST。
        if (!origin.startsWith('chrome-extension://') &&
            !origin.startsWith('moz-extension://')) {
          req.response.statusCode = 403;
          await req.response.close();
          return;
        }
        final body = await utf8.decoder.bind(req).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        _url = (data['url'] as String?)?.trim() ?? '';
        _focused = (data['focused'] as bool?) ?? true;
        _at = DateTime.now();
        req.response.statusCode = 204;
        await req.response.close();
        return;
      }
      req.response.statusCode = 404;
      await req.response.close();
    } catch (_) {
      try {
        req.response.statusCode = 400;
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> stop() async => _server?.close(force: true);
}
