import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';
import '../widgets/ai_dialog.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  List<Map<String, dynamic>> _findings = [];
  int _scanned = 0;
  bool _running = false;

  Future<void> _scan() async {
    setState(() => _running = true);
    final r = await Api.instance.scan();
    if (!mounted) return;
    setState(() {
      _findings = (r['findings'] as List).cast<Map<String, dynamic>>();
      _scanned = r['scanned'] as int? ?? 0;
      _running = false;
    });
  }

  Color _sevColor(String s) => switch (s) {
        'high' => YmColors.danger,
        'medium' => YmColors.warning,
        'low' => YmColors.accent,
        _ => YmColors.textMuted,
      };

  SoftChip _sevChip(String s) => switch (s) {
        'high' => SoftChip.danger('HIGH'),
        'medium' => SoftChip.warning('MEDIUM'),
        'low' => SoftChip('LOW', fg: YmColors.link, bg: YmColors.primarySoft, pill: true, bold: true),
        _ => SoftChip.neutral('INFO'),
      };

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            crumbs: [tr('Alat', 'Tools'), 'Scanner'],
            title: 'Scanner',
            subtitle: tr('Pemeriksaan pasif atas lalu lintas yang sudah tertangkap: header keamanan, cookie, info bocor, CORS, rahasia. Hanya untuk aplikasi milikmu.',
                'Passive checks over captured traffic: security headers, cookies, info leaks, CORS, secrets. Only for your own apps.'),
            actions: [
              ElevatedButton.icon(
                onPressed: _running ? null : _scan,
                icon: _running
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.radar_rounded, size: 18),
                label: Text(_running ? tr('Memindai…', 'Scanning…') : tr('Scan sekarang', 'Scan now')),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_findings.isEmpty && !_running)
            HoverCard(
              child: SizedBox(
                height: 220,
                child: EmptyState(
                  icon: Icons.verified_outlined,
                  title: tr('Belum ada hasil', 'No results yet'),
                  message: tr('Tekan "Scan sekarang" untuk memeriksa semua request yang sudah tertangkap di HTTP History.',
                      'Press "Scan now" to check all requests captured in HTTP History.'),
                ),
              ),
            )
          else ...[
            Row(children: [
              SoftChip.neutral('$_scanned ${tr('request diperiksa', 'requests checked')}'),
              const SizedBox(width: 8),
              SoftChip.danger('${_findings.where((f) => f['severity'] == 'high').length} high'),
              const SizedBox(width: 8),
              SoftChip.warning('${_findings.where((f) => f['severity'] == 'medium').length} medium'),
            ]),
            const SizedBox(height: 12),
            for (final f in _findings) ...[
              HoverCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _sevChip(f['severity'] as String),
                      const SizedBox(width: 10),
                      Expanded(child: Text(f['title'] as String, style: YmTextStyles.headlineSm)),
                      TextButton.icon(
                        onPressed: () => showAiDialog(
                          context,
                          title: f['title'] as String,
                          attachment: '[${f['severity']}] ${f['title']}\nURL: ${f['url']}\n\n${f['detail']}\n\n${tr('Bukti', 'Evidence')}:\n${f['evidence'] ?? ''}',
                          starter: tr('Jelaskan temuan ini, dampaknya, cara verifikasi & cara perbaiki.', 'Explain this finding, its impact, how to verify and how to fix it.'),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                        label: Text(tr('Tanya AI', 'Ask AI')),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(f['detail'] as String, style: YmTextStyles.bodySm),
                    const SizedBox(height: 8),
                    Text(f['url'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelSm.copyWith(color: _sevColor(f['severity'] as String))),
                    if ((f['evidence'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                        child: SelectableText(f['evidence'] as String, style: YmTextStyles.mono, maxLines: 4),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}
