import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';

class UsbPage extends StatefulWidget {
  const UsbPage({super.key});
  @override
  State<UsbPage> createState() => _UsbPageState();
}

class _UsbPageState extends State<UsbPage> {
  final _adbPath = TextEditingController();
  String _resolved = '';
  List<Map<String, dynamic>> _devices = [];
  String? _serial;
  String _msg = '';
  bool _loading = false;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = await Api.instance.adbConfigGet();
      _adbPath.text = (c['path'] ?? '').toString();
      _resolved = (c['resolved'] ?? '').toString();
    } catch (_) {}
    await _refresh();
  }

  Future<void> _savePath() async {
    final c = await Api.instance.adbConfigPut(_adbPath.text.trim());
    setState(() => _resolved = (c['resolved'] ?? '').toString());
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final r = await Api.instance.adbDevices();
      _devices = ((r['devices'] as List?) ?? []).cast<Map<String, dynamic>>();
      if (_serial == null && _devices.isNotEmpty) _serial = _devices.first['serial'] as String?;
      if (r['ok'] != true) _msg = (r['raw'] ?? '').toString();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _enable() async {
    final port = Api.instance.status['port'] as int? ?? 8080;
    setState(() => _loading = true);
    final r = await Api.instance.adbEnable(_serial ?? '', port);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _active = r['ok'] == true;
      _msg = r['ok'] == true
          ? tr('USB aktif. Proxy HP diarahkan ke 127.0.0.1:$port lewat kabel.', 'USB active. Phone proxy pointed to 127.0.0.1:$port over cable.')
          : tr('Gagal mengaktifkan. Cek USB debugging & otorisasi.', 'Failed to enable. Check USB debugging & authorization.');
    });
  }

  Future<void> _disable() async {
    setState(() => _loading = true);
    await Api.instance.adbDisable(_serial ?? '');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _active = false;
      _msg = tr('USB dimatikan, proxy HP dibersihkan.', 'USB disabled, phone proxy cleared.');
    });
  }

  Future<void> _pushCert() async {
    setState(() => _loading = true);
    final r = await Api.instance.adbPushCert(_serial ?? '');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _msg = r['ok'] == true
          ? tr('Sertifikat terkirim ke HP (folder Download). Pasang: Settings > Security > Install from storage.',
              'Certificate sent to phone (Download folder). Install: Settings > Security > Install from storage.')
          : '${tr('Gagal kirim sertifikat', 'Failed to send certificate')}: ${r['out'] ?? r['error']}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasAdb = _resolved.isNotEmpty;
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            crumbs: [tr('Lalu lintas', 'Traffic'), 'USB (ADB)'],
            title: tr('Debug lewat kabel (USB)', 'Debug over cable (USB)'),
            subtitle: tr('Lebih stabil dari Wi-Fi: trafik HP lewat kabel ke proxy PC (adb reverse). Tak perlu satu Wi-Fi. Hanya untuk perangkatmu.',
                'More stable than Wi-Fi: phone traffic goes over the cable to the PC proxy (adb reverse). No shared Wi-Fi needed. For your own device only.'),
            actions: [
              OutlinedButton.icon(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(tr('Segarkan', 'Refresh'))),
            ],
          ),
          const SizedBox(height: 20),
          // path adb
          HoverCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.terminal_rounded, color: YmColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('ADB', style: YmTextStyles.headlineSm),
                const Spacer(),
                SoftChip(
                  hasAdb ? tr('terdeteksi', 'detected') : tr('tak ditemukan', 'not found'),
                  fg: hasAdb ? YmColors.onSuccessSoft : YmColors.onDangerSoft,
                  bg: hasAdb ? YmColors.successContainer.withOpacity(0.4) : YmColors.dangerSoft,
                  pill: true, bold: true,
                ),
              ]),
              const SizedBox(height: 6),
              if (hasAdb) Text(_resolved, style: YmTextStyles.labelSm) else Text(tr('Pasang Android platform-tools, lalu isi path adb.exe di bawah.', 'Install Android platform-tools, then set the adb.exe path below.'), style: YmTextStyles.bodySm),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _adbPath, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('Path adb (kosong = cari otomatis)', 'adb path (empty = auto-detect)'), hintText: r'...\platform-tools\adb.exe'))),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _savePath, child: Text(tr('Simpan', 'Save'))),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          // perangkat
          HoverCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Perangkat terhubung', 'Connected devices'), style: YmTextStyles.headlineSm),
              const SizedBox(height: 10),
              if (_devices.isEmpty)
                Text(tr('Tidak ada perangkat. Colok HP, aktifkan USB debugging, dan setujui otorisasi di HP.',
                    'No devices. Plug in the phone, enable USB debugging, and approve the authorization on the phone.'), style: YmTextStyles.bodySm)
              else
                Column(children: [
                  for (final d in _devices)
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: d['serial'] as String,
                      groupValue: _serial,
                      onChanged: (v) => setState(() => _serial = v),
                      title: Text('${d['model']?.toString().isNotEmpty == true ? d['model'] : d['serial']}', style: YmTextStyles.labelMd),
                      subtitle: Text('${d['serial']} • ${d['state']}', style: YmTextStyles.labelSm),
                    ),
                ]),
            ]),
          ),
          const SizedBox(height: 16),
          // aksi
          HoverCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Langkah', 'Steps'), style: YmTextStyles.headlineSm),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (!_active)
                  ElevatedButton.icon(onPressed: _loading || _devices.isEmpty ? null : _enable, icon: const Icon(Icons.usb_rounded, size: 18), label: Text(tr('Aktifkan USB (reverse + proxy)', 'Enable USB (reverse + proxy)')))
                else
                  OutlinedButton.icon(onPressed: _loading ? null : _disable, icon: const Icon(Icons.usb_off_rounded, size: 18), label: Text(tr('Matikan USB', 'Disable USB'))),
                OutlinedButton.icon(onPressed: _loading || _devices.isEmpty ? null : _pushCert, icon: const Icon(Icons.verified_user_outlined, size: 18), label: Text(tr('Kirim sertifikat ke HP', 'Send certificate to phone'))),
              ]),
              if (_loading) ...[const SizedBox(height: 12), Row(children: [SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: YmColors.primary)), const SizedBox(width: 10), Text(tr('Memproses…', 'Working…'), style: YmTextStyles.bodySm)])],
              if (_msg.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                  child: Text(_msg, style: YmTextStyles.bodySm),
                ),
              ],
              const SizedBox(height: 14),
              Text(tr('Catatan: app yang mengabaikan proxy sistem (banyak Flutter) tetap tak tertangkap — itu butuh VPN/reFlutter, bukan sekadar USB.',
                  'Note: apps that ignore the system proxy (many Flutter apps) still aren\'t captured — that needs VPN/reFlutter, not just USB.'),
                  style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
            ]),
          ),
        ],
      ),
    );
  }
}
