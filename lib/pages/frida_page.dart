import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';
import '../widgets/findable_view.dart';

/// Pasang frida-server ke HP (root) + kelola & jalankan script Frida.
/// Dipakai untuk menguji aplikasi & perangkat milikmu sendiri: bypass SSL
/// pinning, analisa alur OTP/2FA, trace fungsi, dsb.
class FridaPage extends StatefulWidget {
  const FridaPage({super.key});
  @override
  State<FridaPage> createState() => _FridaPageState();
}

class _FridaPageState extends State<FridaPage> {
  Map<String, dynamic> _status = {};
  List<Map<String, dynamic>> _scripts = [];
  List<String> _packages = [];
  List<Map<String, dynamic>> _sessions = [];
  String _serial = '';
  String? _selectedPackage;
  String? _selectedScript;
  bool _spawn = true;
  bool _busy = false;
  String _msg = '';
  List<Map<String, dynamic>>? _installSteps;

  // editor script
  final _editor = HighlightController();
  String? _editingName;
  bool _editorDirty = false;

  // sesi aktif yang sedang dilihat log-nya
  String? _activeSid;
  final List<String> _liveLog = [];
  bool _tailing = false;

  @override
  void initState() {
    super.initState();
    _editor.addListener(() => _editorDirty = true);
    _loadAll();
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _busy = true);
    try {
      final s = await Api.instance.fridaStatus(_serial);
      final sc = await Api.instance.fridaScripts();
      final ss = await _sessionsSafe();
      if (!mounted) return;
      setState(() {
        _status = s;
        _scripts = sc;
        _sessions = ss;
        final names = sc.map((e) => e['name'] as String).toSet();
        if (_selectedScript != null && !names.contains(_selectedScript)) _selectedScript = null;
        _selectedScript ??= sc.isNotEmpty ? sc.first['name'] as String : null;
      });
    } catch (e) {
      if (mounted) setState(() => _msg = '$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<List<Map<String, dynamic>>> _sessionsSafe() async {
    try {
      return await Api.instance.fridaSessions();
    } catch (_) {
      return [];
    }
  }

  void _toast(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _loadPackages() async {
    setState(() => _busy = true);
    try {
      _packages = await Api.instance.fridaPackages(_serial);
      if (_selectedPackage != null && !_packages.contains(_selectedPackage)) _selectedPackage = null;
      if (_selectedPackage == null && _packages.isNotEmpty) _selectedPackage = _packages.first;
    } catch (e) {
      _toast('$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _installSteps = null;
      _msg = '';
    });
    try {
      final r = await Api.instance.fridaInstall(_serial);
      setState(() => _installSteps = (r['steps'] as List?)?.cast<Map<String, dynamic>>());
      _msg = r['ok'] == true
          ? tr('frida-server terpasang & berjalan (versi ${r['version']}).', 'frida-server installed & running (version ${r['version']}).')
          : '${tr('Gagal', 'Failed')}: ${r['error']}';
    } catch (e) {
      _msg = '$e';
    }
    await _loadAll();
  }

  Future<void> _stopServer() async {
    setState(() => _busy = true);
    try {
      await Api.instance.fridaStopServer(_serial);
    } catch (e) {
      _toast('$e');
    }
    await _loadAll();
  }

  void _openScript(Map<String, dynamic> meta) async {
    final name = meta['name'] as String;
    try {
      final r = await Api.instance.fridaScriptRead(name);
      if (r['ok'] == true) {
        setState(() {
          _editingName = name;
          _editor.text = (r['content'] as String?) ?? '';
          _editorDirty = false;
        });
      } else {
        _toast('${r['error']}');
      }
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _newScript() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Script baru', 'New script')),
        content: TextField(controller: c, autofocus: true, decoration: InputDecoration(hintText: tr('nama-script (tanpa .js)', 'script-name (no .js)'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Batal', 'Cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, c.text), child: Text(tr('Buat', 'Create'))),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await Api.instance.fridaScriptSave(name.trim(), '// $name\nJava.perform(function () {\n  console.log("halo dari $name");\n});\n');
      await _loadAll();
      final created = _scripts.firstWhere((s) => s['name'] == name.trim(), orElse: () => {'name': name.trim()});
      _openScript(created);
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _saveScript() async {
    if (_editingName == null) return;
    setState(() => _busy = true);
    try {
      final r = await Api.instance.fridaScriptSave(_editingName!, _editor.text);
      _editorDirty = false;
      _toast(r['ok'] == true ? tr('Tersimpan.', 'Saved.') : '${r['error']}');
    } catch (e) {
      _toast('$e');
    }
    if (mounted) setState(() => _busy = false);
    await _loadAll();
  }

  Future<void> _deleteScript(String name) async {
    try {
      await Api.instance.fridaScriptDelete(name);
      if (_editingName == name) setState(() => _editingName = null);
      await _loadAll();
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _run() async {
    if (_selectedPackage == null || _selectedScript == null) {
      _toast(tr('Pilih aplikasi & script dulu.', 'Pick an app & script first.'));
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await Api.instance.fridaRun(_serial, _selectedPackage!, _selectedScript!, spawn: _spawn);
      if (r['ok'] == true) {
        _activeSid = r['id'] as String;
        _liveLog.clear();
        _startTail();
      } else {
        _toast('${r['error']}');
      }
    } catch (e) {
      _toast('$e');
    }
    if (mounted) setState(() => _busy = false);
    await _loadAll();
  }

  void _startTail() {
    if (_tailing) return;
    _tailing = true;
    _pollLog();
  }

  Future<void> _pollLog() async {
    while (_tailing && _activeSid != null && mounted) {
      try {
        final r = await Api.instance.fridaSessionLog(_activeSid!, since: _liveLog.length);
        if (r['ok'] == true) {
          final lines = (r['lines'] as List?)?.cast<String>() ?? const [];
          if (lines.isNotEmpty && mounted) setState(() => _liveLog.addAll(lines));
          if (r['running'] != true) {
            _tailing = false;
            break;
          }
        } else {
          _tailing = false;
          break;
        }
      } catch (_) {
        _tailing = false;
        break;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _stopActiveSession() async {
    if (_activeSid == null) return;
    try {
      await Api.instance.fridaSessionStop(_activeSid!);
    } catch (_) {}
    _tailing = false;
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final installed = _status['installed'] == true;
    final running = _status['running'] == true;
    final rooted = _status['rooted'] == true;
    final localCli = _status['local_cli'] == true;
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            crumbs: [tr('Lalu lintas', 'Traffic'), 'Frida'],
            title: tr('Frida (script injection)', 'Frida (script injection)'),
            subtitle: tr('Pasang frida-server ke HP (root) lalu jalankan script untuk bypass SSL pinning, analisa OTP, atau trace fungsi. Hanya untuk aplikasi & perangkat milikmu sendiri.',
                'Install frida-server on the phone (root) then run scripts to bypass SSL pinning, inspect OTP flows, or trace functions. For your own app & device only.'),
            actions: [OutlinedButton.icon(onPressed: _busy ? null : _loadAll, icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(tr('Segarkan', 'Refresh')))],
          ),
          const SizedBox(height: 20),

          // ---- status & pasang ----
          HoverCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.bolt_rounded, color: YmColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('frida-server (HP)', style: YmTextStyles.headlineSm),
                const Spacer(),
                SoftChip(running ? tr('berjalan', 'running') : (installed ? tr('terpasang, tidak jalan', 'installed, not running') : tr('belum terpasang', 'not installed')),
                    fg: running ? YmColors.onSuccessSoft : YmColors.onDangerSoft,
                    bg: running ? YmColors.successContainer.withOpacity(0.4) : YmColors.dangerSoft,
                    pill: true, bold: true),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 16, runSpacing: 4, children: [
                Text('ABI: ${_status['abi'] ?? '-'} (${_status['arch'] ?? '?'})', style: YmTextStyles.labelSm),
                Text('${tr('Root', 'Root')}: ${rooted ? tr('ya', 'yes') : tr('tidak', 'no')}', style: YmTextStyles.labelSm.copyWith(color: rooted ? null : YmColors.danger)),
                Text("'frida' CLI di PC: ${localCli ? tr('ada', 'found') : tr('tidak ada', 'missing')}", style: YmTextStyles.labelSm.copyWith(color: localCli ? null : YmColors.danger)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                TextField(
                  controller: TextEditingController(text: _serial),
                  onChanged: (v) => _serial = v,
                  decoration: InputDecoration(labelText: tr('Serial HP (kosong = perangkat pertama)', 'Phone serial (empty = first device)')),
                ),
              ].map((w) => Expanded(child: w)).toList()),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ElevatedButton.icon(onPressed: _busy ? null : _install, icon: const Icon(Icons.download_rounded, size: 18), label: Text(tr('Pasang / perbarui frida-server', 'Install / update frida-server'))),
                OutlinedButton.icon(onPressed: _busy || !running ? null : _stopServer, icon: const Icon(Icons.stop_circle_outlined, size: 18), label: Text(tr('Hentikan server', 'Stop server'))),
              ]),
              if (!localCli) ...[
                const SizedBox(height: 10),
                SelectableText('pip install frida-tools --break-system-packages', style: YmTextStyles.mono.copyWith(color: YmColors.primary)),
                Text(tr('Jalankan perintah di atas di PC (bukan HP) supaya tombol Jalankan di bawah bisa dipakai.',
                    'Run the command above on your PC (not the phone) so Run below works.'), style: YmTextStyles.labelSm),
              ],
              if (_installSteps != null) ...[
                const SizedBox(height: 12),
                ..._installSteps!.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(s['ok'] == true ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 15, color: s['ok'] == true ? YmColors.success : YmColors.danger),
                        const SizedBox(width: 6),
                        Expanded(child: Text('${s['step']}${(s['out'] as String?)?.isNotEmpty == true ? ' — ${s['out']}' : ''}', style: YmTextStyles.labelSm)),
                      ]),
                    )),
              ],
              if (_msg.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(_msg, style: YmTextStyles.bodySm.copyWith(color: _msg.startsWith(tr('Gagal', 'Failed')) ? YmColors.danger : YmColors.primary)),
              ],
            ]),
          ),
          const SizedBox(height: 16),

          // ---- jalankan script ----
          HoverCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Jalankan script', 'Run script'), style: YmTextStyles.headlineSm),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedPackage,
                    items: _packages.map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _selectedPackage = v),
                    decoration: InputDecoration(labelText: tr('Aplikasi target', 'Target app')),
                  ),
                ),
                OutlinedButton.icon(onPressed: _busy ? null : _loadPackages, icon: const Icon(Icons.apps_rounded, size: 16), label: Text(tr('Muat daftar app', 'Load apps'))),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedScript,
                    items: _scripts.map((s) => DropdownMenuItem(value: s['name'] as String, child: Text(s['name'] as String, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _selectedScript = v),
                    decoration: InputDecoration(labelText: tr('Script', 'Script')),
                  ),
                ),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Checkbox(value: _spawn, onChanged: (v) => setState(() => _spawn = v ?? true)),
                  Text(tr('Spawn (buka ulang app)', 'Spawn (relaunch app)'), style: YmTextStyles.labelSm),
                ]),
                ElevatedButton.icon(onPressed: _busy || !running ? null : _run, icon: const Icon(Icons.play_arrow_rounded, size: 18), label: Text(tr('Jalankan', 'Run'))),
                if (_activeSid != null) OutlinedButton.icon(onPressed: _stopActiveSession, icon: const Icon(Icons.stop_rounded, size: 18), label: Text(tr('Hentikan sesi', 'Stop session'))),
              ]),
              if (!running) Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr('frida-server belum berjalan di HP. Pasang dulu di atas.', 'frida-server is not running on the phone. Install it above first.'), style: YmTextStyles.labelSm.copyWith(color: YmColors.danger))),
              if (_activeSid != null) ...[
                const SizedBox(height: 12),
                Container(
                  height: 220,
                  decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                  child: FindableView(text: _liveLog.join('\n'), readOnly: true),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 16),

          // ---- perpustakaan script ----
          HoverCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(tr('Script tersimpan', 'Saved scripts'), style: YmTextStyles.headlineSm),
                const Spacer(),
                OutlinedButton.icon(onPressed: _newScript, icon: const Icon(Icons.add_rounded, size: 16), label: Text(tr('Script baru', 'New script'))),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                height: 420,
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    width: 220,
                    child: ListView(children: [
                      for (final s in _scripts)
                        ListTile(
                          dense: true,
                          selected: _editingName == s['name'],
                          title: Text(s['name'] as String, style: YmTextStyles.labelMd, overflow: TextOverflow.ellipsis),
                          onTap: () => _openScript(s),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            onPressed: () => _deleteScript(s['name'] as String),
                            tooltip: tr('Hapus', 'Delete'),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _editingName == null
                        ? Center(child: Text(tr('Pilih script di kiri, atau impor/buat baru.', 'Pick a script on the left, or import/create new.'), style: YmTextStyles.bodySm))
                        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Row(children: [
                              Expanded(child: Text(_editingName!, style: YmTextStyles.labelMd.copyWith(fontWeight: FontWeight.w700))),
                              if (_editorDirty) Padding(padding: const EdgeInsets.only(right: 8), child: Text(tr('belum disimpan', 'unsaved'), style: YmTextStyles.labelSm.copyWith(color: YmColors.warning))),
                              ElevatedButton.icon(onPressed: _busy ? null : _saveScript, icon: const Icon(Icons.save_rounded, size: 16), label: Text(tr('Simpan', 'Save'))),
                            ]),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(border: Border.all(color: YmColors.line), borderRadius: BorderRadius.circular(8)),
                                child: FindableView(controller: _editor, readOnly: false),
                              ),
                            ),
                          ]),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              Text(tr('Impor script: tempel isi .js ke kolom editor lalu Simpan dengan nama baru lewat "Script baru".',
                  'Import a script: paste the .js content into the editor and Save it under a new name via "New script".'), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
            ]),
          ),
        ],
      ),
    );
  }
}
