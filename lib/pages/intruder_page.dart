import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';
import '../widgets/tab_strip.dart';

/// Jembatan: History/Repeater -> Intruder (buka TAB BARU).
class IntruderInbox {
  static Map<String, dynamic>? _seed;
  static final ValueNotifier<int> tick = ValueNotifier(0);
  static void send(Map<String, dynamic> detail) {
    _seed = detail;
    tick.value++;
  }

  static Map<String, dynamic>? take() {
    final s = _seed;
    _seed = null;
    return s;
  }
}

/// Satu sesi Intruder (satu tab).
class _Session {
  String scheme = 'https';
  final host = TextEditingController();
  final port = TextEditingController();
  final method = TextEditingController(text: 'GET');
  final path = TextEditingController(text: '/user/§');
  final headers = TextEditingController();
  String genType = 'numbers';
  final list = TextEditingController(text: 'admin\nroot\ntest');
  final numFrom = TextEditingController(text: '1');
  final numTo = TextEditingController(text: '50');
  final bruteChars = TextEditingController(text: '0123456789');
  final bruteLen = TextEditingController(text: '3');
  final randCount = TextEditingController(text: '20');
  final randDigits = TextEditingController(text: '6');
  List<Map<String, dynamic>> results = [];
  bool running = false;
  int n;
  _Session(this.n);

  String get title {
    final h = host.text.trim();
    return h.isEmpty ? '${tr('Intruder', 'Intruder')} $n' : h;
  }

  void dispose() {
    for (final c in [host, port, method, path, headers, list, numFrom, numTo, bruteChars, bruteLen, randCount, randDigits]) {
      c.dispose();
    }
  }

  void seed(Map<String, dynamic> s) {
    scheme = s['scheme'] as String? ?? 'https';
    host.text = s['host'] as String? ?? '';
    method.text = s['method'] as String? ?? 'GET';
    path.text = s['path'] as String? ?? '/';
    final b = StringBuffer();
    (s['req_headers'] as Map?)?.forEach((k, v) => b.writeln('$k: $v'));
    headers.text = b.toString().trim();
  }
}

class IntruderPage extends StatefulWidget {
  const IntruderPage({super.key});
  @override
  State<IntruderPage> createState() => _IntruderPageState();
}

class _IntruderPageState extends State<IntruderPage> {
  final List<_Session> _tabs = [];
  int _active = 0;
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _tabs.add(_Session(++_counter));
    IntruderInbox.tick.addListener(_loadSeed);
    _loadSeed();
  }

  @override
  void dispose() {
    IntruderInbox.tick.removeListener(_loadSeed);
    for (final t in _tabs) {
      t.dispose();
    }
    super.dispose();
  }

  void _loadSeed() {
    final s = IntruderInbox.take();
    if (s == null) return;
    final sess = _Session(++_counter)..seed(s);
    setState(() {
      final cur = _tabs[_active];
      if (cur.host.text.isEmpty && cur.results.isEmpty) {
        sess.n = cur.n;
        cur.dispose();
        _tabs[_active] = sess;
      } else {
        _tabs.add(sess);
        _active = _tabs.length - 1;
      }
    });
  }

  void _addTab() => setState(() {
        _tabs.add(_Session(++_counter));
        _active = _tabs.length - 1;
      });

  void _closeTab(int i) {
    setState(() {
      _tabs[i].dispose();
      _tabs.removeAt(i);
      if (_tabs.isEmpty) _tabs.add(_Session(++_counter));
      if (_active >= _tabs.length) _active = _tabs.length - 1;
    });
  }

  List<String> _payloads(_Session t) {
    switch (t.genType) {
      case 'list':
        return t.list.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      case 'numbers':
        final a = int.tryParse(t.numFrom.text) ?? 0;
        final b = int.tryParse(t.numTo.text) ?? 0;
        if (b < a) return [];
        return [for (var i = a; i <= b && i - a < 2000; i++) '$i'];
      case 'random':
        final n = (int.tryParse(t.randCount.text) ?? 20).clamp(1, 2000);
        final d = (int.tryParse(t.randDigits.text) ?? 6).clamp(1, 12);
        final r = Random();
        return [for (var i = 0; i < n; i++) List.generate(d, (_) => r.nextInt(10)).join()];
      case 'brute':
        final chars = t.bruteChars.text;
        final len = (int.tryParse(t.bruteLen.text) ?? 1).clamp(1, 4);
        if (chars.isEmpty) return [];
        final out = <String>[];
        void rec(String cur) {
          if (out.length >= 2000) return;
          if (cur.length == len) {
            out.add(cur);
            return;
          }
          for (final c in chars.split('')) {
            rec(cur + c);
            if (out.length >= 2000) return;
          }
        }
        rec('');
        return out;
      default:
        return [];
    }
  }

  Map<String, String> _parseHeaders(_Session t) {
    final h = <String, String>{};
    for (final line in t.headers.text.split('\n')) {
      final idx = line.indexOf(':');
      if (idx > 0) h[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
    }
    return h;
  }

  Future<void> _run(_Session t) async {
    final pls = _payloads(t);
    if (pls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Payload kosong.', 'No payloads.'))));
      return;
    }
    setState(() {
      t.running = true;
      t.results = [];
    });
    final r = await Api.instance.intruder({
      'scheme': t.scheme,
      'host': t.host.text.trim(),
      'port': int.tryParse(t.port.text) ?? 0,
      'method': t.method.text.trim().toUpperCase(),
      'path': t.path.text.trim(),
      'headers': _parseHeaders(t),
      'body': '',
      'marker': '§',
      'payloads': pls,
    });
    if (!mounted) return;
    setState(() {
      t.running = false;
      t.results = ((r['results'] as List?) ?? []).cast<Map<String, dynamic>>();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_active >= _tabs.length) _active = _tabs.length - 1;
    final t = _tabs[_active];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: PageHeader(
            crumbs: [tr('Alat', 'Tools'), 'Intruder'],
            title: 'Intruder',
            subtitle: tr('Kirim satu request berkali-kali dengan payload di posisi §. Tiap tab satu sesi — tutup dengan ✕ / klik-kanan / klik-tengah.',
                'Send one request many times with payloads at §. Each tab is a session — close with ✕ / right-click / middle-click.'),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TabStrip(
            titles: [for (final s in _tabs) s.title],
            active: _active,
            onSelect: (i) => setState(() => _active = i),
            onClose: _closeTab,
            onAdd: _addTab,
          ),
        ),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 24), child: _sessionBody(t))),
      ],
    );
  }

  Widget _sessionBody(_Session t) {
    final pls = _payloads(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Spacer(),
          ElevatedButton.icon(
            onPressed: t.running ? null : () => _run(t),
            icon: t.running ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.rocket_launch_outlined, size: 18),
            label: Text(t.running ? tr('Menyerang…', 'Running…') : '${tr('Mulai', 'Start')} (${pls.length})'),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          SizedBox(width: 120, child: SegmentedToggle<String>(value: t.scheme, items: const [('https', 'https'), ('http', 'http')], onChanged: (nv) => setState(() => t.scheme = nv))),
          const SizedBox(width: 8),
          SizedBox(width: 90, child: TextField(controller: t.method, decoration: const InputDecoration(labelText: 'Method'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: t.host, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Host'))),
          const SizedBox(width: 8),
          SizedBox(width: 80, child: TextField(controller: t.port, decoration: const InputDecoration(labelText: 'Port'))),
        ]),
        const SizedBox(height: 8),
        TextField(controller: t.path, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('Path (taruh § di posisi payload)', 'Path (put § at the payload position)'))),
        const SizedBox(height: 8),
        TextField(controller: t.headers, maxLines: 3, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('Header (opsional, satu per baris; § boleh dipakai)', 'Headers (optional, one per line; § allowed)'))),
        const SizedBox(height: 16),
        _generator(t, pls),
        const SizedBox(height: 16),
        Text(tr('Hasil', 'Results'), style: YmTextStyles.sectionTitle),
        const SizedBox(height: 8),
        _resultTable(t),
      ],
    );
  }

  Widget _generator(_Session t, List<String> pls) {
    return HoverCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(tr('Generator payload', 'Payload generator'), style: YmTextStyles.headlineSm),
            const Spacer(),
            SoftChip.neutral('${pls.length} payload'),
          ]),
          const SizedBox(height: 12),
          SegmentedToggle<String>(
            value: t.genType,
            items: [('list', tr('Daftar', 'List')), ('numbers', tr('Angka urut', 'Number range')), ('random', tr('Angka acak', 'Random numbers')), ('brute', tr('Brute force', 'Brute force'))],
            onChanged: (v) => setState(() => t.genType = v),
          ),
          const SizedBox(height: 12),
          if (t.genType == 'list')
            TextField(controller: t.list, maxLines: 4, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('Satu payload per baris', 'One payload per line')), onChanged: (_) => setState(() {}))
          else if (t.genType == 'numbers')
            Row(children: [
              SizedBox(width: 120, child: TextField(controller: t.numFrom, decoration: InputDecoration(labelText: tr('Dari', 'From')), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              SizedBox(width: 120, child: TextField(controller: t.numTo, decoration: InputDecoration(labelText: tr('Sampai', 'To')), onChanged: (_) => setState(() {}))),
            ])
          else if (t.genType == 'random')
            Row(children: [
              SizedBox(width: 120, child: TextField(controller: t.randCount, decoration: InputDecoration(labelText: tr('Jumlah', 'Count')), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              SizedBox(width: 120, child: TextField(controller: t.randDigits, decoration: InputDecoration(labelText: tr('Digit', 'Digits')), onChanged: (_) => setState(() {}))),
            ])
          else
            Row(children: [
              Expanded(child: TextField(controller: t.bruteChars, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('Karakter', 'Characters')), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              SizedBox(width: 100, child: TextField(controller: t.bruteLen, decoration: InputDecoration(labelText: tr('Panjang', 'Length')), onChanged: (_) => setState(() {}))),
            ]),
        ],
      ),
    );
  }

  Widget _resultTable(_Session t) {
    if (t.results.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: YmColors.line)),
        child: Center(child: Text(t.running ? tr('Berjalan…', 'Running…') : tr('Belum ada hasil. Tekan Mulai.', 'No results yet. Press Start.'), style: YmTextStyles.bodySm)),
      );
    }
    return Container(
      decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: YmColors.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: YmColors.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Expanded(flex: 3, child: Text('Payload', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontWeight: FontWeight.w700))),
              SizedBox(width: 70, child: Text('Status', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontWeight: FontWeight.w700))),
              SizedBox(width: 80, child: Text(tr('Panjang', 'Length'), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontWeight: FontWeight.w700))),
              SizedBox(width: 70, child: Text(tr('Waktu', 'Time'), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontWeight: FontWeight.w700))),
            ]),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: t.results.length,
              itemBuilder: (context, i) {
                final r = t.results[i];
                final st = r['status'] as int? ?? 0;
                return Container(
                  color: i.isEven ? Colors.transparent : YmColors.surfaceAlt.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text(r['payload'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.mono)),
                    SizedBox(width: 70, child: Text(st == 0 ? 'err' : '$st', style: YmTextStyles.labelSm.copyWith(color: statusColor(st), fontWeight: FontWeight.w700))),
                    SizedBox(width: 80, child: Text('${r['length']}', style: YmTextStyles.labelSm)),
                    SizedBox(width: 70, child: Text('${r['duration_ms']}ms', style: YmTextStyles.labelSm)),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
