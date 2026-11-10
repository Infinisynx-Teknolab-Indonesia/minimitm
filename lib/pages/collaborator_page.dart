import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';

class CollaboratorPage extends StatefulWidget {
  const CollaboratorPage({super.key});
  @override
  State<CollaboratorPage> createState() => _CollaboratorPageState();
}

class _CollaboratorPageState extends State<CollaboratorPage> {
  bool _running = false;
  String _base = '';
  final _port = TextEditingController(text: '8083');
  final _baseC = TextEditingController();
  String? _payload;
  List<Map<String, dynamic>> _inter = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final s = await Api.instance.collabStatus();
      setState(() {
        _running = s['running'] == true;
        _base = (s['base'] ?? '').toString();
      });
    } catch (_) {}
    _poll();
  }

  Future<void> _poll() async {
    if (!_running) return;
    try {
      final list = await Api.instance.collabInteractions();
      if (mounted) setState(() => _inter = list);
    } catch (_) {}
  }

  Future<void> _start() async {
    final r = await Api.instance.collabStart(int.tryParse(_port.text) ?? 8083, _baseC.text.trim());
    if (!mounted) return;
    setState(() {
      _running = r['running'] == true;
      _base = (r['base'] ?? '').toString();
    });
  }

  Future<void> _stop() async {
    await Api.instance.collabStop();
    if (mounted) setState(() => _running = false);
  }

  Future<void> _gen() async {
    final r = await Api.instance.collabPayload();
    if (mounted) setState(() => _payload = r['url'] as String?);
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            crumbs: [tr('Alat', 'Tools'), 'Collaborator'],
            title: 'Collaborator (OOB)',
            subtitle: tr('Deteksi celah blind (SSRF/XSS blind): sisipkan URL unik sebagai payload; kalau target menghubunginya, tercatat di sini. Untuk aplikasi milikmu.',
                'Detect blind bugs (blind SSRF/XSS): inject a unique URL as payload; if the target hits it, it is logged here. For your own apps.'),
            actions: [
              if (!_running)
                ElevatedButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow_rounded, size: 18), label: Text(tr('Mulai listener', 'Start listener')))
              else
                OutlinedButton.icon(onPressed: _stop, icon: const Icon(Icons.stop_rounded, size: 18), label: Text(tr('Hentikan', 'Stop'))),
            ],
          ),
          const SizedBox(height: 20),
          HoverCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                StatusPill(running: _running, text: _running ? 'ON' : 'OFF'),
                const SizedBox(width: 12),
                if (_running) Expanded(child: Text('${tr('Base', 'Base')}: $_base', style: YmTextStyles.mono)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                SizedBox(width: 120, child: TextField(controller: _port, decoration: const InputDecoration(labelText: 'Port'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _baseC, decoration: InputDecoration(labelText: tr('Base publik (opsional, host:port)', 'Public base (optional, host:port)'), hintText: 'vps.contoh.com:8083'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                OutlinedButton.icon(onPressed: _running ? _gen : null, icon: const Icon(Icons.vpn_key_outlined, size: 18), label: Text(tr('Buat URL payload', 'Generate payload URL'))),
                const SizedBox(width: 12),
                if (_payload != null)
                  Expanded(
                    child: Row(children: [
                      Expanded(child: SelectableText(_payload!, style: YmTextStyles.mono)),
                      IconButton(
                        icon: Icon(Icons.copy_rounded, size: 16, color: YmColors.outline),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _payload!));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Disalin.', 'Copied.'))));
                        },
                      ),
                    ]),
                  ),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Text(tr('Interaksi masuk', 'Incoming interactions'), style: YmTextStyles.sectionTitle),
            const SizedBox(width: 10),
            SoftChip.neutral('${_inter.length}'),
            const Spacer(),
            if (_inter.isNotEmpty) TextButton.icon(onPressed: () async { await Api.instance.collabClear(); setState(() => _inter = []); }, icon: const Icon(Icons.delete_outline_rounded, size: 16), label: Text(tr('Bersihkan', 'Clear'))),
          ]),
          const SizedBox(height: 8),
          if (_inter.isEmpty)
            HoverCard(child: SizedBox(height: 160, child: EmptyState(icon: Icons.wifi_tethering_rounded, title: tr('Menunggu interaksi…', 'Waiting for interactions…'), message: tr('Sisipkan URL payload di aplikasi target. Kalau ada yang menghubunginya, muncul di sini.', 'Inject the payload URL into the target. If something hits it, it shows here.'))))
          else
            for (final it in _inter)
              HoverCard(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    SoftChip.primary(it['method'] as String? ?? 'GET'),
                    const SizedBox(width: 8),
                    Expanded(child: Text(it['path'] as String? ?? '', style: YmTextStyles.mono, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 4),
                  Text('${tr('Dari', 'From')}: ${it['client']}  •  UA: ${it['ua']}', style: YmTextStyles.labelSm, maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
        ],
      ),
    );
  }
}
