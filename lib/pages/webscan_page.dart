import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';

/// Menu "Cek Kelemahan Web" — pemindai AKTIF (DAST) untuk aplikasi/website
/// MILIKMU: XSS, SQL Injection, LFI/Path Traversal, Open Redirect, CRLF, dan
/// misconfig header. Hasil bisa langsung ditanyakan ke AI lokal (Pengaturan > AI).
class WebScanPage extends StatefulWidget {
  const WebScanPage({super.key});
  @override
  State<WebScanPage> createState() => _WebScanPageState();
}

class _WebScanPageState extends State<WebScanPage> {
  final _url = TextEditingController();
  final _body = TextEditingController();
  String _method = 'GET';
  final Set<String> _checks = {'xss', 'sqli', 'lfi', 'redirect', 'crlf', 'headers'};
  bool _busy = false;
  List<Map<String, dynamic>> _findings = [];
  List<String> _params = [];
  bool _ran = false;

  // AI
  final _aiQ = TextEditingController(text: 'Jelaskan temuan ini, dampaknya, dan cara memperbaikinya.');
  bool _aiBusy = false;
  String _aiAnswer = '';

  static const _labels = {
    'xss': 'XSS', 'sqli': 'SQL Injection', 'lfi': 'LFI / Traversal',
    'redirect': 'Open Redirect', 'crlf': 'CRLF', 'headers': 'Header',
  };

  @override
  void dispose() { _url.dispose(); _body.dispose(); _aiQ.dispose(); super.dispose(); }

  void _copy(String v) {
    Clipboard.setData(ClipboardData(text: v));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Disalin.', 'Copied.'))));
  }

  Future<void> _run() async {
    final u = _url.text.trim();
    if (u.isEmpty || !u.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Isi URL target dulu.', 'Enter the target URL first.'))));
      return;
    }
    if (_checks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Pilih minimal satu jenis cek.', 'Pick at least one check.'))));
      return;
    }
    setState(() { _busy = true; _findings = []; _ran = false; _aiAnswer = ''; });
    try {
      final r = await Api.instance.webscanRun(u, method: _method, body: _body.text, checks: _checks.toList());
      if (!mounted) return;
      setState(() {
        _busy = false;
        _ran = true;
        if (r['ok'] == true) {
          _findings = ((r['findings'] as List?) ?? []).cast<Map<String, dynamic>>();
          _params = ((r['params_tested'] as List?) ?? []).map((e) => e.toString()).toList();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r['error'] ?? tr('Gagal', 'Failed')}')));
        }
      });
    } catch (e) {
      if (mounted) setState(() { _busy = false; });
    }
  }

  String _findingsAsText() {
    if (_findings.isEmpty) return tr('Tidak ada temuan.', 'No findings.');
    final b = StringBuffer();
    b.writeln('Target: ${_url.text.trim()} (${_method})');
    b.writeln('Temuan (${_findings.length}):');
    for (final f in _findings) {
      b.writeln('- [${f['severity']}] ${f['type']} | param=${f['param']} | payload=${f['payload']}');
      if ((f['evidence'] ?? '').toString().isNotEmpty) b.writeln('  bukti: ${f['evidence']}');
    }
    return b.toString();
  }

  Future<void> _askAi() async {
    if (!_ran) return;
    setState(() { _aiBusy = true; _aiAnswer = ''; });
    try {
      final msgs = <Map<String, String>>[
        {'role': 'system', 'content': 'Kamu asisten keamanan web. Jawab ringkas dalam Bahasa Indonesia. Jelaskan temuan, dampak, dan langkah perbaikan konkret. Jangan mengarang.'},
        {'role': 'user', 'content': '${_findingsAsText()}\n\nPertanyaan: ${_aiQ.text.trim()}'},
      ];
      final r = await Api.instance.aiAsk(msgs);
      if (!mounted) return;
      setState(() {
        _aiBusy = false;
        _aiAnswer = r['ok'] == true ? (r['answer'] ?? '').toString() : (tr('AI gagal: ', 'AI failed: ') + (r['error'] ?? '').toString());
      });
    } catch (e) {
      if (mounted) setState(() { _aiBusy = false; _aiAnswer = '$e'; });
    }
  }

  Color _sevColor(String s) => switch (s) {
        'tinggi' => YmColors.danger,
        'sedang' => YmColors.warning,
        _ => YmColors.textMuted,
      };
  Color _sevBg(String s) => switch (s) {
        'tinggi' => YmColors.dangerSoft,
        'sedang' => YmColors.warningSoft,
        _ => YmColors.surfaceContainerHigh,
      };

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            crumbs: [tr('Alat', 'Tools'), tr('Cek Kelemahan Web', 'Web Vuln Scan')],
            title: tr('Cek Kelemahan Web', 'Web Vulnerability Scan'),
            subtitle: tr(
                'Pemindai aktif: XSS, SQL Injection, LFI, Open Redirect, CRLF, & header. Hasil bisa ditanyakan ke AI lokalmu. Hanya untuk aplikasi/website milikmu / yang kamu diizinkan uji.',
                'Active scanner: XSS, SQL Injection, LFI, Open Redirect, CRLF, & headers. Ask your local AI about results. Only for apps/sites you own or are authorized to test.'),
          ),
          const SizedBox(height: 14),
          _controls(),
          const SizedBox(height: 16),
          if (_busy)
            HoverCard(padding: const EdgeInsets.all(18), child: Row(children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: YmColors.primary)),
              const SizedBox(width: 12),
              Text(tr('Memindai target…', 'Scanning target…'), style: YmTextStyles.bodySm.copyWith(color: YmColors.outline)),
            ]))
          else if (_ran) ...[
            _resultsCard(),
            const SizedBox(height: 16),
            _aiCard(),
          ],
        ],
      ),
    );
  }

  Widget _controls() {
    final isPost = _method == 'POST' || _method == 'PUT';
    return HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          SizedBox(
            width: 140,
            child: SegmentedToggle<String>(
              value: _method,
              items: const [('GET', 'GET'), ('POST', 'POST')],
              onChanged: (v) => setState(() => _method = v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: TextField(
            controller: _url,
            style: YmTextStyles.mono,
            onSubmitted: (_) => _busy ? null : _run(),
            decoration: InputDecoration(
              labelText: tr('URL target (sertakan parameter)', 'Target URL (include parameters)'),
              hintText: 'https://app-ku.com/cari?q=test&id=1',
              prefixIcon: const Icon(Icons.link_rounded, size: 18),
            ),
          )),
        ]),
        if (isPost) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _body,
            style: YmTextStyles.mono,
            minLines: 1, maxLines: 3,
            decoration: InputDecoration(
              labelText: tr('Body (form: a=1&b=2)', 'Body (form: a=1&b=2)'),
              hintText: 'username=admin&q=test',
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(tr('Jenis cek:', 'Checks:'), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in _labels.keys)
            InkWell(
              onTap: _busy ? null : () => setState(() { _checks.contains(k) ? _checks.remove(k) : _checks.add(k); }),
              borderRadius: BorderRadius.circular(999),
              child: SoftChip(
                _labels[k]!,
                fg: _checks.contains(k) ? YmColors.onPrimaryFixed : YmColors.textMuted,
                bg: _checks.contains(k) ? YmColors.primaryFixed : YmColors.surfaceContainerHigh,
                pill: true, bold: _checks.contains(k),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: _busy ? null : _run,
          icon: const Icon(Icons.bug_report_rounded, size: 18),
          label: Text(tr('Pindai sekarang', 'Scan now')),
        ),
        const SizedBox(height: 8),
        Text(
          tr('Pemindai mengirim payload uji ke target (aktif). Hanya untuk target milikmu / berizin.',
              'The scanner sends test payloads to the target (active). Only for targets you own or are authorized to test.'),
          style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontStyle: FontStyle.italic),
        ),
      ]),
    );
  }

  Widget _resultsCard() {
    return HoverCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.verified_outlined, size: 18, color: YmColors.primary),
          const SizedBox(width: 8),
          Text(tr('Temuan', 'Findings'), style: YmTextStyles.headlineSm),
          const SizedBox(width: 8),
          SoftChip('${_findings.length}', pill: true),
          const Spacer(),
          if (_params.isNotEmpty)
            Flexible(child: Text('${tr('param', 'params')}: ${_params.join(", ")}', maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelSm.copyWith(color: YmColors.outline))),
        ]),
        const SizedBox(height: 10),
        if (_findings.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: YmColors.successContainer.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
            child: Text(tr('Tidak ada temuan dari cek yang dipilih. (Bukan jaminan 100% aman.)', 'No findings from the selected checks. (Not a 100% guarantee.)'),
                style: YmTextStyles.bodySm.copyWith(color: YmColors.onSuccessContainer)),
          )
        else
          ...List.generate(_findings.length, (i) {
            final f = _findings[i];
            final sev = (f['severity'] ?? '').toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: YmColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border(left: BorderSide(color: _sevColor(sev), width: 3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  SoftChip(sev.toUpperCase(), fg: _sevColor(sev), bg: _sevBg(sev), pill: true, bold: true),
                  const SizedBox(width: 8),
                  Expanded(child: Text((f['type'] ?? '').toString(), style: YmTextStyles.labelMd.copyWith(fontWeight: FontWeight.w800))),
                  if ((f['param'] ?? '-') != '-')
                    SoftChip('param: ${f['param']}', icon: Icons.tag_rounded, pill: true),
                ]),
                const SizedBox(height: 6),
                Text((f['detail'] ?? '').toString(), style: YmTextStyles.bodySm.copyWith(color: YmColors.outline)),
                if ((f['payload'] ?? '-') != '-') ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Text('payload: ', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
                    Expanded(child: SelectableText((f['payload'] ?? '').toString(), style: YmTextStyles.mono.copyWith(color: YmColors.danger))),
                    IconButton(tooltip: tr('Salin', 'Copy'), icon: Icon(Icons.copy_rounded, size: 15, color: YmColors.outline), onPressed: () => _copy((f['payload'] ?? '').toString())),
                  ]),
                ],
                if ((f['evidence'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(6)),
                    child: SelectableText((f['evidence'] ?? '').toString(), style: YmTextStyles.mono.copyWith(fontSize: 11)),
                  ),
                ],
              ]),
            );
          }),
      ]),
    );
  }

  Widget _aiCard() {
    return HoverCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 18, color: YmColors.primary),
          const SizedBox(width: 8),
          Text(tr('Tanya AI tentang hasil', 'Ask AI about results'), style: YmTextStyles.headlineSm),
        ]),
        const SizedBox(height: 4),
        Text(tr('Memakai AI lokal yang diatur di Pengaturan > AI (Prakash AI / OpenAI-compatible / Ollama).',
            'Uses the local AI set in Settings > AI (OpenAI-compatible / Ollama).'),
            style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final q in [
            tr('Jelaskan temuan ini, dampaknya, dan cara memperbaikinya.', 'Explain these findings, impact, and how to fix them.'),
            tr('Mana yang paling berbahaya dan harus diperbaiki duluan?', 'Which is most dangerous and should be fixed first?'),
            tr('Tulis contoh perbaikan kode untuk tiap temuan.', 'Write example code fixes for each finding.'),
          ])
            ActionChip(label: Text(q, style: YmTextStyles.labelSm), onPressed: _aiBusy ? null : () { _aiQ.text = q; _askAi(); }),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _aiQ,
          style: YmTextStyles.bodySm,
          minLines: 1, maxLines: 3,
          decoration: InputDecoration(
            labelText: tr('Pertanyaan ke AI', 'Question for AI'),
            suffixIcon: IconButton(
              icon: _aiBusy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
              onPressed: _aiBusy ? null : _askAi,
            ),
          ),
        ),
        if (_aiAnswer.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
            child: SelectableText(_aiAnswer, style: YmTextStyles.bodySm),
          ),
        ],
      ]),
    );
  }
}
