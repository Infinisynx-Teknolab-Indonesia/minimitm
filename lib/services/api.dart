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

  /// Pesan error terakhir saat "Mulai proxy" (null = tidak ada error).
  String? startError;

  Future<void> start() async {
    startError = null;
    try {
      final r = await http.post(Uri.parse('$_http/api/start')).timeout(const Duration(seconds: 10));
      final j = jsonDecode(r.body);
      if (j is Map && j['ok'] == false) {
        startError = '${j['error'] ?? 'Gagal menjalankan proxy.'}';
      }
    } catch (e) {
      startError = 'Backend (port $basePort) tidak merespons. Pastikan server Python berjalan: '
          'jalankan "python run_server.py" di folder backend, atau cek log di Pengaturan.\n$e';
    }
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

  // ---- Mail Catcher (menu "Email Login") ----
  Future<Map<String, dynamic>> mailStatus() async {
    final r = await http.get(Uri.parse('$_http/api/mail/status'));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> mailStart({String host = '0.0.0.0', int port = 1025}) async {
    final r = await http.post(Uri.parse('$_http/api/mail/start'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'host': host, 'port': port}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> mailStop() async {
    final r = await http.post(Uri.parse('$_http/api/mail/stop'));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> mailList({String to = ''}) async {
    final uri = Uri.parse('$_http/api/mail/list').replace(queryParameters: {'to': to});
    final r = await http.get(uri);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return ((j['items'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> mailGet(int id) async {
    final r = await http.get(Uri.parse('$_http/api/mail/get/$id'));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<void> mailClear() async {
    await http.delete(Uri.parse('$_http/api/mail'));
  }

  String mailHtmlUrl(int id) => '$_http/api/mail/html/$id';

  // ---- Login Email (IMAP) ----
  Future<Map<String, dynamic>> imapDetect(String email) async {
    final uri = Uri.parse('$_http/api/imap/detect').replace(queryParameters: {'email': email});
    final r = await http.get(uri);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> imapFetch({
    required String email,
    required String password,
    String? host,
    int? port,
    int limit = 15,
    bool unseenOnly = false,
    String mailbox = 'INBOX',
    String proto = 'imap',   // 'imap' | 'pop3'
    bool ssl = true,         // true = TLS implisit (993/995); false = plaintext/STARTTLS
    bool starttls = false,   // kalau ssl=false, naikkan ke TLS (STARTTLS/STLS)
  }) async {
    final r = await http.post(Uri.parse('$_http/api/imap/fetch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email, 'password': password, 'host': host, 'port': port,
          'limit': limit, 'unseen_only': unseenOnly, 'mailbox': mailbox,
          'proto': proto, 'ssl': ssl, 'starttls': starttls,
        }));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  String imapHtmlUrl(int id) => '$_http/api/imap/html/$id';

  // ---- SMS Catcher (menu "SMS Masuk") — webhook dari gateway/provider sendiri ----
  Future<Map<String, dynamic>> smsStatus() async {
    final r = await http.get(Uri.parse('$_http/api/sms/status'));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> smsSetRunning(bool running) async {
    final r = await http.post(Uri.parse('$_http/api/sms/running'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'running': running}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> smsSetToken(String token) async {
    final r = await http.post(Uri.parse('$_http/api/sms/token'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'token': token}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> smsList({String to = ''}) async {
    final uri = Uri.parse('$_http/api/sms/list').replace(queryParameters: {'to': to});
    final r = await http.get(uri);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return ((j['items'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> smsClear() async {
    await http.delete(Uri.parse('$_http/api/sms'));
  }

  /// URL webhook yang di-set di gateway/provider SMS milikmu (LAN / VPS).
  String smsInboundUrl({String host = ''}) {
    final h = host.trim().isEmpty ? baseHost : host.trim();
    return 'http://$h:$basePort/api/sms/inbound';
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

  /// Buka Settings > Trusted credentials > USER langsung di HP, supaya pengguna
  /// bisa cek sendiri apakah CA MITM benar-benar aktif di sana.
  Future<Map<String, dynamic>> adbOpenTrustedCredentials(String serial) async {
    final r = await http.post(Uri.parse('$_http/api/adb/open-trusted-credentials'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'serial': serial}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ---- Frida (install frida-server + script) ----
  Future<Map<String, dynamic>> fridaStatus(String serial) async {
    final r = await http.get(Uri.parse('$_http/api/frida/status?serial=${Uri.encodeComponent(serial)}')).timeout(const Duration(seconds: 15));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fridaInstall(String serial) async {
    final r = await http
        .post(Uri.parse('$_http/api/frida/install'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'serial': serial}))
        .timeout(const Duration(seconds: 120));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fridaStopServer(String serial) async {
    final r = await http.post(Uri.parse('$_http/api/frida/stop-server'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'serial': serial}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<String>> fridaPackages(String serial) async {
    final r = await http.get(Uri.parse('$_http/api/frida/packages?serial=${Uri.encodeComponent(serial)}')).timeout(const Duration(seconds: 20));
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return (d['packages'] as List?)?.cast<String>() ?? <String>[];
  }

  Future<List<Map<String, dynamic>>> fridaScripts() async {
    final r = await http.get(Uri.parse('$_http/api/frida/scripts'));
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return (d['scripts'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> fridaScriptRead(String name) async {
    final r = await http.get(Uri.parse('$_http/api/frida/scripts/${Uri.encodeComponent(name)}'));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fridaScriptSave(String name, String content) async {
    final r = await http.put(Uri.parse('$_http/api/frida/scripts/${Uri.encodeComponent(name)}'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'content': content}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<void> fridaScriptDelete(String name) async {
    await http.delete(Uri.parse('$_http/api/frida/scripts/${Uri.encodeComponent(name)}'));
  }

  Future<Map<String, dynamic>> fridaRun(String serial, String package, String script, {bool spawn = true}) async {
    final r = await http.post(Uri.parse('$_http/api/frida/run'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'serial': serial, 'package': package, 'script': script, 'spawn': spawn}));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fridaSessions() async {
    final r = await http.get(Uri.parse('$_http/api/frida/sessions'));
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return (d['sessions'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> fridaSessionLog(String id, {int since = 0}) async {
    final r = await http.get(Uri.parse('$_http/api/frida/sessions/$id/log?since=$since'));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fridaSessionStop(String id) async {
    final r = await http.post(Uri.parse('$_http/api/frida/sessions/$id/stop'));
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

  /// Unduh apktool, jadx, uber-apk-signer (GitHub resmi) + pasang reflutter (pip).
  /// Tak butuh Android SDK; hanya butuh Java sudah ada.
  Future<Map<String, dynamic>> apkInstallTools() async {
    final r = await http.post(Uri.parse('$_http/api/apk/install-tools')).timeout(const Duration(minutes: 5));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Satu klik untuk app Flutter: reflutter (patch Dart/TLS) lalu tanda tangani hasilnya.
  Future<Map<String, dynamic>> apkReflutter(String apk) async {
    final r = await http.post(Uri.parse('$_http/api/apk/reflutter'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'apk': apk})).timeout(const Duration(minutes: 10));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Pindai APK (tanpa decompile) untuk cari keystore, PEM key, JWT, API key, dsb.
  Future<Map<String, dynamic>> apkSecrets(String apk) async {
    final r = await http.post(Uri.parse('$_http/api/apk/secrets'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'apk': apk})).timeout(const Duration(minutes: 5));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Suntik native lib (.so) ke folder hasil Decode -> recompile (apktool b) -> self-sign.
  /// Untuk APK milikmu sendiri (mis. engine instrumentasi / frida-gadget).
  Future<Map<String, dynamic>> apkInjectSo({
    required String srcdir,
    required List<String> soPaths,
    String libName = '',
    List<String> abis = const [],
    bool addLoader = true,
    bool trustCa = false,
    String outdir = '',
  }) async {
    final r = await http.post(Uri.parse('$_http/api/apk/inject-so'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'srcdir': srcdir, 'so_paths': soPaths, 'lib_name': libName,
          'abis': abis, 'add_loader': addLoader, 'trust_ca': trustCa, 'outdir': outdir,
        })).timeout(const Duration(minutes: 10));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Decode (apktool d): apk -> folder source (smali + res + AndroidManifest.xml).
  Future<Map<String, dynamic>> apkDecode(String apk, {String outdir = ''}) async {
    final r = await http.post(Uri.parse('$_http/api/apk/decode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'apk': apk, 'outdir': outdir})).timeout(const Duration(minutes: 10));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Tulis network_security_config (trust user CA) + debuggable di folder source,
  /// TANPA build/sign -- langkah manual sebelum 'Build'.
  Future<Map<String, dynamic>> apkPatchManifest(String srcdir) async {
    final r = await http.post(Uri.parse('$_http/api/apk/patch-manifest'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'srcdir': srcdir})).timeout(const Duration(minutes: 2));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// 'apktool b': folder source -> .apk belum ditandatangani.
  Future<Map<String, dynamic>> apkBuild(String srcdir, {String outdir = ''}) async {
    final r = await http.post(Uri.parse('$_http/api/apk/build'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'srcdir': srcdir, 'outdir': outdir})).timeout(const Duration(minutes: 10));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Tanda tangani .apk (uber-apk-signer, atau zipalign+apksigner resmi sbg cadangan).
  Future<Map<String, dynamic>> apkSign(String apk) async {
    final r = await http.post(Uri.parse('$_http/api/apk/sign'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'apk': apk})).timeout(const Duration(minutes: 5));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Pindai folder HASIL DECOMPILE (jadx/apktool) sbg teks sumber -- lebih reliabel utk
  /// key bernama (mis. "HMAC key") daripada pemindaian ZIP mentah di apkSecrets().
  Future<Map<String, dynamic>> apkSecretsDir(String dir) async {
    final r = await http.post(Uri.parse('$_http/api/apk/secrets-dir'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'dir': dir})).timeout(const Duration(minutes: 5));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Tab 4 "Cari dengan AI": AI menelusuri folder hasil decompile (lewat ranking file +
  /// AI membaca potongan relevan -- bukan akses mandiri ke seluruh filesystem) utk
  /// menjawab pertanyaan ttg lokasi data sensitif. Pakai AI yg diatur di Settings > AI.
  Future<Map<String, dynamic>> apkAiSearch(String dir, String question) async {
    final r = await http.post(Uri.parse('$_http/api/apk/ai-search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'dir': dir, 'question': question})).timeout(const Duration(minutes: 5));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ---- SpiderFoot (Docker: lokal/remote) ----
  Future<Map<String, dynamic>> sfCall(String action, Map<String, dynamic> cfg) async {
    final r = await http.post(Uri.parse('$_http/api/spiderfoot/$action'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(cfg)).timeout(const Duration(minutes: 16));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ---- Web Vuln Scanner (aktif) ----
  Future<Map<String, dynamic>> webscanRun(String url, {String method = 'GET', String body = '', List<String> checks = const []}) async {
    final r = await http.post(Uri.parse('$_http/api/webscan/run'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url, 'method': method, 'body': body, 'checks': checks})).timeout(const Duration(minutes: 5));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ---- Recon / OSINT passive (gaya SpiderFoot) ----
  Future<Map<String, dynamic>> reconRun(String target, List<String> modules) async {
    final r = await http.post(Uri.parse('$_http/api/recon/run'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'target': target, 'modules': modules})).timeout(const Duration(minutes: 3));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  String caPemUrl() => '$_http/api/ca.pem';
  String caCrtUrl() => '$_http/api/ca.crt';
  String caMobileconfigUrl() => '$_http/api/ca.mobileconfig';
}
