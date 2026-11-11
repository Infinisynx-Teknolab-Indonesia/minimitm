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

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int? _selId;
  Map<String, dynamic>? _detail;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    Api.instance.onFlow.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _sendTo(int id, String target) async {
    final d = await Api.instance.flowDetail(id);
    if (d == null || !mounted) return;
    if (target == 'repeater') {
      RepeaterInbox.send(d);
      Nav.go('repeater');
    } else {
      IntruderInbox.send(d);
      Nav.go('intruder');
    }
  }

  String _ctx(Map<String, dynamic> d) => '=== REQUEST ===\n${_reqText(d)}\n\n=== RESPONSE ===\n${_resText(d)}';

  String get _aiStarter => tr(
      'Analisa kelemahan keamanan dari request & response ini, dan jelaskan cara memverifikasi / bypass / mengeksploitasinya. Ini aplikasi milikku sendiri.',
      'Analyse the security weaknesses of this request & response, and explain how to verify / bypass / exploit them. This is my own app.');

  void _openAi(Map<String, dynamic> d) =>
      showAiDialog(context, title: '${d['method']} ${d['host']}', attachment: _ctx(d), starter: _aiStarter);

  Future<void> _askAi(int id) async {
    final d = await Api.instance.flowDetail(id);
    if (d == null || !mounted) return;
    _openAi(d);
  }

  void _rowMenu(Map<String, dynamic> f, Offset pos) {
    final id = f['id'] as int;
    showCtxMenu(context, pos, [
      CtxItem(tr('Tanya AI', 'Ask AI'), Icons.auto_awesome_rounded, () => _askAi(id)),
      CtxItem(tr('Kirim ke Repeater', 'Send to Repeater'), Icons.send_outlined, () => _sendTo(id, 'repeater')),
      CtxItem(tr('Kirim ke Intruder', 'Send to Intruder'), Icons.rocket_launch_outlined, () => _sendTo(id, 'intruder')),
      CtxItem(tr('Kirim ke Comparer', 'Send to Comparer'), Icons.compare_arrows_rounded, () async {
        final d = await Api.instance.flowDetail(id);
        if (d != null && mounted) {
          ComparerInbox.send(_resText(d));
          Nav.go('comparer');
        }
      }),
      CtxItem(tr('Salin URL', 'Copy URL'), Icons.link_rounded, () {
        Clipboard.setData(ClipboardData(text: f['url'] as String));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('URL disalin.', 'URL copied.'))));
      }),
      CtxItem(tr('Lihat detail', 'View details'), Icons.open_in_full_rounded, () => _select(id)),
      CtxItem(tr('Bersihkan semua', 'Clear all'), Icons.delete_outline_rounded, () async {
        await Api.instance.clearHistory();
        if (mounted) setState(() => _selId = null);
      }, danger: true),
    ]);
  }

  Future<void> _select(int id) async {
    setState(() {
      _selId = id;
      _detail = null;
    });
    final d = await Api.instance.flowDetail(id);
    if (mounted && _selId == id) setState(() => _detail = d);
  }

  @override
  Widget build(BuildContext context) {
    final all = Api.instance.flows;
    final flows = _filter.isEmpty
        ? all
        : all.where((f) => (f['url'] as String).toLowerCase().contains(_filter.toLowerCase()) || (f['host'] as String).toLowerCase().contains(_filter.toLowerCase())).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(
            children: [
              Text('HTTP History', style: YmTextStyles.sectionTitle),
              const SizedBox(width: 12),
              SoftChip.neutral('${flows.length} ${tr('request', 'requests')}'),
              const Spacer(),
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: InputDecoration(hintText: tr('Saring host / URL…', 'Filter host / URL…'), prefixIcon: const Icon(Icons.search_rounded, size: 18)),
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Api.instance.clearHistory();
                  setState(() {
                    _selId = null;
                    _detail = null;
                  });
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(tr('Bersihkan', 'Clear')),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _table(flows),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: _detailPane(),
          ),
        ),
      ],
    );
  }

  Widget _table(List<Map<String, dynamic>> flows) {
    return Container(
      decoration: BoxDecoration(
        color: YmColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: YmColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: YmColors.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              _h('#', 46),
              _h('Method', 64),
              _h('Host', 180),
              _h('URL', null),
              _h('Status', 56),
              _h('Len', 64),
              _h(tr('Tipe', 'Type'), 110),
            ]),
          ),
          Expanded(
            child: flows.isEmpty
                ? EmptyState(icon: Icons.inbox_outlined, title: tr('Belum ada lalu lintas', 'No traffic yet'), message: tr('Nyalakan proxy dan buka aplikasimu. Request muncul di sini secara langsung.', 'Start the proxy and open your app. Requests appear here live.'))
                : ListView.builder(
                    itemCount: flows.length,
                    itemBuilder: (context, i) {
                      final f = flows[i];
                      final sel = f['id'] == _selId;
                      return InkWell(
                        onTap: () => _select(f['id'] as int),
                        onSecondaryTapDown: (d) => _rowMenu(f, d.globalPosition),
                        child: Container(
                          color: sel ? YmColors.surfaceHigh : (i.isEven ? Colors.transparent : YmColors.surfaceAlt.withOpacity(0.4)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          child: Row(children: [
                            _c('${f['id']}', 46, muted: true),
                            SizedBox(width: 64, child: Text(f['method'] as String, style: YmTextStyles.labelSm.copyWith(color: methodColor(f['method'] as String), fontWeight: FontWeight.w700))),
                            _c(f['host'] as String, 180),
                            Expanded(child: Text(_pathOf(f), maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.bodySm)),
                            SizedBox(width: 56, child: Text('${f['status']}', style: YmTextStyles.labelSm.copyWith(color: statusColor(f['status'] as int? ?? 0), fontWeight: FontWeight.w700))),
                            _c('${f['length']}', 64, muted: true),
                            _c((f['mime'] as String?) ?? '', 110, muted: true),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _pathOf(Map<String, dynamic> f) {
    final url = f['url'] as String;
    final scheme = f['scheme'] == 'https' ? '🔒 ' : '';
    return scheme + url;
  }

  Widget _h(String t, double? w) {
    final child = Text(t, style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontWeight: FontWeight.w700));
    return w == null ? Expanded(child: child) : SizedBox(width: w, child: child);
  }

  Widget _c(String t, double w, {bool muted = false}) =>
      SizedBox(width: w, child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted ? YmTextStyles.labelSm : YmTextStyles.bodySm));

  Widget _detailPane() {
    if (_selId == null) {
      return Container(
        decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: YmColors.line)),
        child: Center(child: Text(tr('Pilih satu request untuk melihat detail.', 'Select a request to see details.'), style: YmTextStyles.bodySm)),
      );
    }
    final d = _detail;
    return Container(
      decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: YmColors.line)),
      clipBehavior: Clip.antiAlias,
      child: d == null
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(child: TabBar(tabs: [Tab(text: 'Request'), Tab(text: 'Response')])),
                      TextButton.icon(
                        onPressed: () => _openAi(d),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                        label: Text(tr('Tanya AI', 'Ask AI')),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          RepeaterInbox.send(d);
                          Nav.go('repeater');
                        },
                        icon: const Icon(Icons.send_outlined, size: 16),
                        label: Text(tr('Kirim ke Repeater', 'Send to Repeater')),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(children: [
                      _msgView(d, _reqText(d)),
                      _msgView(d, _resText(d)),
                    ]),
                  ),
                ],
              ),
            ),
    );
  }

  String _reqText(Map<String, dynamic> d) {
    final b = StringBuffer();
    b.writeln('${d['method']} ${d['path']} HTTP/1.1');
    (d['req_headers'] as Map).forEach((k, v) => b.writeln('$k: $v'));
    b.writeln();
    b.write(d['req_body'] ?? '');
    return b.toString();
  }

  String _resText(Map<String, dynamic> d) {
    final b = StringBuffer();
    b.writeln('HTTP/1.1 ${d['status']}');
    (d['res_headers'] as Map).forEach((k, v) => b.writeln('$k: $v'));
    b.writeln();
    b.write(d['res_body'] ?? '');
    return b.toString();
  }

  Widget _msgView(Map<String, dynamic> d, String text) {
    return FindableView(
      text: text,
      readOnly: true,
      contextMenuBuilder: editableMenu([
        EditAction(tr('Tanya AI', 'Ask AI'), () => _openAi(d)),
        EditAction(tr('Kirim ke Repeater', 'Send to Repeater'), () {
          RepeaterInbox.send(d);
          Nav.go('repeater');
        }),
        EditAction(tr('Kirim ke Intruder', 'Send to Intruder'), () {
          IntruderInbox.send(d);
          Nav.go('intruder');
        }),
        EditAction(tr('Kirim ke Comparer', 'Send to Comparer'), () {
          ComparerInbox.send(text);
          Nav.go('comparer');
        }),
      ]),
    );
  }
}
