import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';

/// Menu "SMS Masuk" — penerima SMS lewat WEBHOOK dari gateway/provider milikmu.
///
/// Gateway/provider SMS-mu sendiri (nomor Twilio/Vonage, atau app Android SMS
/// Gateway di HP-mu) di-set agar MENERUSKAN setiap SMS masuk ke endpoint:
///     POST http://<server>:8099/api/sms/inbound
/// Isinya ditampung di sini & OTP-nya diekstrak otomatis (pola sama "Penangkap SMTP").
/// BUKAN penyadap seluler — hanya menerima apa yang gatewaymu kirim. Untuk nomor
/// /akun/aplikasi milikmu sendiri saja.
class SmsPage extends StatefulWidget {
  const SmsPage({super.key});
  @override
  State<SmsPage> createState() => _SmsPageState();
}

class _SmsPageState extends State<SmsPage> {
  final _host = TextEditingController(text: Api.instance.baseHost);
  final _filter = TextEditingController();
  final _token = TextEditingController();
  Map<String, dynamic> _status = {'running': true, 'count': 0, 'token_set': false};
  List<Map<String, dynamic>> _list = [];
  Map<String, dynamic>? _open;
  bool _autoCopyOtp = true;
  int _lastTopId = 0;
  Timer? _poll;

  bool get _running => _status['running'] == true;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_running) _refreshList();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _host.dispose();
    _filter.dispose();
    _token.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _copy(String v) {
    Clipboard.setData(ClipboardData(text: v));
    _snack(tr('Disalin.', 'Copied.'));
  }

  String _time(dynamic ts) {
    final n = (ts as num?)?.toInt() ?? 0;
    if (n == 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(n);
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  Future<void> _refreshStatus() async {
    try {
      final s = await Api.instance.smsStatus();
      if (!mounted) return;
      setState(() => _status = s);
      if (_running) _refreshList();
    } catch (_) {}
  }

  Future<void> _refreshList() async {
    try {
      final items = await Api.instance.smsList(to: _filter.text.trim());
      if (!mounted) return;
      if (items.isNotEmpty) {
        final topId = (items.first['id'] as num?)?.toInt() ?? 0;
        if (topId > _lastTopId) {
          final otp = (items.first['otp'] ?? '').toString();
          if (_lastTopId != 0 && _autoCopyOtp && otp.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: otp));
            _snack(tr('SMS baru — OTP $otp disalin.', 'New SMS — OTP $otp copied.'));
          }
          _lastTopId = topId;
        }
      }
      setState(() => _list = items);
    } catch (_) {}
  }

  Future<void> _toggleRunning() async {
    try {
      final s = await Api.instance.smsSetRunning(!_running);
      if (mounted) setState(() => _status = s);
    } catch (_) {}
  }

  Future<void> _saveToken() async {
    try {
      final s = await Api.instance.smsSetToken(_token.text.trim());
      if (mounted) setState(() => _status = s);
      _snack(_token.text.trim().isEmpty
          ? tr('Token dihapus — semua webhook diterima.', 'Token cleared — all webhooks accepted.')
          : tr('Token disimpan — webhook wajib membawa token ini.', 'Token saved — webhooks must carry it.'));
    } catch (_) {}
  }

  Future<void> _clear() async {
    await Api.instance.smsClear();
    if (mounted) setState(() { _list = []; _open = null; _lastTopId = 0; });
  }

  void _openDetail(int id) {
    final items = _list.where((e) => e['id'] == id).toList();
    if (items.isNotEmpty) setState(() => _open = items.first);
  }

  @override
  Widget build(BuildContext context) {
    final url = Api.instance.smsInboundUrl(host: _host.text);
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            crumbs: [tr('Alat', 'Tools'), tr('SMS Masuk', 'Inbound SMS')],
            title: tr('SMS Masuk', 'Inbound SMS'),
            subtitle: tr(
                'Gateway/provider SMS milikmu meneruskan SMS masuk ke endpoint ini, lalu OTP-nya diambil otomatis. Bukan penyadap seluler — hanya nomor/aplikasi milikmu.',
                'Your own SMS gateway/provider forwards inbound SMS here and the OTP is auto-extracted. Not a cellular interceptor — only your own numbers/apps.'),
          ),
          const SizedBox(height: 14),
          _controls(url),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 2, child: _inboxCard()),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: _detailCard()),
          ]),
          const SizedBox(height: 16),
          _howtoNote(),
        ],
      ),
    );
  }

  Widget _controls(String url) {
    final count = _status['count'] ?? _list.length;
    return HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(tr('Penerima SMS (webhook)', 'SMS receiver (webhook)'), style: YmTextStyles.headlineSm)),
          SoftChip(
            _running ? tr('AKTIF • $count', 'LIVE • $count') : tr('MATI', 'OFF'),
            icon: _running ? Icons.circle : Icons.circle_outlined,
            fg: _running ? YmColors.onSuccessSoft : YmColors.textMuted,
            bg: _running ? YmColors.successContainer.withOpacity(0.5) : YmColors.surfaceContainerHigh,
            pill: true, bold: true,
          ),
        ]),
        const SizedBox(height: 12),
        // URL webhook
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          SizedBox(
            width: 220,
            child: TextField(
              controller: _host,
              onChanged: (_) => setState(() {}),
              style: YmTextStyles.mono,
              decoration: InputDecoration(
                labelText: tr('Host/IP server', 'Server host/IP'),
                hintText: tr('IP VPS / domain', 'VPS IP / domain'),
                prefixIcon: const Icon(Icons.dns_outlined, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => _copy(url),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: YmColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: YmColors.line),
                ),
                child: Row(children: [
                  Expanded(child: Text(url, style: YmTextStyles.mono.copyWith(color: YmColors.primary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Icon(Icons.copy_rounded, size: 16, color: YmColors.outline),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        // filter + token
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _filter,
              onChanged: (_) => _refreshList(),
              style: YmTextStyles.mono,
              decoration: InputDecoration(
                labelText: tr('Pantau nomor (opsional)', 'Watch number (optional)'),
                hintText: tr('kosong = semua', 'empty = all'),
                prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _token,
              style: YmTextStyles.mono,
              decoration: InputDecoration(
                labelText: tr('Token rahasia (opsional)', 'Secret token (optional)'),
                hintText: _status['token_set'] == true ? '••••••' : tr('kosong = tanpa token', 'empty = no token'),
                prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: _saveToken, icon: const Icon(Icons.save_outlined, size: 16), label: Text(tr('Simpan', 'Save'))),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (!_running)
            ElevatedButton.icon(onPressed: _toggleRunning, icon: const Icon(Icons.play_arrow_rounded, size: 18), label: Text(tr('Aktifkan terima', 'Enable receiving')))
          else
            ElevatedButton.icon(onPressed: _toggleRunning, style: ElevatedButton.styleFrom(backgroundColor: YmColors.danger), icon: const Icon(Icons.stop_rounded, size: 18), label: Text(tr('Matikan', 'Stop'))),
          OutlinedButton.icon(onPressed: _refreshStatus, icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(tr('Cek', 'Check'))),
          OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new_rounded, size: 16), label: Text(tr('Tes di browser', 'Test in browser'))),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Switch(value: _autoCopyOtp, onChanged: (v) => setState(() => _autoCopyOtp = v)),
          Text(tr('Auto-salin OTP saat SMS baru masuk', 'Auto-copy OTP on new SMS'), style: YmTextStyles.labelMd.copyWith(color: YmColors.textMuted)),
        ]),
      ]),
    );
  }

  Widget _inboxCard() {
    return HoverCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.sms_outlined, color: YmColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(tr('SMS masuk', 'Inbound SMS'), style: YmTextStyles.headlineSm),
          const Spacer(),
          Text('${_list.length}', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
          IconButton(tooltip: tr('Bersihkan', 'Clear'), icon: Icon(Icons.delete_outline_rounded, size: 18, color: YmColors.outline), onPressed: _list.isEmpty ? null : _clear),
        ]),
        const SizedBox(height: 8),
        if (_list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(
              _running ? tr('Menunggu SMS masuk…', 'Waiting for inbound SMS…') : tr('Aktifkan dulu di atas.', 'Enable it above first.'),
              style: YmTextStyles.bodySm.copyWith(color: YmColors.outline))),
          )
        else
          ...List.generate(_list.length, (i) {
            final m = _list[i];
            final otp = (m['otp'] ?? '').toString();
            final sel = _open != null && _open!['id'] == m['id'];
            return InkWell(
              onTap: () => _openDetail(m['id'] as int),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: sel ? YmColors.primary.withOpacity(0.08) : YmColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? YmColors.primary.withOpacity(0.4) : Colors.transparent),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${tr('dari', 'from')}: ${m['from'] ?? '-'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelMd.copyWith(fontWeight: FontWeight.w700))),
                    Text(_time(m['ts']), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
                  ]),
                  const SizedBox(height: 2),
                  Text((m['text'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
                  if (otp.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SoftChip('OTP $otp', icon: Icons.password_rounded, fg: YmColors.onDangerSoft, bg: YmColors.dangerSoft, pill: true, bold: true),
                  ],
                ]),
              ),
            );
          }),
      ]),
    );
  }

  Widget _detailCard() {
    final m = _open;
    if (m == null) {
      return HoverCard(
        padding: const EdgeInsets.all(18),
        child: SizedBox(height: 160, child: Center(child: Text(
          tr('Pilih SMS untuk melihat isinya & OTP-nya.', 'Pick an SMS to see its content & OTP.'),
          style: YmTextStyles.bodySm.copyWith(color: YmColors.outline)))),
      );
    }
    final otp = (m['otp'] ?? '').toString();
    final links = ((m['links'] as List?) ?? []).map((e) => e.toString()).toList();
    final text = (m['text'] ?? '').toString();
    return HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${tr('SMS dari', 'SMS from')} ${m['from'] ?? '-'}', style: YmTextStyles.headlineSm),
        const SizedBox(height: 6),
        Text('${tr('ke', 'to')}: ${m['to'] ?? '-'}', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
        if (otp.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(tr('Kode OTP', 'OTP code'), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
          const SizedBox(height: 4),
          Row(children: [
            SelectableText(otp, style: YmTextStyles.mono.copyWith(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 4, color: YmColors.danger)),
            const SizedBox(width: 10),
            OutlinedButton.icon(onPressed: () => _copy(otp), icon: const Icon(Icons.copy_rounded, size: 15), label: Text(tr('Salin', 'Copy'))),
          ]),
        ],
        if (links.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(tr('Link', 'Links'), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
          const SizedBox(height: 6),
          ...links.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(child: SelectableText(u, style: YmTextStyles.mono.copyWith(color: YmColors.primary), maxLines: 2)),
                  const SizedBox(width: 6),
                  IconButton(tooltip: tr('Salin', 'Copy'), icon: Icon(Icons.copy_rounded, size: 15, color: YmColors.outline), onPressed: () => _copy(u)),
                  ElevatedButton.icon(onPressed: () => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new_rounded, size: 15), label: Text(tr('Buka', 'Open'))),
                ]),
              )),
        ],
        if (text.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(tr('Isi SMS', 'SMS body'), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
            child: SelectableText(text, style: YmTextStyles.bodySm),
          ),
        ],
      ]),
    );
  }

  Widget _howtoNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: YmColors.warningSoft.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, size: 18, color: YmColors.onWarningSoft),
        const SizedBox(width: 10),
        Expanded(child: Text(
          tr('Set "inbound/forward webhook" di gateway/providermu ke URL di atas. Format body yang didukung: generic {from,to,text}, Twilio {From,To,Body}, Vonage {msisdn,to,text}, atau app Android SMS-gateway. Di VPS: buka port 8099 & isi Host/IP dengan IP publik server. Hanya untuk nomor/aplikasi milikmu.',
              'Set the "inbound/forward webhook" in your gateway/provider to the URL above. Supported body formats: generic {from,to,text}, Twilio {From,To,Body}, Vonage {msisdn,to,text}, or Android SMS-gateway apps. On a VPS: open port 8099 and set Host/IP to the server public IP. Only for your own numbers/apps.'),
          style: YmTextStyles.labelSm.copyWith(color: YmColors.onWarningSoft))),
      ]),
    );
  }
}
