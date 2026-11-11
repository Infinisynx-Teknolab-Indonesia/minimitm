import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/nav.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';
import '../widgets/context_menu.dart';
import '../widgets/ai_dialog.dart';
import '../widgets/editor_menu.dart';
import '../widgets/findable_view.dart';
import 'repeater_page.dart';
import 'intruder_page.dart';
import 'comparer_page.dart';

/// Intercept gaya History: tabel di atas, detail Request/Response di bawah.
/// Item tertahan punya `phase`: 'request' (default) atau 'response'.
/// - phase request  : tab Request bisa diedit, Response belum ada.
/// - phase response : tab Response bisa diedit, Request hanya baca.
class InterceptPage extends StatefulWidget {
  const InterceptPage({super.key});
  @override
  State<InterceptPage> createState() => _InterceptPageState();
}

class _InterceptPageState extends State<InterceptPage> with SingleTickerProviderStateMixin {
  final _reqC = HighlightController();
  final _resC = HighlightController();
  late final TabController _tab = TabController(length: 2, vsync: this);
  String? _loadedKey; // "id:phase" yang sedang dimuat ke editor
  String? _selKey;

  @override
  void dispose() {
    _reqC.dispose();
    _resC.dispose();
    _tab.dispose();
    super.dispose();
  }

  // ---------- util ----------
  static String _phase(Map<String, dynamic> r) => (r['phase'] as String?) ?? 'request';
  static String _key(Map<String, dynamic> r) => '${r['id']}:${_phase(r)}';
  static bool _isRes(Map<String, dynamic> r) => _phase(r) == 'response';

  String _reqText(Map<String, dynamic> r) {
    final b = StringBuffer();
    b.writeln('${r['method']} ${r['path']} HTTP/1.1');
    ((r['headers'] ?? r['req_headers'] ?? {}) as Map).forEach((k, v) => b.writeln('$k: $v'));
    b.writeln();
    b.write(r['body'] ?? r['req_body'] ?? '');
    return b.toString();
  }

  String _resText(Map<String, dynamic> r) {
    final b = StringBuffer();
    b.writeln('HTTP/1.1 ${r['status'] ?? 200}');
    ((r['res_headers'] ?? {}) as Map).forEach((k, v) => b.writeln('$k: $v'));
    b.writeln();
    b.write(r['res_body'] ?? '');
    return b.toString();
  }

  void _load(Map<String, dynamic> r) {
    _loadedKey = _key(r);
    _selKey = _loadedKey;
    _reqC.text = _reqText(r);
    _resC.text = _isRes(r) ? _resText(r) : '';
    _tab.index = _isRes(r) ? 1 : 0;
  }

  (String, String, Map<String, String>, String) _parseReq(String text) {
    final lines = text.split('\n');
    String method = 'GET', path = '/';
    if (lines.isNotEmpty) {
      final parts = lines[0].trim().split(' ');
      if (parts.length >= 2) {
        method = parts[0];
        path = parts[1];
      }
    }
    final (h, b) = _headersBody(lines, 1);
    return (method, path, h, b);
  }

  (int, Map<String, String>, String) _parseRes(String text) {
    final lines = text.split('\n');
    int status = 200;
    if (lines.isNotEmpty) {
      final parts = lines[0].trim().split(' ');
      if (parts.length >= 2) status = int.tryParse(parts[1]) ?? 200;
    }
    final (h, b) = _headersBody(lines, 1);
    return (status, h, b);
  }

  (Map<String, String>, String) _headersBody(List<String> lines, int start) {
    final headers = <String, String>{};
    int i = start;
    for (; i < lines.length; i++) {
      final line = lines[i].trimRight();
      if (line.isEmpty) {
        i++;
        break;
      }
      final idx = line.indexOf(':');
      if (idx > 0) headers[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
    }
    return (headers, i < lines.length ? lines.sublist(i).join('\n') : '');
  }

  /// Bentuk "detail flow" (sama seperti History) dari item tertahan + hasil edit,
  /// supaya Repeater / Intruder / AI bisa memakainya.
  Map<String, dynamic> _asDetail(Map<String, dynamic> r) {
    final (m, p, h, b) = _parseReq(_reqC.text);
    final d = <String, dynamic>{
      'id': r['id'],
      'scheme': r['scheme'] ?? 'https',
      'host': r['host'],
      'method': m,
      'path': p,
      'url': r['url'] ?? '${r['scheme'] ?? 'https'}://${r['host']}$p',
      'req_headers': h,
      'req_body': b,
    };
    if (_isRes(r)) {
      final (st, rh, rb) = _parseRes(_resC.text);
      d['status'] = st;
      d['res_headers'] = rh;
      d['res_body'] = rb;
    }
    return d;
  }

  // ---------- aksi ----------
  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _forward(Map<String, dynamic> r, {bool modified = false}) async {
    Map<String, dynamic>? mod;
    if (modified) {
      if (_isRes(r)) {
        final (st, h, b) = _parseRes(_resC.text);
        mod = {'status': st, 'headers': h, 'body': b};
      } else {
        final (m, p, h, b) = _parseReq(_reqC.text);
        mod = {'method': m, 'path': p, 'headers': h, 'body': b};
      }
    }
    await Api.instance.resolveIntercept(r['id'] as int, 'forward', modified: mod, phase: _phase(r));
    _afterResolve(r);
  }

  Future<void> _drop(Map<String, dynamic> r) async {
    await Api.instance.resolveIntercept(r['id'] as int, 'drop', phase: _phase(r));
    _afterResolve(r);
  }

  void _afterResolve(Map<String, dynamic> r) {
    if (_loadedKey == _key(r)) {
      _loadedKey = null;
      _selKey = null;
      _reqC.clear();
      _resC.clear();
    }
    if (mounted) setState(() {});
  }

  void _sendRepeater(Map<String, dynamic> r) {
    RepeaterInbox.send(_asDetail(r));
    Nav.go('repeater');
  }

  void _sendIntruder(Map<String, dynamic> r) {
    IntruderInbox.send(_asDetail(r));
    Nav.go('intruder');
  }

  void _sendComparer(String text) {
    ComparerInbox.send(text);
    Nav.go('comparer');
  }

  String _ctx(Map<String, dynamic> r) {
    final s = StringBuffer('=== REQUEST ===\n${_reqC.text}');
    if (_isRes(r)) s.write('\n\n=== RESPONSE ===\n${_resC.text}');
    return s.toString();
  }

  String get _aiStarter => tr(
      'Analisa kelemahan keamanan dari request & response ini, dan jelaskan cara memverifikasi / bypass / mengeksploitasinya. Ini aplikasi milikku sendiri.',
      'Analyse the security weaknesses of this request & response, and explain how to verify / bypass / exploit them. This is my own app.');

  void _askAi(Map<String, dynamic> r) =>
      showAiDialog(context, title: '${r['method']} ${r['host']}', attachment: _ctx(r), starter: _aiStarter);

  Future<void> _sendPlugin(Map<String, dynamic> r) async {
    List<Map<String, dynamic>> plugins;
    try {
      plugins = (await Api.instance.plugins()).where((p) => p['has_action'] == true && p['error'] == null).toList();
    } catch (_) {
      plugins = [];
    }
    if (!mounted) return;
    if (plugins.isEmpty) {
      _toast(tr('Tidak ada plugin manual yang tersedia.', 'No manual plugins available.'));
      return;
    }
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 460),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.all(16), child: Text(tr('Kirim ke Plugin', 'Send to Plugin'), style: YmTextStyles.headlineSm)),
            const Divider(height: 1),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final p in plugins)
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.extension_outlined, size: 18, color: YmColors.primary),
                    title: Text(p['name'] as String, style: YmTextStyles.labelMd),
                    subtitle: Text(p['description'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.bodySm),
                    onTap: () => Navigator.pop(context, p),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    Map<String, dynamic> res;
    try {
      res = await Api.instance.runPluginRaw(picked['name'] as String, _asDetail(r));
    } catch (e) {
      res = {'ok': false, 'error': '$e'};
    }
    if (!mounted) return;
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.extension_outlined, color: YmColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${picked['name']} — ${tr('hasil', 'result')}', style: YmTextStyles.headlineSm)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ]),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  res['ok'] == true ? (res['result'] as String? ?? tr('(kosong)', '(empty)')) : '${tr('Gagal', 'Failed')}: ${res['error']}',
                  style: YmTextStyles.mono,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Aksi kirim-ke-mana-saja; dipakai klik kanan baris & klik kanan editor.
  /// Untuk baris yang belum dimuat ke editor, dimuat dulu supaya edit ikut terkirim.
  List<EditAction> _editorActions(Map<String, dynamic> r, {required bool onResponse}) => [
        EditAction(tr('Tanya AI', 'Ask AI'), () => _askAi(r)),
        EditAction(tr('Kirim ke Repeater', 'Send to Repeater'), () => _sendRepeater(r)),
        EditAction(tr('Kirim ke Intruder', 'Send to Intruder'), () => _sendIntruder(r)),
        EditAction(tr('Kirim ke Comparer', 'Send to Comparer'), () => _sendComparer(onResponse ? _resC.text : _reqC.text)),
        EditAction(tr('Kirim ke Plugin', 'Send to Plugin'), () => _sendPlugin(r)),
        EditAction(tr('Teruskan', 'Forward'), () => _forward(r, modified: true)),
        EditAction('Drop', () => _drop(r)),
      ];

  void _rowMenu(Map<String, dynamic> r, Offset pos) {
    if (_loadedKey != _key(r)) setState(() => _load(r));
    showCtxMenu(context, pos, [
      CtxItem(tr('Tanya AI', 'Ask AI'), Icons.auto_awesome_rounded, () => _askAi(r)),
      CtxItem(tr('Kirim ke Repeater', 'Send to Repeater'), Icons.send_outlined, () => _sendRepeater(r)),
      CtxItem(tr('Kirim ke Intruder', 'Send to Intruder'), Icons.rocket_launch_outlined, () => _sendIntruder(r)),
      CtxItem(tr('Kirim ke Comparer', 'Send to Comparer'), Icons.compare_arrows_rounded,
          () => _sendComparer(_isRes(r) ? _resC.text : _reqC.text)),
      CtxItem(tr('Kirim ke Plugin', 'Send to Plugin'), Icons.extension_outlined, () => _sendPlugin(r)),
      CtxItem(tr('Salin URL', 'Copy URL'), Icons.link_rounded, () {
        final url = (r['url'] as String?) ?? 'https://${r['host']}${r['path']}';
        Clipboard.setData(ClipboardData(text: url));
        _toast(tr('URL disalin.', 'URL copied.'));
      }),
      CtxItem(tr('Teruskan apa adanya', 'Forward as-is'), Icons.fast_forward_rounded, () => _forward(r)),
      CtxItem('Drop', Icons.block_rounded, () => _drop(r), danger: true),
    ]);
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Api.instance,
      builder: (context, _) {
        final api = Api.instance;
        final pending = [...api.pendingIntercept]
          ..sort((a, b) => ((b['id'] as num?) ?? 0).compareTo((a['id'] as num?) ?? 0)); // terbaru di atas
        if (_selKey != null && !pending.any((e) => _key(e) == _selKey)) {
          _selKey = null;
          _loadedKey = null;
        }
        // Jangan ubah controller / tab saat build -> jadwalkan setelah frame.
        if (_selKey == null && pending.isNotEmpty) {
          final first = pending.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_selKey == null) setState(() => _load(first));
          });
        }
        Map<String, dynamic>? sel;
        for (final e in pending) {
          if (_key(e) == _selKey) sel = e;
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(children: [
                Text('Intercept', style: YmTextStyles.sectionTitle),
                const SizedBox(width: 12),
                SoftChip.neutral('${pending.length} ${tr('tertahan', 'held')}'),
                const Spacer(),
                Text(tr('Request', 'Request'), style: YmTextStyles.labelMd),
                const SizedBox(width: 6),
                Switch(value: api.intercepting, onChanged: (v) => api.putConfig({'intercept': v})),
                const SizedBox(width: 12),
                Text('Response', style: YmTextStyles.labelMd),
                const SizedBox(width: 6),
                Switch(value: api.status['intercept_response'] == true, onChanged: (v) => api.putConfig({'intercept_response': v})),
              ]),
            ),
            Expanded(flex: 3, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _table(pending))),
            const SizedBox(height: 12),
            Expanded(flex: 4, child: Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), child: _detail(sel, api))),
          ],
        );
      },
    );
  }

  Widget _box({required Widget child}) => Container(
        decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: YmColors.line)),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

  Widget _h(String t, double? w) {
    final child = Text(t, style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontWeight: FontWeight.w700));
    return w == null ? Expanded(child: child) : SizedBox(width: w, child: child);
  }

  Widget _c(String t, double w, {bool muted = false}) =>
      SizedBox(width: w, child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted ? YmTextStyles.labelSm : YmTextStyles.bodySm));

  Widget _table(List<Map<String, dynamic>> pending) {
    final api = Api.instance;
    return _box(
      child: Column(children: [
        Container(
          color: YmColors.surfaceAlt,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            _h('#', 46),
            _h(tr('Fase', 'Phase'), 84),
            _h('Method', 64),
            _h('Host', 180),
            _h('URL', null),
            _h('Status', 56),
          ]),
        ),
        Expanded(
          child: pending.isEmpty
              ? EmptyState(
                  icon: Icons.pan_tool_outlined,
                  title: api.intercepting ? tr('Tidak ada yang tertahan', 'Nothing held') : tr('Mode intercept mati', 'Intercept mode is off'),
                  message: api.intercepting
                      ? tr('Request/response yang masuk akan muncul di sini untuk kamu teruskan / ubah / drop.', 'Incoming requests/responses appear here to forward / edit / drop.')
                      : tr('Nyalakan switch Request (dan Response) di atas, lalu buka aplikasimu.', 'Turn on the Request (and Response) switch above, then open your app.'))
              : ListView.builder(
                  itemCount: pending.length,
                  itemBuilder: (context, i) {
                    final r = pending[i];
                    final selected = _key(r) == _selKey;
                    final res = _isRes(r);
                    return InkWell(
                      onTap: () => setState(() => _load(r)),
                      onSecondaryTapDown: (d) => _rowMenu(r, d.globalPosition),
                      child: Container(
                        color: selected ? YmColors.surfaceHigh : (i.isEven ? Colors.transparent : YmColors.surfaceAlt.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        child: Row(children: [
                          _c('${r['id']}', 46, muted: true),
                          SizedBox(
                            width: 84,
                            child: Text(res ? 'RESPONSE' : 'REQUEST',
                                style: YmTextStyles.labelSm.copyWith(color: res ? YmColors.warning : YmColors.primary, fontWeight: FontWeight.w700)),
                          ),
                          SizedBox(width: 64, child: Text('${r['method']}', style: YmTextStyles.labelSm.copyWith(color: methodColor('${r['method']}'), fontWeight: FontWeight.w700))),
                          _c('${r['host']}', 180),
                          Expanded(child: Text('${r['scheme'] == 'https' ? '🔒 ' : ''}${r['url'] ?? r['path']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.bodySm)),
                          SizedBox(
                            width: 56,
                            child: Text(res ? '${r['status']}' : '',
                                style: YmTextStyles.labelSm.copyWith(color: statusColor(r['status'] as int? ?? 0), fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _editor(HighlightController c, Map<String, dynamic> r, {required bool onResponse, required bool readOnly}) {
    return FindableView(
      controller: c,
      readOnly: readOnly,
      contextMenuBuilder: editableMenu(_editorActions(r, onResponse: onResponse)),
    );
  }

  Widget _detail(Map<String, dynamic>? r, Api api) {
    if (r == null) {
      return _box(child: Center(child: Text(tr('Pilih satu item untuk melihat detail.', 'Select an item to see details.'), style: YmTextStyles.bodySm)));
    }
    final res = _isRes(r);
    return _box(
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TabBar(controller: _tab, tabs: [
              Tab(text: res ? tr('Request (baca saja)', 'Request (read-only)') : 'Request'),
              Tab(text: res ? 'Response' : tr('Response (belum ada)', 'Response (not yet)')),
            ]),
          ),
          TextButton.icon(onPressed: () => _askAi(r), icon: const Icon(Icons.auto_awesome_rounded, size: 16), label: Text(tr('Tanya AI', 'Ask AI'))),
          TextButton.icon(onPressed: () => _sendRepeater(r), icon: const Icon(Icons.send_outlined, size: 16), label: Text(tr('Kirim ke Repeater', 'Send to Repeater'))),
          const SizedBox(width: 8),
        ]),
        Expanded(
          child: TabBarView(controller: _tab, children: [
            _editor(_reqC, r, onResponse: false, readOnly: res),
            res
                ? _editor(_resC, r, onResponse: true, readOnly: false)
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                          tr('Response belum ada. Teruskan request ini; jika switch Response menyala, response-nya akan tertahan di sini dan bisa kamu ubah.',
                              'No response yet. Forward this request; if the Response switch is on, its response will be held here for editing.'),
                          textAlign: TextAlign.center,
                          style: YmTextStyles.bodySm),
                    ),
                  ),
          ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            ElevatedButton.icon(
              onPressed: () => _forward(r, modified: true),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: Text(tr('Teruskan (dengan perubahan)', 'Forward (with changes)')),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(onPressed: () => _forward(r), icon: const Icon(Icons.fast_forward_rounded, size: 18), label: Text(tr('Teruskan apa adanya', 'Forward as-is'))),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _drop(r),
              style: OutlinedButton.styleFrom(foregroundColor: YmColors.danger),
              icon: const Icon(Icons.block_rounded, size: 18),
              label: const Text('Drop'),
            ),
          ]),
        ),
      ]),
    );
  }
}
