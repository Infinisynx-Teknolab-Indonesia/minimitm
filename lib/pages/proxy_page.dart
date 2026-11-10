import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';

class ProxyPage extends StatefulWidget {
  const ProxyPage({super.key});
  @override
  State<ProxyPage> createState() => _ProxyPageState();
}

class _ProxyPageState extends State<ProxyPage> {
  final _portC = TextEditingController(text: '8080');
  bool _allIfaces = true;
  bool _loaded = false;
  List<String> _ips = [];
  String _fwMsg = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cfg = await Api.instance.getConfig();
      _portC.text = '${cfg['listen_port'] ?? 8080}';
      _allIfaces = (cfg['listen_host'] ?? '0.0.0.0') == '0.0.0.0';
      final ni = await Api.instance.netInfo();
      _ips = ((ni['ips'] as List?) ?? []).cast<String>();
    } catch (_) {}
    setState(() => _loaded = true);
  }

  Future<void> _openFirewall() async {
    setState(() => _fwMsg = tr('Membuka firewall…', 'Opening firewall…'));
    final r = await Api.instance.firewallOpen(int.tryParse(_portC.text) ?? 8080);
    if (!mounted) return;
    setState(() => _fwMsg = r['ok'] == true
        ? tr('Firewall dibuka untuk port ini.', 'Firewall opened for this port.')
        : '${tr('Perlu Administrator. Jalankan perintah ini di CMD (admin):', 'Needs Administrator. Run this in CMD (admin):')}\n${r['command']}');
  }

  Future<void> _apply() async {
    await Api.instance.putConfig({
      'listen_host': _allIfaces ? '0.0.0.0' : '127.0.0.1',
      'listen_port': int.tryParse(_portC.text) ?? 8080,
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Pengaturan proxy disimpan.', 'Proxy settings saved.'))));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return AnimatedBuilder(
      animation: Api.instance,
      builder: (context, _) {
        final api = Api.instance;
        final host = _allIfaces ? '0.0.0.0' : '127.0.0.1';
        return PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                crumbs: ['Mini MITM', tr('Proxy', 'Proxy')],
                title: tr('Proxy', 'Proxy'),
                subtitle: tr('Nyalakan proxy, lalu arahkan proxy perangkat/aplikasimu ke alamat ini.',
                    'Start the proxy, then point your device/app proxy to this address.'),
                actions: [
                  if (!api.proxyRunning)
                    ElevatedButton.icon(onPressed: api.start, icon: const Icon(Icons.play_arrow_rounded, size: 18), label: Text(tr('Mulai proxy', 'Start proxy')))
                  else
                    OutlinedButton.icon(onPressed: api.stop, icon: const Icon(Icons.stop_rounded, size: 18), label: Text(tr('Hentikan proxy', 'Stop proxy'))),
                ],
              ),
              const SizedBox(height: 24),
              _mobileCard(api),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, c) {
                final two = c.maxWidth > 900;
                final w = two ? (c.maxWidth - 16) / 2 : c.maxWidth;
                return Wrap(spacing: 16, runSpacing: 16, children: [
                  SizedBox(width: w, child: _listenCard(api, host)),
                  SizedBox(width: w, child: _certCard(api)),
                ]);
              }),
              const SizedBox(height: 16),
              _interceptCard(api),
              const SizedBox(height: 12),
              _invisibleCard(api),
            ],
          ),
        );
      },
    );
  }

  Widget _mobileCard(Api api) {
    final ip = _ips.isNotEmpty ? _ips.first : tr('IP-PC-tidak-terdeteksi', 'PC-IP-not-detected');
    final addr = '$ip:${_portC.text}';
    return HoverCard(
      padding: const EdgeInsets.all(20),
      color: YmColors.primarySoft.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.smartphone_rounded, color: YmColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(tr('Hubungkan HP (Android / iOS)', 'Connect your phone (Android / iOS)'), style: YmTextStyles.headlineSm),
          ]),
          const SizedBox(height: 12),
          Text(tr('Di HP: Setelan Wi-Fi → proxy Manual → isi:', 'On phone: Wi-Fi settings → Manual proxy → set:'), style: YmTextStyles.labelSm),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: YmColors.line)),
            child: Row(children: [
              Expanded(child: SelectableText(addr, style: TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w700, color: YmColors.primary))),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 18, color: YmColors.outline),
                onPressed: () { Clipboard.setData(ClipboardData(text: addr)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Disalin.', 'Copied.')))); },
              ),
            ]),
          ),
          if (_ips.length > 1) ...[
            const SizedBox(height: 6),
            Text('${tr('IP lain', 'Other IPs')}: ${_ips.skip(1).join(", ")}', style: YmTextStyles.labelSm),
          ],
          const SizedBox(height: 12),
          if (!_allIfaces)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: YmColors.warningSoft, borderRadius: BorderRadius.circular(8)),
              child: Text(tr('⚠ "Terima dari semua perangkat" mati → HP tidak bisa konek. Nyalakan di bawah.',
                  '⚠ "Accept from all devices" is off → phone can\'t connect. Turn it on below.'), style: YmTextStyles.labelSm.copyWith(color: YmColors.onWarningSoft)),
            ),
          Row(children: [
            OutlinedButton.icon(onPressed: _openFirewall, icon: const Icon(Icons.shield_outlined, size: 18), label: Text(tr('Buka Windows Firewall', 'Open Windows Firewall'))),
            const SizedBox(width: 8),
            Expanded(child: Text(tr('HP tidak konek? Firewall PC biasanya memblokir. Klik ini (butuh admin).',
                'Phone won\'t connect? The PC firewall usually blocks it. Click this (needs admin).'), style: YmTextStyles.labelSm)),
          ]),
          if (_fwMsg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(8)), child: SelectableText(_fwMsg, style: YmTextStyles.mono)),
          ],
          const SizedBox(height: 12),
          Text(tr('iOS: setelah pasang sertifikat, aktifkan "trust" penuh di Settings → General → About → Certificate Trust Settings.',
              'iOS: after installing the certificate, enable full trust in Settings → General → About → Certificate Trust Settings.'), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
        ],
      ),
    );
  }

  Widget _listenCard(Api api, String host) {
    return HoverCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.lan_outlined, color: YmColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(tr('Alamat proxy', 'Proxy address'), style: YmTextStyles.headlineSm),
            const Spacer(),
            StatusPill(running: api.proxyRunning, text: api.proxyRunning ? 'ON' : 'OFF'),
          ]),
          const SizedBox(height: 16),
          Text('Port', style: YmTextStyles.labelSm),
          const SizedBox(height: 6),
          SizedBox(width: 160, child: TextField(controller: _portC, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '8080'))),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _allIfaces,
            onChanged: (v) => setState(() => _allIfaces = v),
            title: Text(tr('Terima dari semua perangkat di jaringan (0.0.0.0)', 'Accept from all devices on the network (0.0.0.0)'), style: YmTextStyles.labelMd),
            subtitle: Text(tr('Nyalakan kalau mau intip HP di Wi-Fi yang sama.', 'Turn on to inspect a phone on the same Wi-Fi.'), style: YmTextStyles.bodySm),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 16, color: YmColors.outline),
              const SizedBox(width: 8),
              Expanded(child: SelectableText('${tr('Atur proxy manual di perangkat ke', 'Set device manual proxy to')}:  $host : ${_portC.text}', style: YmTextStyles.mono)),
            ]),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(onPressed: _apply, icon: const Icon(Icons.save_outlined, size: 18), label: Text(tr('Simpan alamat', 'Save address'))),
        ],
      ),
    );
  }

  Widget _certCard(Api api) {
    return HoverCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.verified_user_outlined, color: YmColors.success, size: 20),
            const SizedBox(width: 8),
            Text(tr('Sertifikat CA', 'CA certificate'), style: YmTextStyles.headlineSm),
          ]),
          const SizedBox(height: 12),
          Text(tr('Agar HTTPS bisa dibaca, pasang sertifikat CA sekali di perangkat yang mau diintip. Hanya untuk perangkatmu sendiri.',
              'To read HTTPS, install the CA certificate once on the device you want to inspect. Only for your own device.'),
              style: YmTextStyles.bodySm),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(api.caPemUrl()), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(tr('Unduh .pem', 'Download .pem')),
            ),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(api.caCrtUrl()), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(tr('Unduh .crt (Android/Windows)', 'Download .crt (Android/Windows)')),
            ),
          ]),
          const SizedBox(height: 12),
          Text(tr('Dari HP, buka alamat ini di browser untuk mengunduh sertifikat:', 'On a phone, open this address in a browser to download the certificate:'), style: YmTextStyles.labelSm),
          const SizedBox(height: 6),
          _copyRow('http://${_lanHint()}:${Api.instance.basePort}/api/ca.crt'),
        ],
      ),
    );
  }

  String _lanHint() => Api.instance.baseHost == '127.0.0.1' ? tr('IP-PC-kamu', 'YOUR-PC-IP') : Api.instance.baseHost;

  Widget _copyRow(String text) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(child: SelectableText(text, style: YmTextStyles.mono)),
        IconButton(
          icon: Icon(Icons.copy_rounded, size: 16, color: YmColors.outline),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Disalin.', 'Copied.'))));
          },
        ),
      ]),
    );
  }

  Widget _interceptCard(Api api) {
    return HoverCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: YmColors.warningSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.pan_tool_outlined, color: YmColors.onWarningSoft, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Mode intercept', 'Intercept mode'), style: YmTextStyles.headlineSm),
              const SizedBox(height: 2),
              Text(tr('Tahan setiap request untuk diperiksa/diubah sebelum diteruskan (halaman Intercept).', 'Hold each request to inspect/edit before forwarding (Intercept page).'), style: YmTextStyles.bodySm),
            ]),
          ),
          Switch(
            value: api.intercepting,
            onChanged: (v) => api.putConfig({'intercept': v}),
          ),
        ],
      ),
    );
  }

  Widget _invisibleCard(Api api) {
    final on = api.status['invisible'] == true;
    return HoverCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: YmColors.primarySoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.visibility_off_outlined, color: YmColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Transparent proxy (invisible)', 'Transparent proxy (invisible)'), style: YmTextStyles.headlineSm),
              const SizedBox(height: 2),
              Text(tr('Terima trafik walau klien tak menyetel proxy (lewat redirect/VPN/tun2socks). Host HTTPS dibaca dari SNI.', 'Accept traffic even if the client sets no proxy (via redirect/VPN/tun2socks). HTTPS host is read from SNI.'), style: YmTextStyles.bodySm),
            ]),
          ),
          Switch(value: on, onChanged: (v) => api.putConfig({'invisible': v})),
        ],
      ),
    );
  }
}
