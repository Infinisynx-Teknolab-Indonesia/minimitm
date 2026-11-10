import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

enum BackendState { idle, locating, installing, starting, running, external, failed }

/// Menjalankan server backend Python (run_server.py) sebagai proses anak,
/// supaya aplikasi "jalan sendiri" tanpa buka terminal.
class BackendManager extends ChangeNotifier {
  BackendManager._();
  static final BackendManager instance = BackendManager._();

  BackendState state = BackendState.idle;
  String message = '';
  final List<String> log = [];
  Process? _proc;
  bool _stopping = false;

  // pengaturan (tersimpan)
  String pythonPath = Platform.isWindows ? r'D:\python3.12\python.exe' : 'python3';
  String backendDir = '';
  bool autoStart = true;

  bool get busy => state == BackendState.locating || state == BackendState.installing || state == BackendState.starting;
  bool get isOurs => _proc != null;

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      pythonPath = sp.getString('be_python') ?? pythonPath;
      backendDir = sp.getString('be_dir') ?? '';
      autoStart = sp.getBool('be_autostart') ?? true;
    } catch (_) {}
  }

  Future<void> save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('be_python', pythonPath);
      await sp.setString('be_dir', backendDir);
      await sp.setBool('be_autostart', autoStart);
    } catch (_) {}
  }

  void _set(BackendState s, [String? msg]) {
    state = s;
    if (msg != null) message = msg;
    notifyListeners();
  }

  void _log(String line) {
    for (final l in line.split('\n')) {
      if (l.trim().isEmpty) continue;
      log.add(l);
      if (log.length > 400) log.removeAt(0);
    }
    notifyListeners();
  }

  String _join(List<String> parts) => parts.join(Platform.pathSeparator);

  /// Python portable yang dibundel (backend/runtime/python/) kalau ada,
  /// selain itu pakai pythonPath (Python sistem).
  String effectivePython(String dir) {
    final exe = Platform.isWindows ? 'python.exe' : 'python';
    final bundled = _join([dir, 'runtime', 'python', exe]);
    try {
      if (File(bundled).existsSync()) return bundled;
    } catch (_) {}
    return pythonPath;
  }

  bool bundledExists(String dir) {
    final exe = Platform.isWindows ? 'python.exe' : 'python';
    try {
      return File(_join([dir, 'runtime', 'python', exe])).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Kandidat lokasi folder backend (yang berisi run_server.py).
  List<String> _candidates() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final cwd = Directory.current.path;
    return [
      if (backendDir.trim().isNotEmpty) backendDir.trim(),
      _join([exeDir, 'backend']),
      _join([cwd, 'backend']),
      _join([cwd, '..', 'backend']),
      // saat `flutter run`: exe ada di build/windows/x64/runner/Debug -> naik ke root proyek
      _join([exeDir, '..', '..', '..', '..', '..', 'backend']),
      // di sebelah folder proyek flutter
      _join([cwd, '..', 'MiniMitmFlutter', 'backend']),
    ];
  }

  String? _detectDir() {
    for (final c in _candidates()) {
      try {
        if (File(_join([c, 'run_server.py'])).existsSync()) return Directory(c).absolute.path;
      } catch (_) {}
    }
    return null;
  }

  Future<bool> _apiUp() async {
    try {
      final r = await http
          .get(Uri.parse('http://${Api.instance.baseHost}:${Api.instance.basePort}/api/status'))
          .timeout(const Duration(seconds: 2));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Mulai backend: pakai yang sudah jalan kalau ada; selain itu spawn baru.
  Future<void> ensureStarted() async {
    if (state == BackendState.running || state == BackendState.external) return;
    // sudah ada server (dijalankan manual)? pakai itu.
    if (await _apiUp()) {
      _set(BackendState.external, 'Memakai server yang sudah berjalan.');
      Api.instance.connect();
      return;
    }
    _set(BackendState.locating, 'Mencari folder backend…');
    final dir = _detectDir();
    if (dir == null) {
      _set(BackendState.failed, 'Folder backend tidak ditemukan. Atur manual di Pengaturan → Server lokal.');
      return;
    }
    backendDir = dir;
    await save();

    // pasang dependensi sekali (penanda .deps_ok)
    final marker = File(_join([dir, '.deps_ok']));
    if (!marker.existsSync()) {
      final ok = await installDeps(dir: dir);
      if (!ok) return; // pesan sudah di-set
      try {
        marker.writeAsStringSync('ok');
      } catch (_) {}
    }

    await _spawn(dir);
  }

  Future<bool> installDeps({String? dir}) async {
    final d = dir ?? (_detectDir() ?? backendDir);
    if (d.isEmpty) {
      _set(BackendState.failed, 'Folder backend belum diatur.');
      return false;
    }
    _set(BackendState.installing, 'Memasang dependensi (sekali saja)…');
    final py = effectivePython(d);
    _log('> pip install -r requirements.txt');
    try {
      final r = await Process.run(
        py,
        ['-m', 'pip', 'install', '--break-system-packages', '-r', 'requirements.txt'],
        workingDirectory: d,
      );
      _log((r.stdout as String).trim());
      if ((r.stderr as String).trim().isNotEmpty) _log((r.stderr as String).trim());
      if (r.exitCode != 0) {
        _set(BackendState.failed, 'Gagal pasang dependensi. Cek path Python di Pengaturan.');
        return false;
      }
      return true;
    } catch (e) {
      _set(BackendState.failed, 'Python tidak ditemukan di "$pythonPath". Atur di Pengaturan.');
      return false;
    }
  }

  Future<void> _spawn(String dir) async {
    final py = effectivePython(dir);
    _set(BackendState.starting, bundledExists(dir) ? 'Menjalankan server (Python bundel)…' : 'Menjalankan server…');
    _log('> "$py" run_server.py  ($dir)');
    try {
      _proc = await Process.start(py, ['run_server.py'], workingDirectory: dir);
    } catch (e) {
      _set(BackendState.failed, 'Gagal menjalankan Python: $e');
      return;
    }
    _stopping = false;
    _proc!.stdout.transform(utf8.decoder).listen(_log);
    _proc!.stderr.transform(utf8.decoder).listen(_log);
    _proc!.exitCode.then((code) {
      _proc = null;
      if (_stopping) return; // dihentikan manual, bukan error
      final tail = log.length > 12 ? log.sublist(log.length - 12) : List<String>.from(log);
      _set(BackendState.failed, 'Server berhenti (kode $code).\n${tail.join("\n")}');
    });

    // tunggu API siap (maks 60 detik)
    for (var i = 0; i < 120; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (await _apiUp()) {
        _set(BackendState.running, 'Server berjalan.');
        Api.instance.connect();
        return;
      }
      if (_proc == null) return; // keburu mati
    }
    _set(BackendState.failed, 'Server tidak merespons dalam 60 detik.');
  }

  Future<void> restart() async {
    stop();
    await Future.delayed(const Duration(milliseconds: 400));
    await ensureStarted();
  }

  void stop() {
    _stopping = true;
    try {
      _proc?.kill(ProcessSignal.sigterm);
    } catch (_) {}
    _proc = null;
    if (state != BackendState.external) _set(BackendState.idle, 'Server dihentikan.');
  }
}
