import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';

class WebSocketPage extends StatefulWidget {
  const WebSocketPage({super.key});
  @override
  State<WebSocketPage> createState() => _WebSocketPageState();
}

class _WebSocketPageState extends State<WebSocketPage> {
  String _filter = '';

  @override
  void initState() {
    super.initState();
    Api.instance.onWs.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = Api.instance.wsMessages;
    final msgs = _filter.isEmpty ? all : all.where((m) => (m['text'] as String? ?? '').toLowerCase().contains(_filter.toLowerCase()) || (m['host'] as String? ?? '').toLowerCase().contains(_filter.toLowerCase())).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(children: [
            Text('WebSocket', style: YmTextStyles.sectionTitle),
            const SizedBox(width: 12),
            SoftChip.neutral('${msgs.length} ${tr('pesan', 'messages')}'),
            const Spacer(),
            SizedBox(width: 240, child: TextField(decoration: InputDecoration(hintText: tr('Saring teks / host…', 'Filter text / host…'), prefixIcon: const Icon(Icons.search_rounded, size: 18)), onChanged: (v) => setState(() => _filter = v))),
            const SizedBox(width: 8),
            OutlinedButton.icon(onPressed: () => Api.instance.wsClear(), icon: const Icon(Icons.delete_outline_rounded, size: 18), label: Text(tr('Bersihkan', 'Clear'))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
          child: Text(tr('Frame WebSocket langsung (⬆ keluar / ⬇ masuk). Butuh proxy jalan + trafik WS lewat proxy.',
              'Live WebSocket frames (⬆ outgoing / ⬇ incoming). Needs the proxy running + WS traffic via the proxy.'), style: YmTextStyles.bodySm),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
            child: Container(
              decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: YmColors.line)),
              clipBehavior: Clip.antiAlias,
              child: msgs.isEmpty
                  ? EmptyState(icon: Icons.swap_horiz_rounded, title: tr('Belum ada frame WebSocket', 'No WebSocket frames yet'), message: tr('Buka aplikasi yang memakai WebSocket lewat proxy ini.', 'Open an app that uses WebSocket through this proxy.'))
                  : ListView.builder(
                      itemCount: msgs.length,
                      itemBuilder: (context, i) {
                        final m = msgs[i];
                        final out = m['dir'] == 'out';
                        final op = (m['opcode'] ?? 'text').toString();
                        final ctrl = op != 'text' && op != 'binary';
                        return Container(
                          color: i.isEven ? Colors.transparent : YmColors.surfaceAlt.withOpacity(0.4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(out ? Icons.north_rounded : Icons.south_rounded, size: 15, color: out ? YmColors.accent : YmColors.success),
                            const SizedBox(width: 8),
                            SizedBox(width: 70, child: Text(m['host'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelSm)),
                            if (ctrl) Padding(padding: const EdgeInsets.only(right: 6), child: SoftChip.neutral(op)),
                            Expanded(child: SelectableText(m['text'] as String? ?? '', style: YmTextStyles.mono, maxLines: 3)),
                          ]),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
