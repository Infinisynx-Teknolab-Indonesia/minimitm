import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';

class ApkPage extends StatefulWidget {
  const ApkPage({super.key});
  @override
  State<ApkPage> createState() => _ApkPageState();
}

class _ApkPageState extends State<ApkPage> {
  final _apk = TextEditingController();
  Map<String, dynamic> _tools = {};
  String _log = '';
  String _output = '';
  bool _busy = false;
  List<Map<String, dynamic>>? _installSteps;

  // ---- Tab aktif: 0 = Decompile & reFlutter, 1 = Recompile & Resign, 2 = Cari data sensitif ----
  int _section = 0;

  // ---- Tab 2: Recompile & Resign ----
  final _srcDir = TextEditingController(); // folder hasil 'Decode (apktool)'
  final _buildOut = TextEditingController(); // path .apk hasil 'Build'
  bool _patchingManifest = false, _building = false, _signing = false;

  // ---- Cari keystore / key (JWT, PEM, API key, dst) ----
  bool _scanning = false;
  List<Map<String, dynamic>>? _findings;
  List<Map<String, dynamic>> _hosts = [];
  List<Map<String, dynamic>> _weaknesses = [];
  String _scanLog = '';
  String _findingFilter = 'semua';

  // ---- Tab 3 (tambahan): pindai HASIL DECOMPILE sbg teks sumber -- lebih reliabel
  // utk key bernama (mis. "HMAC key"/"signing key") drpd pemindaian ZIP mentah ----
  final _srcScanDir = TextEditingController();
  bool _scanningSrc = false;
  String _srcScanLog = '';

  // ---- Tab 5: Suntik .so (engine) ----
  final _soSrcDir = TextEditingController();  // folder hasil 'Decode (apktool)'
  final _soFiles = TextEditingController();   // path .so (satu per baris)
  final _soLibName = TextEditingController(); // opsional: nama utk System.loadLibrary
  final _soAbis = TextEditingController();    // opsional: koma-pisah; kosong = auto
  bool _soAddLoader = true;
  bool _soTrustCa = false;
  bool _injecting = false;

  // ---- Tab 4: Cari dengan AI ----
  final _aiDir = TextEditingController();
  final _aiQuestion = TextEditingController(
      text: 'Temukan HMAC/signing key, API key, password, dan data sensitif lain. Sebutkan lokasinya (file:baris) dan tingkat keyakinanmu.');
  bool _aiSearching = false;
  String? _aiAnswer;
  List<String> _aiFilesUsed = [];
  String _aiLog = '';
  String? _aiError;

  /// Dialog pilih file bawaan Windows (System.Windows.Forms), tanpa perlu paket Flutter
  /// tambahan: cukup panggil powershell sebagai proses anak, seperti backend Python
  /// yang sudah dijalankan lewat Process.start di services/backend.dart.
  Future<void> _browseApk() async {
    if (!Platform.isWindows) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          tr('Pilih file otomatis baru didukung di Windows. Ketik path APK secara manual.',
              'Auto file picker is Windows-only for now. Type the APK path manually.'))));
      return;
    }
    const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$f = New-Object System.Windows.Forms.OpenFileDialog
$f.Filter = "APK files (*.apk)|*.apk|All files (*.*)|*.*"
$f.Title = "Pilih file APK"
if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $f.FileName }
''';
    try {
      final r = await Process.run('powershell', ['-NoProfile', '-STA', '-Command', script]);
      final path = (r.stdout as String).trim();
      if (path.isNotEmpty && mounted) setState(() => _apk.text = path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Gagal membuka dialog file', 'Could not open file dialog')}: $e')));
      }
    }
  }

  /// Sama seperti _browseApk tapi untuk memilih FOLDER (dipakai di tab Recompile & Resign
  /// utk pilih folder hasil 'Decode (apktool)', dan di tab Cari data sensitif utk folder
  /// hasil jadx/apktool).
  Future<void> _browseFolder(TextEditingController ctl) async {
    if (!Platform.isWindows) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          tr('Pilih folder otomatis baru didukung di Windows. Ketik path secara manual.',
              'Auto folder picker is Windows-only for now. Type the path manually.'))));
      return;
    }
    const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$f = New-Object System.Windows.Forms.FolderBrowserDialog
if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $f.SelectedPath }
''';
    try {
      final r = await Process.run('powershell', ['-NoProfile', '-STA', '-Command', script]);
      final path = (r.stdout as String).trim();
      if (path.isNotEmpty && mounted) setState(() => ctl.text = path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Gagal membuka dialog folder', 'Could not open folder dialog')}: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _avail();
  }

  @override
  void dispose() {
    _apk.dispose();
    _srcDir.dispose();
    _buildOut.dispose();
    _srcScanDir.dispose();
    _aiDir.dispose();
    _aiQuestion.dispose();
    _soSrcDir.dispose();
    _soFiles.dispose();
    _soLibName.dispose();
    _soAbis.dispose();
    super.dispose();
  }

  /// Pilih satu atau beberapa file .so (Windows OpenFileDialog, multiselect).
  Future<void> _browseSo() async {
    if (!Platform.isWindows) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          tr('Pilih file otomatis baru didukung di Windows. Ketik path .so manual.',
              'Auto file picker is Windows-only for now. Type the .so path manually.'))));
      return;
    }
    const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$f = New-Object System.Windows.Forms.OpenFileDialog
$f.Filter = "Native libs (*.so)|*.so|All files (*.*)|*.*"
$f.Multiselect = $true
$f.Title = "Pilih file .so (boleh banyak)"
if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $f.FileNames -join "`n" }
''';
    try {
      final r = await Process.run('powershell', ['-NoProfile', '-STA', '-Command', script]);
      final paths = (r.stdout as String).trim();
      if (paths.isNotEmpty && mounted) {
        setState(() {
          final cur = _soFiles.text.trim();
          _soFiles.text = cur.isEmpty ? paths : '$cur\n$paths';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Gagal membuka dialog file', 'Could not open file dialog')}: $e')));
      }
    }
  }

  Future<void> _injectSo() async {
    final src = _soSrcDir.text.trim();
    final sos = _soFiles.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (src.isEmpty || sos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          tr('Isi folder source (hasil Decode) & minimal 1 file .so.', 'Set the source folder (from Decode) & at least one .so.'))));
      return;
    }
    final abis = _soAbis.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    setState(() { _injecting = true; _log = ''; _output = ''; });
    try {
      final r = await Api.instance.apkInjectSo(
        srcdir: src, soPaths: sos, libName: _soLibName.text.trim(),
        abis: abis, addLoader: _soAddLoader, trustCa: _soTrustCa,
      );
      if (!mounted) return;
      setState(() {
        _injecting = false;
        _log = (r['log'] ?? '').toString();
        if (r['ok'] == true) _output = (r['output'] ?? '').toString();
      });
    } catch (e) {
      if (mounted) setState(() { _injecting = false; _log = '$e'; });
    }
  }

  Future<void> _avail() async {
    try {
      _tools = await Api.instance.apkAvailability();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _patch() async {
    if (_apk.text.trim().isEmpty) return;
    setState(() { _busy = true; _log = ''; _output = ''; });
    final r = await Api.instance.apkPatch(_apk.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _log = (r['log'] ?? '').toString();
      _output = r['ok'] == true ? (r['output'] ?? '').toString() : '';
    });
  }

  Future<void> _jadx() async {
    if (_apk.text.trim().isEmpty) return;
    setState(() { _busy = true; _log = ''; _output = ''; });
    final r = await Api.instance.apkJadx(_apk.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _log = (r['log'] ?? '').toString();
      _output = r['ok'] == true ? (r['outdir'] ?? '').toString() : '';
      if (r['ok'] == true) {
        _srcScanDir.text = _output; // siap dipakai di tab "Cari data sensitif"
        if (_aiDir.text.trim().isEmpty) _aiDir.text = _output; // & di tab "Cari dengan AI"
      }
    });
  }

  /// apktool d: apk -> folder source (smali + res + AndroidManifest.xml). Hasilnya
  /// dipakai sbg titik awal tab "Recompile & Resign" (edit manual lalu build+sign).
  Future<void> _decode() async {
    if (_apk.text.trim().isEmpty) return;
    setState(() { _busy = true; _log = ''; _output = ''; });
    final r = await Api.instance.apkDecode(_apk.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _log = (r['log'] ?? '').toString();
      _output = r['ok'] == true ? (r['outdir'] ?? '').toString() : '';
      if (r['ok'] == true) {
        _srcDir.text = _output;
        if (_srcScanDir.text.trim().isEmpty) _srcScanDir.text = _output;
        if (_aiDir.text.trim().isEmpty) _aiDir.text = _output;
      }
    });
  }

  Future<void> _patchManifestOnly() async {
    if (_srcDir.text.trim().isEmpty) return;
    setState(() { _patchingManifest = true; _log = ''; });
    final r = await Api.instance.apkPatchManifest(_srcDir.text.trim());
    if (!mounted) return;
    setState(() { _patchingManifest = false; _log = (r['log'] ?? '').toString(); });
  }

  Future<void> _build() async {
    if (_srcDir.text.trim().isEmpty) return;
    setState(() { _building = true; _log = ''; });
    final r = await Api.instance.apkBuild(_srcDir.text.trim());
    if (!mounted) return;
    setState(() {
      _building = false;
      _log = (r['log'] ?? '').toString();
      if (r['ok'] == true) _buildOut.text = (r['output'] ?? '').toString();
    });
  }

  Future<void> _sign() async {
    if (_buildOut.text.trim().isEmpty) return;
    setState(() { _signing = true; _log = ''; _output = ''; });
    final r = await Api.instance.apkSign(_buildOut.text.trim());
    if (!mounted) return;
    setState(() {
      _signing = false;
      _log = (r['log'] ?? '').toString();
      _output = r['ok'] == true ? (r['output'] ?? '').toString() : '';
    });
  }

  Future<void> _reflutter() async {
    if (_apk.text.trim().isEmpty) return;
    setState(() { _busy = true; _log = ''; _output = ''; });
    final r = await Api.instance.apkReflutter(_apk.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _log = (r['log'] ?? '').toString();
      _output = r['ok'] == true ? (r['output'] ?? '').toString() : '';
    });
  }

  Future<void> _scanSecrets() async {
    if (_apk.text.trim().isEmpty) return;
    setState(() { _scanning = true; _findings = null; _hosts = []; _weaknesses = []; _scanLog = ''; _findingFilter = 'semua'; });
    try {
      final r = await Api.instance.apkSecrets(_apk.text.trim());
      if (!mounted) return;
      setState(() {
        _scanLog = (r['log'] ?? '').toString();
        _findings = r['ok'] == true ? ((r['findings'] as List?)?.cast<Map<String, dynamic>>() ?? []) : [];
        _hosts = ((r['hosts'] as List?)?.cast<Map<String, dynamic>>() ?? []);
        _weaknesses = ((r['weaknesses'] as List?)?.cast<Map<String, dynamic>>() ?? []);
      });
    } catch (e) {
      if (mounted) setState(() => _scanLog = '$e');
    }
    if (mounted) setState(() => _scanning = false);
  }

  /// Pindai folder HASIL DECOMPILE (jadx/apktool) sebagai teks sumber. Nama variabel/field
  /// biasanya utuh lagi di sini, jadi key bernama (mis. "HMAC key"/"signing key") yang
  /// TIDAK kelihatan di pemindaian ZIP mentah (classes.dex, tanpa konteks nama variabel)
  /// punya peluang jauh lebih besar untuk ketemu lewat jalur ini.
  Future<void> _scanSecretsDir() async {
    final dir = _srcScanDir.text.trim();
    if (dir.isEmpty) return;
    setState(() { _scanningSrc = true; _srcScanLog = ''; });
    try {
      final r = await Api.instance.apkSecretsDir(dir);
      if (!mounted) return;
      setState(() {
        _srcScanLog = (r['log'] ?? '').toString();
        final extra = r['ok'] == true ? ((r['findings'] as List?)?.cast<Map<String, dynamic>>() ?? []) : <Map<String, dynamic>>[];
        // gabung ke daftar temuan yang sama (dipakai bersama oleh _secretsCard), dedup ringan.
        final merged = [...(_findings ?? <Map<String, dynamic>>[])];
        final seen = merged.map((f) => '${f['category']}|${f['label']}|${f['file']}|${f['match']}').toSet();
        for (final f in extra) {
          final k = '${f['category']}|${f['label']}|${f['file']}|${f['match']}';
          if (seen.add(k)) merged.add(f);
        }
        _findings = merged;
      });
    } catch (e) {
      if (mounted) setState(() => _srcScanLog = '$e');
    }
    if (mounted) setState(() => _scanningSrc = false);
  }

  /// Tab 4 "Cari dengan AI": backend meranking file hasil decompile dgn heuristik,
  /// mengirim potongan relevan ke AI yg sudah diatur di Settings > AI, dan kalau AI
  /// minta lihat file tertentu lebih lengkap, ada 1 ronde tambahan otomatis. Lihat
  /// penjelasan lengkap di backend/apk_ai_search.py.
  Future<void> _aiSearch() async {
    final dir = _aiDir.text.trim();
    if (dir.isEmpty) return;
    setState(() { _aiSearching = true; _aiAnswer = null; _aiError = null; _aiFilesUsed = []; _aiLog = ''; });
    try {
      final r = await Api.instance.apkAiSearch(dir, _aiQuestion.text.trim());
      if (!mounted) return;
      setState(() {
        _aiLog = (r['log'] ?? '').toString();
        if (r['ok'] == true) {
          _aiAnswer = (r['answer'] ?? '').toString();
          _aiFilesUsed = ((r['files_used'] as List?)?.map((e) => e.toString()).toList() ?? []);
        } else {
          _aiError = (r['error'] ?? tr('Gagal.', 'Failed.')).toString();
        }
      });
    } catch (e) {
      if (mounted) setState(() => _aiError = '$e');
    }
    if (mounted) setState(() => _aiSearching = false);
  }

  /// Dialog "Save As" bawaan Windows + tulis file langsung dari Dart (tanpa butuh
  /// endpoint backend baru) -- memakai trik yang sama dengan _browseApk().
  Future<void> _saveReport(String suggestedName, String content) async {
    if (!Platform.isWindows) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          tr('Unduh laporan baru didukung di Windows untuk saat ini.', 'Report download is Windows-only for now.'))));
      return;
    }
    final script = '''
Add-Type -AssemblyName System.Windows.Forms
\$f = New-Object System.Windows.Forms.SaveFileDialog
\$f.Filter = "Text/JSON (*.txt;*.json)|*.txt;*.json|All files (*.*)|*.*"
\$f.FileName = "$suggestedName"
\$f.Title = "Simpan laporan APK Tools"
if (\$f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output \$f.FileName }
''';
    try {
      final r = await Process.run('powershell', ['-NoProfile', '-STA', '-Command', script]);
      final path = (r.stdout as String).trim();
      if (path.isEmpty) return;
      await File(path).writeAsString(content);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Disimpan ke', 'Saved to')}: $path')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Gagal menyimpan', 'Failed to save')}: $e')));
    }
  }

  String _reportText() {
    final b = StringBuffer();
    b.writeln('Mini MITM Proxy -- Laporan pindai APK');
    b.writeln('APK: ${_apk.text.trim()}');
    b.writeln('=' * 70);
    b.writeln();
    b.writeln('-- Kelemahan (dari AndroidManifest.xml) --');
    if (_weaknesses.isEmpty) {
      b.writeln('(tidak ada / manifest tidak terbaca)');
    } else {
      for (final w in _weaknesses) {
        b.writeln('[${(w['severity'] ?? '').toString().toUpperCase()}] ${w['title']}');
        b.writeln('  ${w['detail']}');
      }
    }
    b.writeln();
    b.writeln('-- Server/host yang dipanggil (${_hosts.length}) --');
    for (final h in _hosts) {
      b.writeln('${h['host']}  (${h['count']}x, contoh: ${h['example_url']}, pertama di: ${h['first_file']})');
    }
    b.writeln();
    b.writeln('-- Keystore/key/secret (${_findings?.length ?? 0}) --');
    for (final f in _findings ?? <Map<String, dynamic>>[]) {
      b.writeln('[${f['category']}] ${f['label']}');
      b.writeln('  file : ${f['file']}');
      b.writeln('  match: ${f['match']}');
      b.writeln();
    }
    return b.toString();
  }

  String _reportJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'apk': _apk.text.trim(),
      'weaknesses': _weaknesses,
      'hosts': _hosts,
      'findings': _findings ?? [],
    });
  }

  Future<void> _installTools() async {
    setState(() { _busy = true; _installSteps = null; });
    try {
      final r = await Api.instance.apkInstallTools();
      if (!mounted) return;
      setState(() => _installSteps = (r['steps'] as List?)?.cast<Map<String, dynamic>>());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _busy = false);
    await _avail();
  }

  static const _catOrder = ['keystore', 'pingone', 'oauth', 'otp', 'jwt', 'apikey', 'secret', 'crypto', 'db'];
  String _catLabel(String c) => switch (c) {
        'keystore' => tr('Keystore / PEM', 'Keystore / PEM'),
        'pingone' => 'PingOne',
        'oauth' => tr('OAuth/OIDC (client, redirect)', 'OAuth/OIDC (client, redirect)'),
        'otp' => tr('OTP / MFA (kirim & verifikasi)', 'OTP / MFA (send & verify)'),
        'jwt' => 'JWT',
        'apikey' => tr('API key', 'API key'),
        'secret' => tr('Password/secret/HMAC key', 'Password/secret/HMAC key'),
        'crypto' => tr('Pemakaian crypto (HMAC dsb.)', 'Crypto usage (HMAC etc.)'),
        'db' => tr('Koneksi DB', 'DB connection'),
        _ => c,
      };
  Color _catColor(String c) => switch (c) {
        'keystore' => YmColors.danger,
        'pingone' => YmColors.danger,
        'oauth' => YmColors.warning,
        'otp' => YmColors.warning,
        'jwt' => YmColors.warning,
        'apikey' => YmColors.danger,
        'secret' => YmColors.warning,
        'crypto' => YmColors.primary,
        'db' => YmColors.danger,
        _ => YmColors.outline,
      };

  String _sevLabel(String s) => switch (s) {
        'high' => tr('Tinggi', 'High'),
        'medium' => tr('Sedang', 'Medium'),
        'low' => tr('Rendah', 'Low'),
        _ => 'Info',
      };
  Color _sevColor(String s) => switch (s) {
        'high' => YmColors.danger,
        'medium' => YmColors.warning,
        'low' => YmColors.primary,
        _ => YmColors.outline,
      };
  static const _sevOrder = {'high': 0, 'medium': 1, 'low': 2, 'info': 3};

  Widget _weaknessesCard() {
    final list = List<Map<String, dynamic>>.from(_weaknesses)
      ..sort((a, b) => (_sevOrder[a['severity']] ?? 9).compareTo(_sevOrder[b['severity']] ?? 9));
    return HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.security_rounded, color: YmColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(tr('Kelemahan dari AndroidManifest.xml', 'Weaknesses from AndroidManifest.xml'), style: YmTextStyles.headlineSm),
        ]),
        const SizedBox(height: 4),
        Text(
          tr('Dibaca langsung dari manifest biner (tanpa apktool): debuggable, allowBackup, cleartext traffic, komponen exported tanpa permission, dan permission sensitif.',
              'Read directly from the binary manifest (no apktool needed): debuggable, allowBackup, cleartext traffic, exported components without a permission, and sensitive permissions.'),
          style: YmTextStyles.labelSm.copyWith(color: YmColors.outline),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Text(tr('Tidak ada temuan (atau manifest gagal diurai).', 'No findings (or the manifest could not be parsed).'), style: YmTextStyles.bodySm)
        else
          ...list.map((w) {
            final sev = (w['severity'] ?? 'info').toString();
            final color = _sevColor(sev);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.25))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  SoftChip(_sevLabel(sev), pill: true, bold: true, fg: color, bg: color.withOpacity(0.12)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(w['title']?.toString() ?? '', style: YmTextStyles.labelSm.copyWith(fontWeight: FontWeight.w600))),
                ]),
                const SizedBox(height: 4),
                Text(w['detail']?.toString() ?? '', style: YmTextStyles.bodySm),
              ]),
            );
          }),
      ]),
    );
  }

  Widget _hostsCard() {
    return HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.dns_rounded, color: YmColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(tr('Server / host yang dipanggil', 'Servers / hosts called'), style: YmTextStyles.headlineSm),
          const Spacer(),
          Text('${_hosts.length}', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
        ]),
        const SizedBox(height: 4),
        Text(
          tr('Semua host dari URL http(s) yang disebut di dalam APK (termasuk string di classes.dex), diringkas per host.',
              'Every host from http(s) URLs mentioned inside the APK (including strings in classes.dex), summarized per host.'),
          style: YmTextStyles.labelSm.copyWith(color: YmColors.outline),
        ),
        const SizedBox(height: 12),
        if (_hosts.isEmpty)
          Text(tr('Tidak ada URL http/https yang ketemu.', 'No http/https URLs found.'), style: YmTextStyles.bodySm)
        else
          ..._hosts.map((h) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.circle, size: 5, color: YmColors.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(h['host']?.toString() ?? '', style: YmTextStyles.mono.copyWith(fontWeight: FontWeight.w600)),
                      Text('${h['count']}x — ${h['example_url']}', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
                    ]),
                  ),
                  IconButton(
                    tooltip: tr('Salin', 'Copy'),
                    icon: Icon(Icons.copy_rounded, size: 14, color: YmColors.outline),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: h['host']?.toString() ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Disalin.', 'Copied.'))));
                    },
                  ),
                ]),
              )),
      ]),
    );
  }

  Widget _secretsCard() {
    final list = _findings ?? [];
    final counts = <String, int>{};
    for (final f in list) counts[f['category'] as String] = (counts[f['category'] as String] ?? 0) + 1;
    final shown = _findingFilter == 'semua' ? list : list.where((f) => f['category'] == _findingFilter).toList();

    return HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.key_rounded, color: YmColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(tr('Keystore, PingOne, OTP & key yang ditemukan', 'Keystore, PingOne, OTP & keys found'), style: YmTextStyles.headlineSm),
          const Spacer(),
          Text('${list.length} ${tr('temuan', 'findings')}', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
        ]),
        const SizedBox(height: 4),
        Text(
          tr('Pindai mentah isi APK (zip + string di classes.dex): keystore/PEM, environment & domain PingOne, client_id/redirect_uri OAuth, endpoint & fungsi kirim/verifikasi OTP, JWT, API key, password, dan connection string DB. Bukan jaminan lengkap — secret yang dienkripsi/di-obfuscate bisa tidak kelihatan, dan bisa ada salah tangkap.',
              'Raw scan of the APK contents (zip + strings inside classes.dex): keystore/PEM, PingOne environment & domain, OAuth client_id/redirect_uri, OTP send/verify endpoints & function names, JWT, API keys, passwords, and DB connection strings. Not exhaustive — encrypted/obfuscated secrets may be missed, and some matches can be false positives.'),
          style: YmTextStyles.labelSm.copyWith(color: YmColors.outline),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Row(children: [
            Icon(Icons.check_circle_outline_rounded, size: 16, color: YmColors.success),
            const SizedBox(width: 8),
            Text(tr('Tidak ada keystore/key/JWT/API-key yang kena pola pemindaian.', 'No keystore/key/JWT/API-key matched the scan patterns.'), style: YmTextStyles.bodySm),
          ])
        else ...[
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(label: Text('${tr('Semua', 'All')} (${list.length})'), selected: _findingFilter == 'semua', onSelected: (_) => setState(() => _findingFilter = 'semua')),
            for (final c in _catOrder)
              if (counts[c] != null)
                ChoiceChip(label: Text('${_catLabel(c)} (${counts[c]})'), selected: _findingFilter == c, onSelected: (_) => setState(() => _findingFilter = c)),
          ]),
          const SizedBox(height: 12),
          ...shown.map((f) {
            final cat = f['category'] as String;
            final color = _catColor(cat);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.25))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  SoftChip(_catLabel(cat), pill: true, bold: true, fg: color, bg: color.withOpacity(0.12)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f['label']?.toString() ?? '', style: YmTextStyles.labelSm.copyWith(fontWeight: FontWeight.w600))),
                  IconButton(
                    tooltip: tr('Salin', 'Copy'),
                    icon: Icon(Icons.copy_rounded, size: 14, color: YmColors.outline),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: f['match']?.toString() ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Disalin.', 'Copied.'))));
                    },
                  ),
                ]),
                const SizedBox(height: 4),
                Text(f['file']?.toString() ?? '', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontFamily: 'monospace')),
                const SizedBox(height: 4),
                SelectableText(f['match']?.toString() ?? '', style: YmTextStyles.mono),
              ]),
            );
          }),
        ],
        if (_scanLog.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_scanLog, style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            crumbs: [tr('Alat', 'Tools'), 'APK Tools'],
            title: 'APK Tools',
            subtitle: tr('Decompile & patch APK agar percaya CA-mu (trust user CA + debuggable). Butuh java/apktool/jadx di PATH. Hanya untuk APK milikmu.',
                'Decompile & patch an APK to trust your CA (user CA + debuggable). Needs java/apktool/jadx on PATH. Only for your own APK.'),
          ),
          const SizedBox(height: 16),
          HoverCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(tr('Tool terdeteksi', 'Detected tools'), style: YmTextStyles.headlineSm),
                const Spacer(),
                ElevatedButton.icon(onPressed: _busy ? null : _installTools, icon: const Icon(Icons.download_rounded, size: 16), label: Text(tr('Install tool otomatis', 'Auto-install tools'))),
                const SizedBox(width: 8),
                OutlinedButton.icon(onPressed: _busy ? null : _avail, icon: const Icon(Icons.refresh_rounded, size: 16), label: Text(tr('Cek', 'Check'))),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in ['java', 'apktool', 'jadx', 'zipalign', 'apksigner', 'keytool', 'jarsigner', 'uber_signer', 'reflutter'])
                  SoftChip(
                    t == 'uber_signer' ? 'uber-signer' : t,
                    icon: (_tools[t] ?? '').toString().isNotEmpty ? Icons.check_rounded : Icons.close_rounded,
                    fg: (_tools[t] ?? '').toString().isNotEmpty ? YmColors.onSuccessSoft : YmColors.onDangerSoft,
                    bg: (_tools[t] ?? '').toString().isNotEmpty ? YmColors.successContainer.withOpacity(0.4) : YmColors.dangerSoft,
                    pill: true, bold: true,
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  tr('Untuk tanda tangan kamu TIDAK wajib menyiapkan apa pun: saat "3) Tanda tangani" dijalankan, sertifikat debug dibuat otomatis. Kalau uber-signer & Android SDK belum ada, uber-signer diunduh otomatis; kalau offline dipakai keytool+jarsigner (sudah ikut JDK). Jadi cukup pastikan "java" hijau.',
                      'You do NOT need to prepare anything to sign: when "3) Sign" runs, a debug certificate is created automatically. If uber-signer & the Android SDK are missing, uber-signer is auto-downloaded; offline it falls back to keytool+jarsigner (bundled with the JDK). So just make sure "java" is green.'),
                  style: YmTextStyles.labelSm.copyWith(color: YmColors.outline),
                ),
              ),
              if (_installSteps != null) ...[
                const SizedBox(height: 10),
                ..._installSteps!.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(s['ok'] == true ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 15, color: s['ok'] == true ? YmColors.success : YmColors.danger),
                        const SizedBox(width: 6),
                        Expanded(child: Text('${s['step']}${(s['out'] as String?)?.isNotEmpty == true ? ' — ${s['out']}' : ''}', style: YmTextStyles.labelSm)),
                      ]),
                    )),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          SegmentedToggle<int>(
            value: _section,
            items: [
              (0, tr('1. Decompile & reFlutter', '1. Decompile & reFlutter')),
              (1, tr('2. Recompile & Resign', '2. Recompile & Resign')),
              (2, tr('3. Cari data sensitif', '3. Find sensitive data')),
              (3, tr('4. Cari dengan AI', '4. AI search')),
              (4, tr('5. Suntik .so (engine)', '5. Inject .so (engine)')),
            ],
            onChanged: (v) => setState(() => _section = v),
          ),
          const SizedBox(height: 16),
          switch (_section) {
            0 => _tabDecompile(),
            1 => _tabRecompile(),
            2 => _tabSecrets(),
            3 => _tabAiSearch(),
            _ => _tabInjectSo(),
          },
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: YmColors.warningSoft.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 18, color: YmColors.onWarningSoft),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('App Flutter murni mengabaikan CA store Android — patch ini membantu app non-Flutter & WebView. Untuk Flutter release perlu reFlutter / Frida.',
                  'Pure Flutter apps ignore the Android CA store — this patch helps non-Flutter apps & WebView. For Flutter release you need reFlutter / Frida.'), style: YmTextStyles.labelSm.copyWith(color: YmColors.onWarningSoft))),
            ]),
          ),
          if (_log.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Log', style: YmTextStyles.sectionTitle),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 260,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF0B0F1A), borderRadius: BorderRadius.circular(8)),
              child: SingleChildScrollView(child: SelectableText(_log, style: const TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Consolas', 'monospace'], fontSize: 11, height: 1.4, color: Color(0xFFCDE3FF)))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _outputBox(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: YmColors.successContainer.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(Icons.check_circle_rounded, size: 16, color: YmColors.success),
        const SizedBox(width: 8),
        Expanded(child: SelectableText('$label: $value', style: YmTextStyles.mono)),
        IconButton(icon: Icon(Icons.copy_rounded, size: 15, color: YmColors.outline), onPressed: () { Clipboard.setData(ClipboardData(text: value)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Disalin.', 'Copied.')))); }),
      ]),
    );
  }

  Widget _busyRow() => Row(children: [
        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: YmColors.primary)),
        const SizedBox(width: 10),
        Text(tr('Memproses… (bisa 1-2 menit)', 'Working… (may take 1-2 min)'), style: YmTextStyles.bodySm),
      ]);

  // ---------------------------------------------------------------------
  // Tab 1: Decompile & reFlutter
  // ---------------------------------------------------------------------
  Widget _tabDecompile() {
    return HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Decompile & reFlutter', 'Decompile & reFlutter'), style: YmTextStyles.headlineSm),
        const SizedBox(height: 4),
        Text(
          tr('Bongkar isi APK jadi sumber yang bisa dibaca/diedit, atau patch khusus app Flutter dengan reFlutter.',
              'Unpack the APK into readable/editable source, or patch a Flutter app specifically with reFlutter.'),
          style: YmTextStyles.labelSm.copyWith(color: YmColors.outline),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _apk,
          style: YmTextStyles.mono,
          decoration: InputDecoration(
            labelText: tr('Path file APK', 'APK file path'),
            hintText: r'C:\Users\kamu\app.apk',
            suffixIcon: IconButton(
              tooltip: tr('Pilih file…', 'Browse…'),
              icon: const Icon(Icons.folder_open_rounded, size: 20),
              onPressed: _busy || _scanning ? null : _browseApk,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ElevatedButton.icon(
            onPressed: _busy ? null : _decode,
            icon: const Icon(Icons.folder_zip_rounded, size: 18),
            label: Text(tr('Decode (apktool) → folder source', 'Decode (apktool) → source folder')),
          ),
          OutlinedButton.icon(onPressed: _busy ? null : _jadx, icon: const Icon(Icons.code_rounded, size: 18), label: Text(tr('Decompile (jadx)', 'Decompile (jadx)'))),
          OutlinedButton.icon(onPressed: _busy ? null : _reflutter, icon: const Icon(Icons.flutter_dash, size: 18), label: Text(tr('reFlutter + Sign (app Flutter, otomatis)', 'reFlutter + Sign (Flutter app, automatic)'))),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            tr('"Decode (apktool)" -> dipakai di tab "Recompile & Resign" utk diedit lalu dibangun ulang. "Decompile (jadx)" -> .java yang enak dibaca, dipakai juga di tab "Cari data sensitif" utk menelusuri key bernama (mis. HMAC key) yang tak kelihatan di pemindaian APK mentah.',
                '"Decode (apktool)" -> used in the "Recompile & Resign" tab to edit and rebuild. "Decompile (jadx)" -> readable .java, also used in "Find sensitive data" to trace named keys (e.g. an HMAC key) that a raw APK scan misses.'),
            style: YmTextStyles.labelSm.copyWith(color: YmColors.outline),
          ),
        ),
        if (_busy) ...[const SizedBox(height: 12), _busyRow()],
        if (_output.isNotEmpty) ...[const SizedBox(height: 12), _outputBox(tr('Hasil', 'Output'), _output)],
      ]),
    );
  }

  // ---------------------------------------------------------------------
  // Tab 2: Recompile & Resign
  // ---------------------------------------------------------------------
  // -------------------------------------------------------------------------
  // Tab 5: Suntik .so (engine) -> recompile -> self-sign
  // -------------------------------------------------------------------------
  Widget _tabInjectSo() {
    final soCount = _soFiles.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).length;
    final canRun = _soSrcDir.text.trim().isNotEmpty && soCount > 0 && !_injecting;
    return HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Suntik .so (engine) + Recompile + Sign', 'Inject .so (engine) + Recompile + Sign'), style: YmTextStyles.headlineSm),
        const SizedBox(height: 4),
        Text(
          tr('Salin native lib (.so) — mis. engine instrumentasi / frida-gadget — ke lib/<abi>/ pada folder hasil "Decode (apktool)", opsional sisipkan System.loadLibrary supaya dimuat saat app jalan, lalu langsung build ulang + tanda tangani. Hanya untuk APK milikmu.',
              'Copy a native lib (.so) — e.g. an instrumentation engine / frida-gadget — into lib/<abi>/ of the "Decode (apktool)" folder, optionally inject System.loadLibrary so it loads at runtime, then rebuild + sign in one go. Only for your own APK.'),
          style: YmTextStyles.labelSm.copyWith(color: YmColors.outline),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _soSrcDir,
          style: YmTextStyles.mono,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: tr('Folder source (hasil "Decode (apktool)" di tab 1)', 'Source folder (from "Decode (apktool)" in tab 1)'),
            hintText: r'C:\...\apk_work\src',
            suffixIcon: IconButton(
              tooltip: tr('Pilih folder…', 'Browse…'),
              icon: const Icon(Icons.folder_open_rounded, size: 20),
              onPressed: () => _browseFolder(_soSrcDir),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _soFiles,
          style: YmTextStyles.mono,
          minLines: 2,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: tr('File .so (satu per baris)', '.so files (one per line)'),
            hintText: r'C:\...\libengine.so',
            alignLabelWithHint: true,
            suffixIcon: IconButton(
              tooltip: tr('Pilih file .so…', 'Browse .so…'),
              icon: const Icon(Icons.folder_open_rounded, size: 20),
              onPressed: _injecting ? null : _browseSo,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _soLibName,
              style: YmTextStyles.mono,
              decoration: InputDecoration(
                labelText: tr('Nama loadLibrary (opsional)', 'loadLibrary name (optional)'),
                hintText: tr('kosong = dari nama file (libX.so → X)', 'empty = from filename (libX.so → X)'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _soAbis,
              style: YmTextStyles.mono,
              decoration: InputDecoration(
                labelText: tr('ABI (opsional, koma)', 'ABIs (optional, comma)'),
                hintText: tr('kosong = auto (ikut lib/ yang ada)', 'empty = auto (match existing lib/)'),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Switch(value: _soAddLoader, onChanged: _injecting ? null : (v) => setState(() => _soAddLoader = v)),
          Expanded(child: Text(tr('Sisipkan System.loadLibrary di Application/launcher (best-effort)', 'Inject System.loadLibrary into Application/launcher (best-effort)'), style: YmTextStyles.labelMd.copyWith(color: YmColors.textMuted))),
        ]),
        Row(children: [
          Switch(value: _soTrustCa, onChanged: _injecting ? null : (v) => setState(() => _soTrustCa = v)),
          Expanded(child: Text(tr('Sekalian trust CA + debuggable (network_security_config)', 'Also trust CA + debuggable (network_security_config)'), style: YmTextStyles.labelMd.copyWith(color: YmColors.textMuted))),
        ]),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: canRun ? _injectSo : null,
          icon: _injecting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.vaccines_rounded, size: 18),
          label: Text(tr('Suntik .so → Recompile → Sign', 'Inject .so → Recompile → Sign')),
        ),
        const SizedBox(height: 8),
        Text(
          tr('Loader "best-effort": kalau kelas Application/launcher tak terdeteksi, lib tetap disalin tapi app harus memanggil System.loadLibrary("<nama>") sendiri. Cek Log untuk detailnya.',
              'The loader is best-effort: if the Application/launcher class isn\'t detected, the lib is still copied but the app must call System.loadLibrary("<name>") itself. See the Log for details.'),
          style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontStyle: FontStyle.italic),
        ),
        if (_output.isNotEmpty) ...[const SizedBox(height: 12), _outputBox(tr('APK siap pasang', 'Ready-to-install APK'), _output)],
      ]),
    );
  }

  Widget _tabRecompile() {
    final canBuild = _srcDir.text.trim().isNotEmpty;
    final canSign = _buildOut.text.trim().isNotEmpty;
    return HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('Recompile & Resign', 'Recompile & Resign'), style: YmTextStyles.headlineSm),
        const SizedBox(height: 4),
        Text(
          tr('Setelah decode & edit manual (mis. di folder hasil tab 1), bangun ulang APK-nya lalu tanda tangani supaya bisa diinstal. Atau pakai jalur 1-klik di bawah kalau cuma mau trust CA + debuggable tanpa edit apa-apa.',
              'After decode & manual edits (e.g. in the folder from tab 1), rebuild the APK then sign it so it installs. Or use the 1-click path below if you only want trust-CA + debuggable with no manual edits.'),
          style: YmTextStyles.labelSm.copyWith(color: YmColors.outline),
        ),
        const SizedBox(height: 14),

        // --- jalur 1-klik (otomatis, dari path APK asli) ---
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Jalur cepat: 1 klik (decode → patch → build → sign)', 'Fast path: 1 click (decode → patch → build → sign)'), style: YmTextStyles.labelMd.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _apk,
              style: YmTextStyles.mono,
              decoration: InputDecoration(
                labelText: tr('Path file APK asli', 'Original APK file path'),
                hintText: r'C:\Users\kamu\app.apk',
                suffixIcon: IconButton(
                  tooltip: tr('Pilih file…', 'Browse…'),
                  icon: const Icon(Icons.folder_open_rounded, size: 20),
                  onPressed: _busy ? null : _browseApk,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(onPressed: _busy ? null : _patch, icon: const Icon(Icons.build_rounded, size: 18), label: Text(tr('Patch untuk proxy (1 klik)', 'Patch for proxy (1-click)'))),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [Expanded(child: Divider(color: YmColors.line)), Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(tr('atau manual, langkah demi langkah', 'or manually, step by step'), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline))), Expanded(child: Divider(color: YmColors.line))]),
        const SizedBox(height: 16),

        // --- jalur manual ---
        TextField(
          controller: _srcDir,
          style: YmTextStyles.mono,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: tr('Folder source (hasil "Decode (apktool)" di tab 1)', 'Source folder (from "Decode (apktool)" in tab 1)'),
            hintText: r'C:\...\apk_work\src',
            suffixIcon: IconButton(
              tooltip: tr('Pilih folder…', 'Browse…'),
              icon: const Icon(Icons.folder_open_rounded, size: 20),
              onPressed: () => _browseFolder(_srcDir),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: (!canBuild || _patchingManifest) ? null : _patchManifestOnly,
            icon: _patchingManifest ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: YmColors.primary)) : const Icon(Icons.shield_rounded, size: 18),
            label: Text(tr('1) Patch manifest (trust CA)', '1) Patch manifest (trust CA)')),
          ),
          ElevatedButton.icon(
            onPressed: (!canBuild || _building) ? null : _build,
            icon: _building ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.construction_rounded, size: 18),
            label: Text(tr('2) Build (apktool b)', '2) Build (apktool b)')),
          ),
          OutlinedButton.icon(
            onPressed: (!canSign || _signing) ? null : _sign,
            icon: _signing ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: YmColors.primary)) : const Icon(Icons.edit_document, size: 18),
            label: Text(tr('3) Tanda tangani (sign)', '3) Sign')),
          ),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _buildOut,
          style: YmTextStyles.mono,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: tr('.apk hasil build (belum ditandatangani) — bisa diisi manual juga', 'Built .apk (unsigned) — can be typed manually too'),
            hintText: r'C:\...\apk_work\rebuilt.apk',
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            tr('Langkah 1 opsional (cuma kalau kamu ingin trust-CA ditambahkan otomatis, selain editan manualmu sendiri). Langkah 2 & 3 wajib supaya APK bisa diinstal lagi. Langkah 3 membuat SERTIFIKAT DEBUG OTOMATIS — kamu tak perlu menyiapkan keystore sendiri; kalau belum ada alat tanda tangan, uber-apk-signer diunduh otomatis, dan kalau offline dipakai keytool+jarsigner bawaan JDK.',
                'Step 1 is optional (only if you also want trust-CA added automatically, on top of your own manual edits). Steps 2 & 3 are required for the APK to install again. Step 3 CREATES THE DEBUG CERTIFICATE AUTOMATICALLY — no need to prepare a keystore yourself; if no signer is present uber-apk-signer is auto-downloaded, and offline it falls back to the JDK keytool+jarsigner.'),
            style: YmTextStyles.labelSm.copyWith(color: YmColors.outline),
          ),
        ),
        if (_busy || _patchingManifest || _building || _signing) ...[const SizedBox(height: 12), _busyRow()],
        if (_output.isNotEmpty) ...[const SizedBox(height: 12), _outputBox(tr('APK siap pasang', 'Ready-to-install APK'), _output)],
      ]),
    );
  }

  // ---------------------------------------------------------------------
  // Tab 3: Cari data sensitif
  // ---------------------------------------------------------------------
  Widget _tabSecrets() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      HoverCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Pindai APK mentah (tanpa decompile)', 'Scan raw APK (no decompile)'), style: YmTextStyles.headlineSm),
          const SizedBox(height: 4),
          Text(
            tr('Cepat, tapi hanya menangkap string yang berdiri sendiri (PEM, JWT, prefix API-key vendor, dll). Key bernama yang namanya dibuang saat kompilasi (mis. "HMAC key") sering TIDAK kena jalur ini — pakai pemindaian hasil decompile di bawah untuk itu.',
                'Fast, but only catches self-describing strings (PEM, JWT, vendor API-key prefixes, etc). A named key whose variable name is stripped at compile time (e.g. an "HMAC key") is often MISSED here — use the decompiled-source scan below for that.'),
            style: YmTextStyles.labelSm.copyWith(color: YmColors.outline),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apk,
            style: YmTextStyles.mono,
            decoration: InputDecoration(
              labelText: tr('Path file APK', 'APK file path'),
              hintText: r'C:\Users\kamu\app.apk',
              suffixIcon: IconButton(
                tooltip: tr('Pilih file…', 'Browse…'),
                icon: const Icon(Icons.folder_open_rounded, size: 20),
                onPressed: _scanning ? null : _browseApk,
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _scanning ? null : _scanSecrets,
            icon: _scanning
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: YmColors.primary))
                : const Icon(Icons.key_rounded, size: 18),
            label: Text(tr('Cari keystore, PingOne, OTP & key…', 'Find keystore, PingOne, OTP & keys…')),
          ),
          if (_scanLog.isNotEmpty) ...[const SizedBox(height: 8), Text(_scanLog, style: YmTextStyles.labelSm.copyWith(color: YmColors.outline))],
        ]),
      ),
      const SizedBox(height: 16),
      HoverCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.manage_search_rounded, color: YmColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(tr('Pindai folder hasil decompile (lebih akurat utk key bernama)', 'Scan decompiled source folder (more accurate for named keys)'), style: YmTextStyles.headlineSm),
          ]),
          const SizedBox(height: 4),
          Text(
            tr('Dipindai sebagai TEKS SUMBER (.java/.kt/.smali/.xml/.json/...) dari folder hasil "Decompile (jadx)" atau "Decode (apktool)" di tab 1 — bukan ZIP mentah. Di sini nama variabel/field biasanya utuh lagi, jadi key bernama "HMAC key"/"signing key"/dst. (yang tidak kelihatan di pemindaian mentah di atas, karena nama variabel dibuang saat kompilasi ke classes.dex) punya peluang jauh lebih besar ketemu di sini.',
                'Scanned as SOURCE TEXT (.java/.kt/.smali/.xml/.json/...) from the folder produced by "Decompile (jadx)" or "Decode (apktool)" in tab 1 — not the raw ZIP. Variable/field names are usually intact here, so a named key like "HMAC key"/"signing key" (invisible to the raw scan above, since variable names are stripped when compiling to classes.dex) has a much better chance of turning up here.'),
            style: YmTextStyles.labelSm.copyWith(color: YmColors.outline),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _srcScanDir,
            style: YmTextStyles.mono,
            decoration: InputDecoration(
              labelText: tr('Folder hasil decompile (jadx atau apktool)', 'Decompiled folder (jadx or apktool)'),
              hintText: r'C:\...\apk_work\jadx',
              suffixIcon: IconButton(
                tooltip: tr('Pilih folder…', 'Browse…'),
                icon: const Icon(Icons.folder_open_rounded, size: 20),
                onPressed: () => _browseFolder(_srcScanDir),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _scanningSrc ? null : _scanSecretsDir,
            icon: _scanningSrc
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: YmColors.primary))
                : const Icon(Icons.travel_explore_rounded, size: 18),
            label: Text(tr('Pindai folder hasil decompile', 'Scan decompiled folder')),
          ),
          if (_srcScanLog.isNotEmpty) ...[const SizedBox(height: 8), Text(_srcScanLog, style: YmTextStyles.labelSm.copyWith(color: YmColors.outline))],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: YmColors.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lightbulb_outline_rounded, size: 16, color: YmColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(
                tr('Kalau masih tidak ketemu: cari kategori "Pemakaian crypto (HMAC dsb.)" di hasil di bawah untuk tahu file mana yang memanggil Mac/SecretKeySpec, lalu buka file itu manual — key-nya mungkin dirakit dari beberapa potongan string, diambil dari native lib (.so), atau diambil dari server saat runtime (jadi memang tidak ada di dalam APK sama sekali).',
                    'Still not found? Look for the "Crypto usage (HMAC etc.)" category in the results below to see which file calls Mac/SecretKeySpec, then open that file manually — the key may be assembled from several string pieces, pulled from a native lib (.so), or fetched from a server at runtime (so it genuinely isn\'t inside the APK at all).'),
                style: YmTextStyles.labelSm,
              )),
            ]),
          ),
        ]),
      ),
      if (_findings != null) ...[
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: () => _saveReport('apk-report.txt', _reportText()),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: Text(tr('Unduh laporan (.txt)', 'Download report (.txt)')),
          ),
          OutlinedButton.icon(
            onPressed: () => _saveReport('apk-report.json', _reportJson()),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: Text(tr('Unduh laporan (.json)', 'Download report (.json)')),
          ),
        ]),
        const SizedBox(height: 16),
        _weaknessesCard(),
        const SizedBox(height: 16),
        _hostsCard(),
        const SizedBox(height: 16),
        _secretsCard(),
      ],
    ]);
  }

  // ---------------------------------------------------------------------
  // Tab 4: Cari dengan AI
  // ---------------------------------------------------------------------
  Widget _tabAiSearch() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      HoverCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.auto_awesome_rounded, color: YmColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(tr('Cari dengan AI', 'AI search'), style: YmTextStyles.headlineSm),
          ]),
          const SizedBox(height: 4),
          Text(
            tr('Begini cara kerjanya, biar ekspektasinya pas: AI TIDAK membaca seluruh project (bisa ribuan file). '
                    'Backend dulu me-ranking file hasil decompile yang paling mungkin relevan dgn heuristik kata kunci, '
                    'lalu mengirim potongan di sekitar kata kunci itu (bukan seluruh file) ke AI yang sudah kamu atur '
                    'di menu Pengaturan > AI. Kalau AI merasa perlu lihat isi lengkap salah satu file yang sudah '
                    'disebut namanya, ada 1 ronde tambahan otomatis utk itu. Jadi ini "AI-assisted grep" — bisa '
                    'menelusuri hubungan antar potongan kode (mis. key yang dirakit dari beberapa variabel) yang '
                    'susah ditangkap regex biasa, tapi tetap heuristik: bisa salah/lewat, dan AI diminta tidak mengarang.',
                'Here\'s how it actually works, so expectations are right: the AI does NOT read the whole project '
                    '(could be thousands of files). The backend first ranks decompiled files most likely relevant using '
                    'keyword heuristics, then sends the snippets around those keywords (not whole files) to the AI '
                    'configured in Settings > AI. If the AI feels it needs the full content of a file it already saw '
                    'named, there\'s one automatic extra round for that. So this is "AI-assisted grep" — it can trace '
                    'relationships across code snippets (e.g. a key assembled from several variables) that plain regex '
                    'struggles with, but it\'s still heuristic: it can miss things, and the AI is told not to invent answers.'),
            style: YmTextStyles.labelSm.copyWith(color: YmColors.outline),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _aiDir,
            style: YmTextStyles.mono,
            decoration: InputDecoration(
              labelText: tr('Folder hasil decompile (jadx atau apktool)', 'Decompiled folder (jadx or apktool)'),
              hintText: r'C:\...\apk_work\jadx',
              suffixIcon: IconButton(
                tooltip: tr('Pilih folder…', 'Browse…'),
                icon: const Icon(Icons.folder_open_rounded, size: 20),
                onPressed: () => _browseFolder(_aiDir),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _aiQuestion,
            style: YmTextStyles.bodySm,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: tr('Pertanyaan utk AI (boleh diedit)', 'Question for the AI (editable)'),
              hintText: tr('mis. "di mana public key utk HMAC dipakai buat tanda tangan request?"',
                  'e.g. "where is the public key used for HMAC request signing?"'),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ElevatedButton.icon(
              onPressed: _aiSearching ? null : _aiSearch,
              icon: _aiSearching
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(tr('Cari dengan AI', 'Search with AI')),
            ),
            Text(
              tr('Pakai AI yang diatur di menu Pengaturan > AI (lokal/OpenAI-compatible/Ollama).',
                  'Uses the AI configured in the Settings > AI menu (local/OpenAI-compatible/Ollama).'),
              style: YmTextStyles.labelSm.copyWith(color: YmColors.outline),
            ),
          ]),
          if (_aiLog.isNotEmpty) ...[const SizedBox(height: 8), Text(_aiLog, style: YmTextStyles.labelSm.copyWith(color: YmColors.outline))],
          if (_aiError != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: YmColors.dangerSoft, borderRadius: BorderRadius.circular(8)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.error_outline_rounded, size: 16, color: YmColors.onDangerSoft),
                const SizedBox(width: 8),
                Expanded(child: SelectableText(_aiError!, style: YmTextStyles.bodySm.copyWith(color: YmColors.onDangerSoft))),
              ]),
            ),
          ],
        ]),
      ),
      if (_aiAnswer != null) ...[
        const SizedBox(height: 16),
        HoverCard(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 18, color: YmColors.primary),
              const SizedBox(width: 8),
              Text(tr('Jawaban AI', 'AI answer'), style: YmTextStyles.sectionTitle),
            ]),
            const SizedBox(height: 10),
            SelectableText(_aiAnswer!.isEmpty ? tr('(kosong)', '(empty)') : _aiAnswer!, style: YmTextStyles.bodySm),
            if (_aiFilesUsed.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(tr('File yang diperiksa AI (${_aiFilesUsed.length})', 'Files the AI examined (${_aiFilesUsed.length})'),
                  style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final f in _aiFilesUsed) SoftChip(f, pill: true),
              ]),
            ],
          ]),
        ),
      ],
    ]);
  }
}
