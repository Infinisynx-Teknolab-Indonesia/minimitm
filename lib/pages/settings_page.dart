import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../services/backend.dart';
import '../widgets/ui.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _apiHost = TextEditingController(text: Api.instance.baseHost);
  final _apiPort = TextEditingController(text: '${Api.instance.basePort}');

  // AI
  final _aiUrl = TextEditingController();
  final _aiModel = TextEditingController();
  final _aiKey = TextEditingController();
  String _aiKind = 'openai';
  List<String> _aiModelList = [];
  String _aiMsg = '';

  // server lokal
  final _pyPath = TextEditingController(text: BackendManager.instance.pythonPath);
  final _beDir = TextEditingController(text: BackendManager.instance.backendDir);
  bool _logOpen = false;

  @override
  void initState() {
    super.initState();
    _loadAi();
  }

  Future<void> _saveBackend() async {
    final b = BackendManager.instance;
    b.pythonPath = _pyPath.text.trim();
    b.backendDir = _beDir.text.trim();
    await b.save();
  }

  Future<void> _loadAi() async {
    try {
      final c = await Api.instance.aiConfigGet();
      setState(() {
        _aiKind = (c['kind'] ?? 'openai').toString();
        _aiUrl.text = (c['url'] ?? '').toString();
        _aiModel.text = (c['model'] ?? '').toString();
        _aiKey.text = (c['api_key'] ?? '').toString();
      });
    } catch (_) {}
  }

  Future<void> _saveAi() async {
    await Api.instance.aiConfigPut({'kind': _aiKind, 'url': _aiUrl.text.trim(), 'model': _aiModel.text.trim(), 'api_key': _aiKey.text});
    if (mounted) setState(() => _aiMsg = tr('Tersimpan.', 'Saved.'));
  }

  Future<void> _fetchModels() async {
    await _saveAi();
    final list = await Api.instance.aiModels();
    if (!mounted) return;
    setState(() {
      _aiModelList = list;
      _aiMsg = list.isEmpty ? tr('Tidak ada model / gateway tak terjangkau.', 'No models / gateway unreachable.') : '${list.length} ${tr('model ditemukan', 'models found')}';
    });
  }

  void _reconnect() {
    Api.instance.baseHost = _apiHost.text.trim().isEmpty ? '127.0.0.1' : _apiHost.text.trim();
    Api.instance.basePort = int.tryParse(_apiPort.text) ?? 8099;
    Api.instance.connect();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Menyambung ulang ke backend…', 'Reconnecting to backend…'))));
  }

  Widget _localServerCard() {
    return AnimatedBuilder(
      animation: BackendManager.instance,
      builder: (context, _) {
        final b = BackendManager.instance;
        final (Color c, String label) = switch (b.state) {
          BackendState.running => (YmColors.success, tr('Berjalan', 'Running')),
          BackendState.external => (YmColors.success, tr('Server manual aktif', 'External server')),
          BackendState.starting => (YmColors.warning, tr('Menjalankan…', 'Starting…')),
          BackendState.installing => (YmColors.warning, tr('Memasang dependensi…', 'Installing deps…')),
          BackendState.locating => (YmColors.warning, tr('Mencari…', 'Locating…')),
          BackendState.failed => (YmColors.danger, tr('Gagal', 'Failed')),
          _ => (YmColors.textMuted, tr('Mati', 'Stopped')),
        };
        return HoverCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.rocket_launch_outlined, color: YmColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(tr('Server lokal (otomatis)', 'Local server (automatic)'), style: YmTextStyles.headlineSm),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(label, style: YmTextStyles.labelSm.copyWith(color: c, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
              const SizedBox(height: 4),
              Text(tr('Aplikasi menjalankan server Python-nya sendiri — tak perlu buka terminal.',
                  'The app runs its own Python server — no terminal needed.'), style: YmTextStyles.bodySm),
              if (b.message.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(b.message, style: YmTextStyles.labelSm.copyWith(color: c)),
              ],
              if (b.backendDir.isNotEmpty && b.bundledExists(b.backendDir)) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.inventory_2_outlined, size: 15, color: YmColors.success),
                  const SizedBox(width: 6),
                  Expanded(child: Text(tr('Python portable aktif — pengguna tak perlu memasang Python.', 'Portable Python active — users don\'t need Python installed.'), style: YmTextStyles.labelSm.copyWith(color: YmColors.onSuccessSoft))),
                ]),
              ],
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: b.autoStart,
                onChanged: (v) {
                  b.autoStart = v;
                  b.save();
                  setState(() {});
                },
                title: Text(tr('Jalankan server otomatis saat app dibuka', 'Start server automatically on app launch'), style: YmTextStyles.labelMd),
              ),
              TextField(controller: _pyPath, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('Path Python', 'Python path'), hintText: r'D:\python3.12\python.exe')),
              const SizedBox(height: 10),
              TextField(controller: _beDir, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('Folder backend (kosong = deteksi otomatis)', 'Backend folder (empty = auto-detect)'), hintText: r'...\MiniMitmFlutter\backend')),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (b.state != BackendState.running && b.state != BackendState.external)
                  ElevatedButton.icon(
                    onPressed: b.busy ? null : () async {
                      await _saveBackend();
                      b.ensureStarted();
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(tr('Jalankan server', 'Start server')),
                  )
                else
                  OutlinedButton.icon(onPressed: b.stop, icon: const Icon(Icons.stop_rounded, size: 18), label: Text(tr('Hentikan', 'Stop'))),
                OutlinedButton.icon(
                  onPressed: b.busy ? null : () async {
                    await _saveBackend();
                    b.restart();
                  },
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: Text(tr('Mulai ulang', 'Restart')),
                ),
                OutlinedButton.icon(
                  onPressed: b.busy ? null : () async {
                    await _saveBackend();
                    b.installDeps();
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(tr('Pasang dependensi', 'Install deps')),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _logOpen = !_logOpen),
                  icon: Icon(_logOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
                  label: Text(tr('Log', 'Log')),
                ),
              ]),
              if (_logOpen) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  height: 160,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF0B0F1A), borderRadius: BorderRadius.circular(8)),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: SelectableText(
                      b.log.isEmpty ? '(kosong)' : b.log.join('\n'),
                      style: const TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Consolas', 'monospace'], fontSize: 11, height: 1.4, color: Color(0xFFCDE3FF)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(crumbs: [tr('Akun', 'Account'), tr('Pengaturan', 'Settings')], title: tr('Pengaturan', 'Settings')),
          const SizedBox(height: 20),
          HoverCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.translate_rounded, color: YmColors.primary, size: 20), const SizedBox(width: 8), Text(tr('Bahasa', 'Language'), style: YmTextStyles.headlineSm)]),
                const SizedBox(height: 14),
                SegmentedToggle<String>(
                  value: L.instance.lang,
                  items: const [('id', 'Indonesia'), ('en', 'English')],
                  onChanged: (v) => L.instance.set(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _localServerCard(),
          const SizedBox(height: 16),
          HoverCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.dns_outlined, color: YmColors.primary, size: 20), const SizedBox(width: 8), Text(tr('Koneksi manual / remote', 'Manual / remote connection'), style: YmTextStyles.headlineSm)]),
                const SizedBox(height: 4),
                Text(tr('Kalau server jalan di PC/alamat lain. Default 127.0.0.1:8099.', 'If the server runs on another PC/address. Default 127.0.0.1:8099.'), style: YmTextStyles.bodySm),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: TextField(controller: _apiHost, decoration: const InputDecoration(labelText: 'Host API'))),
                  const SizedBox(width: 8),
                  SizedBox(width: 120, child: TextField(controller: _apiPort, decoration: const InputDecoration(labelText: 'Port API'))),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _reconnect, child: Text(tr('Sambungkan', 'Connect'))),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          HoverCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.auto_awesome_rounded, color: YmColors.primary, size: 20), const SizedBox(width: 8), Text(tr('AI (Tanya AI)', 'AI (Ask AI)'), style: YmTextStyles.headlineSm)]),
                const SizedBox(height: 4),
                Text(tr('Koneksi ke AI lokal (LM Studio, llama.cpp, Ollama, Prakash AI, dll). Dipakai tombol "Tanya AI".',
                    'Connection to a local AI (LM Studio, llama.cpp, Ollama, Prakash AI, etc). Used by the "Ask AI" buttons.'), style: YmTextStyles.bodySm),
                const SizedBox(height: 14),
                Row(children: [
                  Text(tr('Jenis', 'Kind'), style: YmTextStyles.labelSm),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _aiKind,
                    items: const [
                      DropdownMenuItem(value: 'openai', child: Text('OpenAI-compatible')),
                      DropdownMenuItem(value: 'ollama', child: Text('Ollama')),
                    ],
                    onChanged: (v) => setState(() => _aiKind = v ?? 'openai'),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(controller: _aiUrl, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('URL endpoint', 'Endpoint URL'), hintText: 'http://127.0.0.1:1234/v1/chat/completions')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: _aiModel, decoration: InputDecoration(labelText: tr('Model', 'Model'), hintText: tr('(opsional)', '(optional)')))),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(onPressed: _fetchModels, icon: const Icon(Icons.download_rounded, size: 16), label: Text(tr('Ambil model', 'Fetch models'))),
                ]),
                if (_aiModelList.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final m in _aiModelList)
                      ActionChip(label: Text(m, style: YmTextStyles.labelSm), onPressed: () => setState(() => _aiModel.text = m)),
                  ]),
                ],
                const SizedBox(height: 10),
                TextField(controller: _aiKey, obscureText: true, decoration: InputDecoration(labelText: tr('API key (opsional)', 'API key (optional)'))),
                const SizedBox(height: 12),
                Row(children: [
                  ElevatedButton.icon(onPressed: _saveAi, icon: const Icon(Icons.save_outlined, size: 18), label: Text(tr('Simpan', 'Save'))),
                  const SizedBox(width: 12),
                  if (_aiMsg.isNotEmpty) Expanded(child: Text(_aiMsg, style: YmTextStyles.bodySm.copyWith(color: YmColors.primary))),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          HoverCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.palette_outlined, color: YmColors.primary, size: 20), const SizedBox(width: 8), Text(tr('Tema tampilan', 'Theme'), style: YmTextStyles.headlineSm)]),
                const SizedBox(height: 14),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final p in appPalettes)
                    GestureDetector(
                      onTap: () => ThemeCtl.instance.set(p.id),
                      child: Container(
                        width: 150,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: YmColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.id == ThemeCtl.instance.palette.id ? YmColors.primary : YmColors.line, width: p.id == ThemeCtl.instance.palette.id ? 1.8 : 1),
                        ),
                        child: Row(children: [
                          Container(width: 22, height: 22, decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(6))),
                          const SizedBox(width: 10),
                          Expanded(child: Text(p.name, style: YmTextStyles.labelMd)),
                          if (p.id == ThemeCtl.instance.palette.id) Icon(Icons.check_circle_rounded, size: 16, color: YmColors.primary),
                        ]),
                      ),
                    ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          HoverCard(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: YmColors.outline, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('Mini MITM Proxy v1.0 — frontend Flutter + backend FastAPI. Alat ini hanya untuk menguji aplikasi, perangkat, dan lalu lintas milikmu sendiri.',
                      'Mini MITM Proxy v1.0 — Flutter frontend + FastAPI backend. This tool is only for testing your own apps, devices and traffic.'),
                  style: YmTextStyles.bodySm,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
