import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';

class TotpPage extends StatefulWidget {
  const TotpPage({super.key});
  @override
  State<TotpPage> createState() => _TotpPageState();
}

class _TotpPageState extends State<TotpPage> {
  Map<String, dynamic> _presets = {};
  List<Map<String, dynamic>> _accounts = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _presets = await Api.instance.totpPresets();
    } catch (_) {}
    await _refresh();
  }

  Future<void> _refresh() async {
    try {
      final a = await Api.instance.totpAccounts();
      if (mounted) setState(() => _accounts = a);
    } catch (_) {}
  }

  Future<void> _delete(String id, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Hapus akun?', 'Delete account?')),
        content: Text(tr('Hapus "$label" dari daftar TOTP? Secret-nya akan dibuang.', 'Remove "$label" from the TOTP list? Its secret will be discarded.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Batal', 'Cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: YmColors.danger),
            child: Text(tr('Hapus', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final a = await Api.instance.totpDeleteAccount(id);
    if (mounted) {
      setState(() => _accounts = a);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Akun dihapus.', 'Account deleted.'))));
    }
  }

  void _addDialog() {
    final label = TextEditingController();
    final secret = TextEditingController();
    final nonce = TextEditingController();
    String preset = _presets.containsKey('PingOne TOTP') ? 'PingOne TOTP' : (_presets.keys.isNotEmpty ? _presets.keys.first : 'PingOne TOTP');
    String mode = 'secret'; // secret | nonce
    String err = '';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(tr('Tambah akun TOTP', 'Add TOTP account')),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: label, decoration: InputDecoration(labelText: tr('Nama akun', 'Account name'), hintText: tr('mis. PingOne Kerja', 'e.g. PingOne Work'))),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _presets.containsKey(preset) ? preset : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: tr('Preset', 'Preset')),
                  items: [for (final k in _presets.keys) DropdownMenuItem(value: k, child: Text(k))],
                  onChanged: (v) => preset = v ?? preset,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedToggle<String>(
                    value: mode,
                    items: [('secret', tr('Secret Base32', 'Base32 secret')), ('nonce', tr('Dari Nonce (PingOne)', 'From Nonce (PingOne)'))],
                    onChanged: (v) => setLocal(() => mode = v),
                  ),
                ),
                const SizedBox(height: 10),
                if (mode == 'secret')
                  TextField(controller: secret, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('Secret (Base32)', 'Secret (Base32)'), hintText: 'JBSWY3DPEHPK3PXP'))
                else ...[
                  TextField(controller: nonce, maxLines: 3, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('Nonce (dari JWT PingOne)', 'Nonce (from PingOne JWT)'), hintText: 'beb0cdd4...')),
                  const SizedBox(height: 4),
                  Text(tr('128 hex pertama dipakai jadi secret Base32, lalu dibuat TOTP.', 'First 128 hex become a Base32 secret, then TOTP.'), style: YmTextStyles.labelSm),
                ],
                if (err.isNotEmpty) ...[const SizedBox(height: 8), Text(err, style: YmTextStyles.bodySm.copyWith(color: YmColors.danger))],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Batal', 'Cancel'))),
            ElevatedButton(
              onPressed: () async {
                final r = mode == 'nonce'
                    ? await Api.instance.totpAddAccount(label.text.trim(), '', preset, nonce: nonce.text.trim())
                    : await Api.instance.totpAddAccount(label.text.trim(), secret.text.trim(), preset);
                if (r['ok'] == false) {
                  setLocal(() => err = (r['error'] ?? 'error').toString());
                  return;
                }
                if (mounted) setState(() => _accounts = ((r['accounts'] as List?) ?? []).cast<Map<String, dynamic>>());
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(tr('Simpan', 'Save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            crumbs: [tr('Alat', 'Tools'), 'TOTP'],
            title: 'TOTP / OTP',
            subtitle: tr('Simpan banyak akun 2FA (Google Authenticator, Okta, PingOne, dll) dan lihat kodenya live. Hanya untuk akun milikmu.',
                'Store many 2FA accounts (Google Authenticator, Okta, PingOne, etc) and see codes live. Only for your own accounts.'),
            actions: [
              ElevatedButton.icon(onPressed: _addDialog, icon: const Icon(Icons.add_rounded, size: 18), label: Text(tr('Tambah akun', 'Add account'))),
            ],
          ),
          const SizedBox(height: 20),
          if (_accounts.isEmpty)
            HoverCard(child: SizedBox(height: 220, child: EmptyState(
              icon: Icons.timer_outlined,
              title: tr('Belum ada akun', 'No accounts yet'),
              message: tr('Tekan "Tambah akun" lalu masukkan secret Base32 dari akunmu.', 'Press "Add account" and enter your account\'s Base32 secret.'),
              action: ElevatedButton(onPressed: _addDialog, child: Text(tr('Tambah akun', 'Add account'))),
            )))
          else
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth > 1100 ? 3 : (c.maxWidth > 720 ? 2 : 1);
              final w = (c.maxWidth - (cols - 1) * 16) / cols;
              return Wrap(spacing: 16, runSpacing: 16, children: [
                for (final a in _accounts) SizedBox(width: w, child: _card(a)),
              ]);
            }),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> a) {
    final period = (a['period'] ?? 30) as int;
    final rem = (a['remaining'] ?? 30) as int;
    final code = (a['code'] ?? '------').toString();
    final frac = period == 0 ? 0.0 : rem / period;
    final spaced = code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;
    return HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(a['label'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.headlineSm)),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, size: 18, color: YmColors.danger),
              tooltip: tr('Hapus', 'Delete'),
              onPressed: () => _delete(a['id'].toString(), a['label'] as String? ?? ''),
            ),
          ]),
          Text('${a['preset'] ?? ''}', style: YmTextStyles.labelSm),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text(spaced, style: TextStyle(fontFamily: kFontDisplay, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 2, color: YmColors.primary)),
            ),
            IconButton(
              icon: Icon(Icons.copy_rounded, size: 18, color: YmColors.outline),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code.replaceAll(' ', '')));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Kode disalin.', 'Code copied.'))));
              },
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: frac, minHeight: 5, backgroundColor: YmColors.surfaceAlt, color: rem <= 5 ? YmColors.danger : YmColors.primary),
          ),
          const SizedBox(height: 4),
          Text('${tr('Berganti dalam', 'Changes in')} $rem ${tr('detik', 'sec')}', style: YmTextStyles.labelSm),
        ],
      ),
    );
  }
}
