import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';
import '../widgets/ai_dialog.dart';

/// Jembatan: History -> Comparer (isi slot A lalu B).
class ComparerInbox {
  static final ValueNotifier<int> tick = ValueNotifier(0);
  static String? _pending;
  static int _slot = 0;
  static void send(String text) {
    _pending = text;
    tick.value++;
  }

  static (int, String)? take() {
    if (_pending == null) return null;
    final s = _slot;
    _slot = (_slot + 1) % 2;
    final t = _pending!;
    _pending = null;
    return (s, t);
  }
}

class ComparerPage extends StatefulWidget {
  const ComparerPage({super.key});
  @override
  State<ComparerPage> createState() => _ComparerPageState();
}

class _ComparerPageState extends State<ComparerPage> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  List<(int, String)> _diff = []; // 0 sama, 1 hanya A, 2 hanya B

  @override
  void initState() {
    super.initState();
    ComparerInbox.tick.addListener(_recv);
    _recv();
  }

  @override
  void dispose() {
    ComparerInbox.tick.removeListener(_recv);
    super.dispose();
  }

  void _recv() {
    final r = ComparerInbox.take();
    if (r == null) return;
    setState(() {
      if (r.$1 == 0) {
        _a.text = r.$2;
      } else {
        _b.text = r.$2;
      }
    });
  }

  void _compare() {
    final a = _a.text.split('\n');
    final b = _b.text.split('\n');
    // LCS sederhana pada baris
    final n = a.length, m = b.length;
    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        dp[i][j] = a[i] == b[j] ? dp[i + 1][j + 1] + 1 : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
      }
    }
    final out = <(int, String)>[];
    var i = 0, j = 0;
    while (i < n && j < m) {
      if (a[i] == b[j]) {
        out.add((0, a[i]));
        i++;
        j++;
      } else if (dp[i + 1][j] >= dp[i][j + 1]) {
        out.add((1, a[i]));
        i++;
      } else {
        out.add((2, b[j]));
        j++;
      }
    }
    while (i < n) {
      out.add((1, a[i++]));
    }
    while (j < m) {
      out.add((2, b[j++]));
    }
    setState(() => _diff = out);
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      scroll: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            crumbs: [tr('Alat', 'Tools'), 'Comparer'],
            title: 'Comparer',
            subtitle: tr('Bandingkan dua teks (mis. dua response). Kirim dari HTTP History lewat "Kirim ke Comparer".',
                'Compare two texts (e.g. two responses). Send from HTTP History via "Send to Comparer".'),
            actions: [
              OutlinedButton.icon(
                onPressed: () => showAiDialog(context, title: 'Comparer', attachment: '=== A ===\n${_a.text}\n\n=== B ===\n${_b.text}', starter: tr('Apa beda penting antara A dan B, dan apa artinya dari sisi keamanan?', 'What are the key differences between A and B, and what do they mean security-wise?')),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(tr('Tanya AI', 'Ask AI')),
              ),
              ElevatedButton.icon(onPressed: _compare, icon: const Icon(Icons.compare_arrows_rounded, size: 18), label: Text(tr('Bandingkan', 'Compare'))),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _panel('A', TextField(controller: _a, expands: true, maxLines: null, textAlignVertical: TextAlignVertical.top, style: YmTextStyles.mono, decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(12))))),
              const SizedBox(width: 10),
              Expanded(child: _panel('B', TextField(controller: _b, expands: true, maxLines: null, textAlignVertical: TextAlignVertical.top, style: YmTextStyles.mono, decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(12))))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _panel(tr('Perbedaan', 'Diff'), _diffView())),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _panel(String title, Widget child) {
    return Container(
      decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: YmColors.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(color: YmColors.surfaceAlt, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text(title, style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontWeight: FontWeight.w700))),
        Expanded(child: child),
      ]),
    );
  }

  Widget _diffView() {
    if (_diff.isEmpty) return Center(child: Text(tr('Tekan Bandingkan.', 'Press Compare.'), style: YmTextStyles.bodySm));
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _diff.length,
      itemBuilder: (context, i) {
        final (kind, line) = _diff[i];
        final (Color bg, String sign) = switch (kind) {
          1 => (YmColors.dangerSoft.withOpacity(0.5), '−'),
          2 => (YmColors.successContainer.withOpacity(0.4), '+'),
          _ => (Colors.transparent, ' '),
        };
        return Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          child: Text('$sign $line', style: YmTextStyles.mono),
        );
      },
    );
  }
}
