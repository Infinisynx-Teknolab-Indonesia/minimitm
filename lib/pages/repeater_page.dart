import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';
import '../widgets/ai_dialog.dart';
import '../widgets/tab_strip.dart';
import '../widgets/editor_menu.dart';
import '../services/nav.dart';
import 'intruder_page.dart';

/// Jembatan: History -> Repeater (buka TAB BARU berisi request terpilih).
class RepeaterInbox {
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

/// Satu sesi Repeater (satu tab).
class _Session {
  String scheme = 'https';
  final method = TextEditingController(text: 'GET');
  final host = TextEditingController();
  final port = TextEditingController();
  final path = TextEditingController(text: '/');
  final req = TextEditingController();
  Map<String, dynamic>? resp;
  bool sending = false;
  int n;
  _Session(this.n);

  String get title {
    final h = host.text.trim();
    return h.isEmpty ? '${tr('Repeater', 'Repeater')} $n' : h;
  }

  void dispose() {
    method.dispose();
    host.dispose();
    port.dispose();
    path.dispose();
    req.dispose();
  }

  void seed(Map<String, dynamic> s) {
    scheme = s['scheme'] as String? ?? 'https';
    host.text = s['host'] as String? ?? '';
    method.text = s['method'] as String? ?? 'GET';
    path.text = s['path'] as String? ?? '/';
    final b = StringBuffer();
    (s['req_headers'] as Map?)?.forEach((k, v) => b.writeln('$k: $v'));
    b.writeln();
    b.write(s['req_body'] ?? '');
    req.text = b.toString();
    resp = null;
  }
}

class RepeaterPage extends StatefulWidget {
  const RepeaterPage({super.key});
  @override
  State<RepeaterPage> createState() => _RepeaterPageState();
}

class _RepeaterPageState extends State<RepeaterPage> {
  final List<_Session> _tabs = [];
  int _active = 0;
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    _tabs.add(_Session(++_counter));
    RepeaterInbox.tick.addListener(_loadSeed);
    _loadSeed();
  }

  @override
  void dispose() {
    RepeaterInbox.tick.removeListener(_loadSeed);
    for (final t in _tabs) {
      t.dispose();
    }
    super.dispose();
  }

  void _loadSeed() {
    final s = RepeaterInbox.take();
    if (s == null) return;
    final sess = _Session(++_counter)..seed(s);
    setState(() {
      // kalau tab aktif masih kosong, pakai itu; selain itu buka tab baru
      final cur = _tabs[_active];
      if (cur.host.text.isEmpty && cur.resp == null && cur.req.text.trim().isEmpty) {
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

  Future<void> _send(_Session t) async {
    final (headers, body) = _parseReq(t.req.text);
    setState(() {
      t.sending = true;
      t.resp = null;
    });
    final r = await Api.instance.repeaterSend({
      'scheme': t.scheme,
      'host': t.host.text.trim(),
      'port': int.tryParse(t.port.text) ?? 0,
      'method': t.method.text.trim().toUpperCase(),
      'path': t.path.text.trim(),
      'headers': headers,
      'body': body,
    });
    if (!mounted) return;
    setState(() {
      t.sending = false;
      t.resp = r;
    });
  }

  (Map<String, String>, String) _parseReq(String text) {
    final lines = text.split('\n');
    final headers = <String, String>{};
    int i = 0;
    for (; i < lines.length; i++) {
      final line = lines[i].trimRight();
      if (line.isEmpty) {
        i++;
        break;
      }
      final idx = line.indexOf(':');
      if (idx > 0) headers[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
    }
    final body = i < lines.length ? lines.sublist(i).join('\n') : '';
    return (headers, body);
  }

  Map<String, dynamic> _seed(_Session t) {
    final (headers, body) = _parseReq(t.req.text);
    return {
      'scheme': t.scheme,
      'host': t.host.text.trim(),
      'method': t.method.text.trim().toUpperCase(),
      'path': t.path.text.trim(),
      'req_headers': headers,
      'req_body': body,
    };
  }

  void _askAi(_Session t) {
    final reqText = '${t.method.text} ${t.path.text}\nHost: ${t.host.text}\n${t.req.text}';
    final b = StringBuffer('=== REQUEST ===\n$reqText');
    final r = t.resp;
    final hasResp = r != null && r['ok'] == true;
    if (hasResp) {
      b.write('\n\n=== RESPONSE ===\nHTTP ${r['status']} ${r['reason']}\n');
      (r['headers'] as Map).forEach((k, v) => b.writeln('$k: $v'));
      b.write('\n${r['body'] ?? ''}');
    }
    final starter = hasResp
        ? tr('Analisa kelemahan keamanan dari request & response ini, dan jelaskan cara memverifikasi / bypass / mengeksploitasinya. Ini aplikasi milikku sendiri.',
            'Analyse the security weaknesses of this request & response, and explain how to verify / bypass / exploit them. This is my own app.')
        : tr('Jelaskan request ini dan kemungkinan kelemahan keamanannya. Ini aplikasi milikku sendiri.',
            'Explain this request and its possible security weaknesses. This is my own app.');
    showAiDialog(context, title: '${t.method.text} ${t.host.text}', attachment: b.toString(), starter: starter);
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
            crumbs: [tr('Alat', 'Tools'), 'Repeater'],
            title: 'Repeater',
            subtitle: tr('Kirim ulang & utak-atik request. Tiap tab satu sesi — tutup dengan ✕ / klik-kanan / klik-tengah.',
                'Resend & tweak requests. Each tab is a session — close with ✕ / right-click / middle-click.'),
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
        Expanded(child: _sessionBody(t)),
      ],
    );
  }

  Widget _sessionBody(_Session t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            SizedBox(
              width: 120,
              child: SegmentedToggle<String>(
                value: t.scheme,
                items: const [('https', 'https'), ('http', 'http')],
                onChanged: (nv) => setState(() => t.scheme = nv),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 90, child: TextField(controller: t.method, decoration: const InputDecoration(labelText: 'Method'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: t.host, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: tr('Host (mis. api.contoh.com)', 'Host (e.g. api.example.com)')))),
            const SizedBox(width: 8),
            SizedBox(width: 90, child: TextField(controller: t.port, decoration: const InputDecoration(labelText: 'Port'))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: t.path, decoration: const InputDecoration(labelText: 'Path'))),
            const SizedBox(width: 8),
            OutlinedButton.icon(onPressed: () => _askAi(t), icon: const Icon(Icons.auto_awesome_rounded, size: 18), label: Text(tr('Tanya AI', 'Ask AI'))),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: t.sending ? null : () => _send(t),
              icon: t.sending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(tr('Kirim', 'Send')),
            ),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _panel(tr('Request (header + body)', 'Request (headers + body)'), TextField(
                  controller: t.req,
                  expands: true,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: YmTextStyles.mono,
                  decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(12)),
                  contextMenuBuilder: editableMenu([
                    EditAction(tr('Tanya AI', 'Ask AI'), () => _askAi(t)),
                    EditAction(tr('Kirim ke Intruder', 'Send to Intruder'), () {
                      IntruderInbox.send(_seed(t));
                      Nav.go('intruder');
                    }),
                  ]),
                ))),
                const SizedBox(width: 12),
                Expanded(child: _panel('Response', _respView(t))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(String title, Widget child) {
    return Container(
      decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: YmColors.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: YmColors.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(title, style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _respView(_Session t) {
    final r = t.resp;
    if (r == null) return Center(child: Text(tr('Belum ada response.', 'No response yet.'), style: YmTextStyles.bodySm));
    if (r['ok'] != true) {
      return Padding(padding: const EdgeInsets.all(12), child: Text('${tr('Gagal', 'Failed')}: ${r['error']}', style: YmTextStyles.bodySm.copyWith(color: YmColors.danger)));
    }
    final b = StringBuffer();
    b.writeln('HTTP ${r['status']} ${r['reason']}   •   ${r['duration_ms']} ms   •   ${r['length']} B');
    b.writeln('');
    (r['headers'] as Map).forEach((k, v) => b.writeln('$k: $v'));
    b.writeln('');
    b.write(r['body'] ?? '');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        b.toString(),
        style: YmTextStyles.mono,
        contextMenuBuilder: editableMenu([EditAction(tr('Tanya AI', 'Ask AI'), () => _askAi(t))]),
      ),
    );
  }
}
