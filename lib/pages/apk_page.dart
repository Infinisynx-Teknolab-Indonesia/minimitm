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

  @override
  void initState() {
    super.initState();
    _avail();
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
    });
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
                OutlinedButton.icon(onPressed: _avail, icon: const Icon(Icons.refresh_rounded, size: 16), label: Text(tr('Cek', 'Check'))),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in ['java', 'apktool', 'jadx', 'zipalign', 'apksigner', 'keytool'])
                  SoftChip(
                    t,
                    icon: (_tools[t] ?? '').toString().isNotEmpty ? Icons.check_rounded : Icons.close_rounded,
                    fg: (_tools[t] ?? '').toString().isNotEmpty ? YmColors.onSuccessSoft : YmColors.onDangerSoft,
                    bg: (_tools[t] ?? '').toString().isNotEmpty ? YmColors.successContainer.withOpacity(0.4) : YmColors.dangerSoft,
                    pill: true, bold: true,
                  ),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          HoverCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: _apk, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('Path file APK', 'APK file path'), hintText: r'C:\Users\kamu\app.apk')),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ElevatedButton.icon(onPressed: _busy ? null : _patch, icon: const Icon(Icons.build_rounded, size: 18), label: Text(tr('Patch untuk proxy (1 klik)', 'Patch for proxy (1-click)'))),
                OutlinedButton.icon(onPressed: _busy ? null : _jadx, icon: const Icon(Icons.code_rounded, size: 18), label: Text(tr('Decompile (jadx)', 'Decompile (jadx)'))),
              ]),
              if (_busy) ...[const SizedBox(height: 12), Row(children: [SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: YmColors.primary)), const SizedBox(width: 10), Text(tr('Memproses… (bisa 1-2 menit)', 'Working… (may take 1-2 min)'), style: YmTextStyles.bodySm)])],
              if (_output.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: YmColors.successContainer.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: YmColors.success),
                    const SizedBox(width: 8),
                    Expanded(child: SelectableText('${tr('Hasil', 'Output')}: $_output', style: YmTextStyles.mono)),
                    IconButton(icon: Icon(Icons.copy_rounded, size: 15, color: YmColors.outline), onPressed: () { Clipboard.setData(ClipboardData(text: _output)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Disalin.', 'Copied.')))); }),
                  ]),
                ),
              ],
            ]),
          ),
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
}
