import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';

class JwtPage extends StatefulWidget {
  const JwtPage({super.key});
  @override
  State<JwtPage> createState() => _JwtPageState();
}

class _JwtPageState extends State<JwtPage> {
  final _token = TextEditingController();
  final _header = TextEditingController(text: '{\n  "alg": "HS256",\n  "typ": "JWT"\n}');
  final _payload = TextEditingController(text: '{\n  "sub": "1"\n}');
  final _secret = TextEditingController();
  String _alg = 'HS256';
  String _msg = '';
  List<Map<String, dynamic>> _attackFindings = [];
  bool _attacking = false;

  Future<void> _attack() async {
    final t = _token.text.trim();
    if (t.isEmpty) {
      setState(() => _msg = tr('Isi token dulu.', 'Enter a token first.'));
      return;
    }
    setState(() {
      _attacking = true;
      _attackFindings = [];
    });
    final r = await Api.instance.jwtAttack(t, const []);
    if (!mounted) return;
    setState(() {
      _attacking = false;
      if (r['ok'] == true) {
        _attackFindings = ((r['findings'] as List?) ?? []).cast<Map<String, dynamic>>();
        _msg = '${tr('Serangan selesai', 'Attack done')}: ${_attackFindings.length} ${tr('temuan', 'findings')}';
      } else {
        _msg = '${tr('Gagal', 'Failed')}: ${r['error']}';
      }
    });
  }

  Future<void> _decode() async {
    final r = await Api.instance.jwtDecode(_token.text.trim());
    if (r['ok'] == true) {
      setState(() {
        _header.text = const JsonEncoder.withIndent('  ').convert(r['header']);
        _payload.text = const JsonEncoder.withIndent('  ').convert(r['payload']);
        _alg = (r['header']['alg'] ?? 'HS256').toString();
        _msg = '${tr('Terdekode. Signature', 'Decoded. Signature')}: ${(r['signature'] as String).isEmpty ? tr('(kosong)', '(empty)') : r['signature']}';
      });
    } else {
      setState(() => _msg = '${tr('Gagal decode', 'Decode failed')}: ${r['error']}');
    }
  }

  Future<void> _encode() async {
    Map<String, dynamic> h, p;
    try {
      h = jsonDecode(_header.text) as Map<String, dynamic>;
      p = jsonDecode(_payload.text) as Map<String, dynamic>;
    } catch (e) {
      setState(() => _msg = '${tr('JSON header/payload tidak valid', 'Invalid header/payload JSON')}: $e');
      return;
    }
    final r = await Api.instance.jwtEncode(h, p, _alg, _secret.text);
    if (r['ok'] == true) {
      setState(() {
        _token.text = r['token'] as String;
        _msg = '${tr('Token baru dibuat', 'New token created')} (alg=$_alg).';
      });
    } else {
      setState(() => _msg = '${tr('Gagal encode', 'Encode failed')}: ${r['error']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(crumbs: [tr('Alat', 'Tools'), 'JWT'], title: 'JWT Editor', subtitle: tr('Decode JSON Web Token, ubah header/payload, lalu tanda tangani ulang (none / HS256). Untuk token milikmu.', 'Decode a JSON Web Token, edit header/payload, then re-sign (none / HS256). For your own tokens.')),
          const SizedBox(height: 16),
          _field('Token', _token, mono: true, maxLines: 3, suffix: IconButton(
            icon: Icon(Icons.copy_rounded, size: 16, color: YmColors.outline),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _token.text));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Disalin.', 'Copied.'))));
            },
          )),
          const SizedBox(height: 8),
          Row(children: [
            ElevatedButton.icon(onPressed: _decode, icon: const Icon(Icons.lock_open_rounded, size: 18), label: const Text('Decode')),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _attacking ? null : _attack,
              style: OutlinedButton.styleFrom(foregroundColor: YmColors.danger),
              icon: _attacking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.bolt_rounded, size: 18),
              label: Text(tr('Serang (attack)', 'Attack')),
            ),
            const SizedBox(width: 16),
            if (_msg.isNotEmpty) Expanded(child: Text(_msg, style: YmTextStyles.bodySm.copyWith(color: YmColors.primary))),
          ]),
          if (_attackFindings.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final f in _attackFindings) _attackCard(f),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _field('Header (JSON)', _header, mono: true, maxLines: 7)),
              const SizedBox(width: 12),
              Expanded(child: _field('Payload (JSON)', _payload, mono: true, maxLines: 7)),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            Text(tr('Algoritma', 'Algorithm'), style: YmTextStyles.labelSm),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _alg,
              items: const [DropdownMenuItem(value: 'HS256', child: Text('HS256')), DropdownMenuItem(value: 'none', child: Text('none'))],
              onChanged: (v) => setState(() => _alg = v ?? 'HS256'),
            ),
            const SizedBox(width: 16),
            if (_alg == 'HS256')
              Expanded(child: _field('Secret (HMAC)', _secret, mono: false)),
          ]),
          const SizedBox(height: 12),
          ElevatedButton.icon(onPressed: _encode, icon: const Icon(Icons.edit_rounded, size: 18), label: Text(tr('Sign / buat token baru', 'Sign / create new token'))),
        ],
      ),
    );
  }

  Widget _attackCard(Map<String, dynamic> f) {
    final sev = (f['severity'] ?? 'info').toString();
    final (Color c, String label) = switch (sev) {
      'high' => (YmColors.danger, 'HIGH'),
      'medium' => (YmColors.warning, 'MEDIUM'),
      _ => (YmColors.textMuted, 'INFO'),
    };
    final token = (f['token'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: YmColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: c.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
              child: Text(label, style: YmTextStyles.labelSm.copyWith(color: c, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(f['title'] as String? ?? '', style: YmTextStyles.labelLg.copyWith(fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 6),
          Text(f['detail'] as String? ?? '', style: YmTextStyles.bodySm),
          if (token.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
              decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Expanded(child: SelectableText(token, style: YmTextStyles.mono, maxLines: 2)),
                IconButton(
                  icon: Icon(Icons.copy_rounded, size: 15, color: YmColors.outline),
                  tooltip: tr('Salin token palsu', 'Copy forged token'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: token));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Token disalin.', 'Token copied.'))));
                  },
                ),
                IconButton(
                  icon: Icon(Icons.input_rounded, size: 15, color: YmColors.outline),
                  tooltip: tr('Pakai di editor', 'Load into editor'),
                  onPressed: () => setState(() => _token.text = token),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {bool mono = false, int maxLines = 1, Widget? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: YmTextStyles.labelSm),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          maxLines: maxLines,
          style: mono ? YmTextStyles.mono : null,
          decoration: InputDecoration(suffixIcon: suffix),
        ),
      ],
    );
  }
}
