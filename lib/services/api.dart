import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Klien ke server backend FastAPI (REST + WebSocket).
/// Semua state proxy tinggal di backend; aplikasi ini hanya menampilkannya.
class Api extends ChangeNotifier {
  Api._();
  static final Api instance = Api._();

  String baseHost = '127.0.0.1';
  int basePort = 8099;
  String get _http => 'http://$baseHost:$basePort';
  String get _ws => 'ws://$baseHost:$basePort/ws';

  // ---- status koneksi & proxy ----
  bool connected = false;
  Map<String, dynamic> status = {'running': false, 'host': '127.0.0.1', 'port': 8080, 'intercept': false};
  bool get proxyRunning => status['running'] == true;
  bool get intercepting => status['intercept'] == true;

  // ---- data langsung ----
  final List<Map<String, dynamic>> flows = [];       // ringkasan, terbaru di atas
  final List<Map<String, dynamic>> pendingIntercept = []; // request yang ditahan
  final List<Map<String, dynamic>> wsMessages = [];  // pesan WebSocket, terbaru di atas
  final _flowStream = StreamController<void>.broadcast();
  final _interceptStream = StreamController<void>.broadcast();
  final _wsStream = StreamController<void>.broadcast();
  Stream<void> get onFlow => _flowStream.stream;
  Stream<void> get onIntercept => _interceptStream.stream;
  Stream<void> get onWs => _wsStream.stream;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _retry;

  // ---- koneksi WebSocket ----
  void connect() {
    _retry?.cancel();
    try {
      _sub?.cancel();
    } catch (_) {}
    try {
      final ch = WebSocketChannel.connect(Uri.parse(_ws));
      _channel = ch;
      // Tangani kegagalan koneksi awal lewat `ready` supaya tidak jadi
      // "Unhandled Exception" yang membanjiri konsol.
      ch.ready.then((_) {
        connected = true;
        notifyListeners();
        refreshStatus();
      }).catchError((_) {
        _reconnect();
      });
      _sub = ch.stream.listen(_onMsg, onError: (_) => _reconnect(), onDone: _reconnect, cancelOnError: true);
    } catch (_) {
      _reconnect();
    }
  }

  void _reconnect() {
    connected = false;
    notifyListeners();
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 2), connect);
  }

  /// Sisipkan menurut nomor (id) menurun -> yang terbaru selalu di atas,
  /// walau response-nya selesai tidak berurutan.
  static void _insertByIdDesc(List<Map<String, dynamic>> list, Map<String, dynamic> item) {
    final id = (item['id'] as num?)?.toInt() ?? 0;
    int i = 0;
    while (i < list.length && ((list[i]['id'] as num?)?.toInt() ?? 0) > id) {
      i++;
    }
    list.insert(i, item);
  }

  void _onMsg(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      switch (msg['type']) {
        case 'hello':
          connected = true;
          status = Map<String, dynamic>.from(msg['status'] ?? status);
          notifyListeners();
          break;
        case 'flow':
          _insertByIdDesc(flows, Map<String, dynamic>.from(msg['flow']));
          if (flows.length > 5000) flows.removeLast();
          _flowStream.add(null);
          break;
        case 'intercept':
          _insertByIdDesc(pendingIntercept, Map<String, dynamic>.from(msg['request']));
          _interceptStream.add(null);
          notifyListeners();
          break;
        case 'intercept_released':
          // dilepas otomatis oleh backend (switch intercept dimatikan / timeout)
          pendingIntercept.removeWhere((e) => e['id'] == msg['id'] && (e['phase'] ?? 'request') == (msg['phase'] ?? 'request'));
          _interceptStream.add(null);
          notifyListeners();
          break;
        case 'cleared':
          flows.clear();
          _flowStream.add(null);
          break;
        case 'ws':
          wsMessages.insert(0, Map<String, dynamic>.from(msg['msg']));
          if (wsMessages.length > 3000) wsMessages.removeLast();
          _wsStream.add(null);
          break;
      }
    } catch (_) {}
  }

  // ---- REST ----
  Future<Map<String, dynamic>> refreshStatus() async {
    try {
      final r = await http.get(Uri.parse('$_http/api/status')).timeout(const Duration(seconds: 5));
      status = jsonDecode(r.body) as Map<String, dynamic>;
      connected = true;
    } catch (_) {
      connected = false;
    }
    notifyListeners();
    return status;
  }

  Future<void> start() async {
    await http.post(Uri.parse('$_http/api/start'));
    await refreshStatus();
  }

  Future<void> stop() async {
    await http.post(Uri.parse('$_http/api/stop'));
    await refreshStatus();
  }

  Future<Map<String, dynamic>> getConfig() async {
    final r = await http.get(Uri.parse('$_http/api/config'));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> putConfig(Map<String, dynamic> cfg) async {
    final r = await http.put(Uri.parse('$_http/api/config'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(cfg));
    await refreshStatus();
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> history({int limit = 1000, String host = '', String method = '', String q = ''}) async {
    final uri = Uri.parse('$_http/api/history').replace(queryParameters: {
      'limit': '$limit',
      if (host.isNotEmpty) 'host': host,
      if (method.isNotEmpty) 'method': method,
      if (q.isNotEmpty) 'q': q,
    });
    final r = await http.get(uri);
    final list = jsonDecode(r.body) as List;
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> flowDetail(int id) async {
    final r = await http.get(Uri.parse('$_http/api/history/$id'));
    if (r.statusCode != 200) return null;
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<void> clearHistory() async {
    await http.delete(Uri.parse('$_http/api/history'));
    flows.clear();
    _flowStream.add(null);
  }

  Future<Map<String, dynamic>> repeaterSend(Map<String, dynamic> req) async {
    final r = await http.post(Uri.parse('$_http/api/repeater/send'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(req));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// [phase] = 'request' atau 'response'. [modified] berisi hasil edit:
  ///  request  -> {method, path, headers, body}
  ///  response -> {status, headers, body}
  Future<void> resolveIntercept(int id, String decision, {Map<String, dynamic>? modified, String phase = 'request'}) async {
    final body = <String, dynamic>{'id': id, 'decision': decision, 'phase': phase};
    if (modified != null) body.addAll(modified);
    await http.post(Uri.parse('$_http/api/intercept/resolve'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    pendingIntercept.removeWhere((e) => e['id'] == id && (e['phase'] ?? 'request') == phase);
    _interceptStream.add(null);
    notifyListeners();
  }

  /// Jalankan plugin manual pada request/response mentah (belum jadi flow).
  Future<Map<String, dynamic>> runPluginRaw(String name, Map<String, dynamic> message) async {
    final r = await http.post(Uri.parse('$_http/api/plugins/${Uri.encodeComponent(name)}/run'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'raw': message}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> scan({int limit = 500}) async {
    final r = await http.post(Uri.parse('$_http/api/scan?limit=$limit'));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ---- plugin ----
  Future<List<Map<String, dynamic>>> plugins() async {
    final r = await http.get(Uri.parse('$_http/api/plugins'));
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return (data['plugins'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> reloadPlugins() async {
    final r = await http.post(Uri.parse('$_http/api/plugins/reload'));
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return (data['plugins'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> togglePlugin(String name, bool enabled) async {
    final r = await http.post(Uri.parse('$_http/api/plugins/${Uri.encodeComponent(name)}/toggle'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'enabled': enabled}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> runPlugin(String name, int flowId) async {
    final r = await http.post(Uri.parse('$_http/api/plugins/${Uri.encodeComponent(name)}/run'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'flow_id': flowId}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ---- tool: decoder / jwt / totp / intruder ----
  Future<Map<String, dynamic>> decode(String input, String op) async {
    final r = await http.post(Uri.parse('$_http/api/decode'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'input': input, 'op': op}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> jwtDecode(String token) async {
    final r = await http.post(Uri.parse('$_http/api/jwt/decode'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'token': token}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> jwtEncode(Map<String, dynamic> header, Map<String, dynamic> payload, String alg, String secret) async {
    final r = await http.post(Uri.parse('$_http/api/jwt/encode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'header': header, 'payload': payload, 'alg': alg, 'secret': secret}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> totpPresets() async {
    final r = await http.get(Uri.parse('$_http/api/totp/presets'));
    return (jsonDecode(r.body) as Map<String, dynamic>)['presets'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> totpAccounts() async {
    final r = await http.get(Uri.parse('$_http/api/totp/accounts'));
    return ((jsonDecode(r.body) as Map<String, dynamic>)['accounts'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> totpAddAccount(String label, String secret, String preset, {String nonce = ''}) async {
    final r = await http.post(Uri.parse('$_http/api/totp/accounts'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'label': label, 'secret': secret, 'preset': preset, 'nonce': nonce}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> totpNonce(String nonce) async {
    final r = await http.post(Uri.parse('$_http/api/totp/nonce'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'nonce': nonce}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> netInfo() async {
    final r = await http.get(Uri.parse('$_http/api/netinfo'));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> firewallOpen(int port) async {
    final r = await http.post(Uri.parse('$_http/api/firewall/open'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'port': port}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> totpDeleteAccount(String id) async {
    final r = await http.delete(Uri.parse('$_http/api/totp/accounts/$id'));
    return ((jsonDecode(r.body) as Map<String, dynamic>)['accounts'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> jwtAttack(String token, List<String> wordlist) async {
    final r = await http.post(Uri.parse('$_http/api/jwt/attack'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'token': token, 'wordlist': wordlist}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> totp(String secret, String algo, int digits, int period) async {
    final r = await http.post(Uri.parse('$_http/api/totp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'secret': secret, 'algo': algo, 'digits': digits, 'period': period}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> intruder(Map<String, dynamic> req) async {
    final r = await http.post(Uri.parse('$_http/api/intruder'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(req));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ---- AI (Tanya AI) ----
  Future<Map<String, dynamic>> aiConfigGet() async {
    final r = await http.get(Uri.parse('$_http/api/ai/config'));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> aiConfigPut(Map<String, dynamic> cfg) async {
    final r = await http.put(Uri.parse('$_http/api/ai/config'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(cfg));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Seperti [aiModels] tapi mengembalikan juga pesan error dari backend.
  Future<Map<String, dynamic>> aiModelsResult() async {
    try {
      final r = await http.get(Uri.parse('$_http/api/ai/models')).timeout(const Duration(seconds: 60));
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return {
        'ok': data['ok'] == true,
        'models': (data['models'] as List?)?.cast<String>() ?? <String>[],
        'error': data['error'],
      };
    } catch (e) {
      return {'ok': false, 'models': <String>[], 'error': '$e'};
    }
  }

  Future<List<String>> aiModels() async {
    try {
      final r = await http.get(Uri.parse('$_http/api/ai/models'));
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return (data['models'] as List?)?.cast<String>() ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> aiAsk(List<Map<String, String>> messages) async {
    final r = await http.post(Uri.parse('$_http/api/ai/ask'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'messages': messages}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ---- ADB (USB) ----
  Future<Map<String, dynamic>> adbConfigGet() async {
    final r = await http.get(Uri.parse('$_http/api/adb/config'));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adbConfigPut(String path) async {
    final r = await http.put(Uri.parse('$_http/api/adb/config'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'path': path}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adbDevices() async {
    final r = await http.get(Uri.parse('$_http/api/adb/devices'));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adbEnable(String serial, int port) async {
    final r = await http.post(Uri.parse('$_http/api/adb/enable'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'serial': serial, 'port': port}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adbDisable(String serial) async {
    final r = await http.post(Uri.parse('$_http/api/adb/disable'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'serial': serial}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adbPushCert(String serial) async {
    final r = await http.post(Uri.parse('$_http/api/adb/push-cert'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'serial': serial}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ---- Collaborator (OOB) ----
  Future<Map<String, dynamic>> collabStatus() async {
    final r = await http.get(Uri.parse('$_http/api/collab/status'));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> collabStart(int port, String base) async {
    final r = await http.post(Uri.parse('$_http/api/collab/start'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'port': port, 'base': base}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<void> collabStop() async => http.post(Uri.parse('$_http/api/collab/stop'));

  Future<Map<String, dynamic>> collabPayload() async {
    final r = await http.get(Uri.parse('$_http/api/collab/payload'));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> collabInteractions() async {
    final r = await http.get(Uri.parse('$_http/api/collab/interactions'));
    return ((jsonDecode(r.body) as Map<String, dynamic>)['interactions'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> collabClear() async => http.delete(Uri.parse('$_http/api/collab/interactions'));

  // ---- Project ----
  String projectExportUrl() => '$_http/api/project/export';
  Future<Map<String, dynamic>> projectImportPath(String path) async {
    final r = await http.post(Uri.parse('$_http/api/project/import'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'path': path}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ---- WebSocket log ----
  Future<void> wsClear() async {
    await http.delete(Uri.parse('$_http/api/ws/log'));
    wsMessages.clear();
    _wsStream.add(null);
  }

  // ---- APK Tools ----
  Future<Map<String, dynamic>> apkAvailability() async {
    final r = await http.get(Uri.parse('$_http/api/apk/availability'));
    return (jsonDecode(r.body) as Map<String, dynamic>)['tools'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> apkPatch(String apk) async {
    final r = await http.post(Uri.parse('$_http/api/apk/patch'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'apk': apk})).timeout(const Duration(minutes: 10));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> apkJadx(String apk) async {
    final r = await http.post(Uri.parse('$_http/api/apk/jadx'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'apk': apk})).timeout(const Duration(minutes: 10));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  String caPemUrl() => '$_http/api/ca.pem';
  String caCrtUrl() => '$_http/api/ca.crt';
  String caMobileconfigUrl() => '$_http/api/ca.mobileconfig';
}
