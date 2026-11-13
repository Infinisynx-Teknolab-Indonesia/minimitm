import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';

/// Menu "SpiderFoot" — pasang & jalankan SpiderFoot (OSINT) via Docker, lokal
/// (Docker Desktop) atau remote (SSH ke VPS/VirtualBox milikmu). UI SpiderFoot
/// ada di port 5001. Untuk aset/penggunaan milikmu.
class SpiderFootPage extends StatefulWidget {
  const SpiderFootPage({super.key});
  @override
  State<SpiderFootPage> createState() => _SpiderFootPageState();
}

class _SpiderFootPageState extends State<SpiderFootPage> {
  int _mode = 0; // 0 = lokal, 1 = remote (SSH)
  final _image = TextEditingController(text: 'smicallef/spiderfoot:latest');
  final _port = TextEditingController(text: '5001');
  final _host = TextEditingController();
  final _sshPort = TextEditingController(text: '22');
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _key = TextEditingController();
  bool _showPass = false;

  bool _busy = false;
  String _log = '';
  bool? _running;
  String _url = '';

  @override
  void dispose() {
    _image.dispose(); _port.dispose(); _host.dispose(); _sshPort.dispose();
    _user.dispose(); _pass.dispose(); _key.dispose();
    super.dispose();
  }

  Map<String, dynamic> _cfg() => {
        'mode': _mode == 1 ? 'remote' : 'local',
        'image': _image.text.trim(),
        'port': int.tryParse(_port.text.trim()) ?? 5001,
        'host': _host.text.trim(),
        'ssh_port': int.tryParse(_sshPort.text.trim()) ?? 22,
        'user': _user.text.trim(),
        'password': _pass.text,
        'key_path': _key.text.trim(),
      };

  String get _openUrl {
    final port = int.tryParse(_port.text.trim()) ?? 5001;
    if (_mode == 1 && _host.text.trim().isNotEmpty) return 'http://${_host.text.trim()}:$port';
    return 'http://localhost:$port';
  }

  Future<void> _do(String action) async {
    if (_mode == 1 && (action == 'install' || action == 'status' || action == 'stop')) {
      if (_host.text.trim().isEmpty || _user.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Isi IP host & user SSH dulu.', 'Enter host IP & SSH user first.'))));
        return;
      }
    }
    setState(() { _busy = true; if (action == 'install') _log = ''; });
    try {
      final r = await Api.instance.sfCall(action, _cfg());
      if (!mounted) return;
      setState(() {
        _busy = false;
        if ((r['log'] ?? '').toString().isNotEmpty) _log = r['log'].toString();
        if (r.containsKey('running')) _running = r['running'] == true;
        if ((r['url'] ?? '').toString().isNotEmpty) _url = r['url'].toString();
        if (action == 'status' && r['docker'] == false) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Docker tidak terdeteksi. Buka Docker Desktop dulu.', 'Docker not detected. Open Docker Desktop first.'))));
        }
      });
    } catch (e) {
      if (mounted) setState(() { _busy = false; _log = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            crumbs: [tr('Alat', 'Tools'), 'SpiderFoot'],
            title: 'SpiderFoot',
            subtitle: tr(
                'Pasang & jalankan SpiderFoot (OSINT) via Docker — lokal (Docker Desktop) atau remote SSH ke VPS/VirtualBox milikmu. UI terbuka di browser (port 5001).',
                'Install & run SpiderFoot (OSINT) via Docker — local (Docker Desktop) or remote SSH to your own VPS/VirtualBox. UI opens in the browser (port 5001).'),
          ),
          const SizedBox(height: 14),
          _modeSwitch(),
          const SizedBox(height: 14),
          _controls(),
          const SizedBox(height: 16),
          if (_log.isNotEmpty) _logCard(),
        ],
      ),
    );
  }

  Widget _modeSwitch() {
    Widget seg(int i, IconData ic, String label) {
      final on = _mode == i;
      return InkWell(
        onTap: _busy ? null : () => setState(() => _mode = i),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: on ? YmColors.primary : YmColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, size: 17, color: on ? Colors.white : YmColors.textMuted),
            const SizedBox(width: 8),
            Text(label, style: YmTextStyles.labelMd.copyWith(color: on ? Colors.white : YmColors.textMuted, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }
    return Row(children: [
      seg(0, Icons.computer_rounded, tr('Lokal (Docker Desktop)', 'Local (Docker Desktop)')),
      const SizedBox(width: 8),
      seg(1, Icons.dns_rounded, tr('Remote (SSH)', 'Remote (SSH)')),
    ]);
  }

  Widget _controls() {
    return HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: TextField(controller: _image, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('Docker image', 'Docker image'), hintText: 'smicallef/spiderfoot:latest'))),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: TextField(controller: _port, keyboardType: TextInputType.number, style: YmTextStyles.mono, decoration: const InputDecoration(labelText: 'Port UI'))),
        ]),
        if (_mode == 1) ...[
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(flex: 3, child: TextField(controller: _host, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('IP / host remote', 'Remote IP / host'), hintText: '192.168.56.10', prefixIcon: const Icon(Icons.dns_outlined, size: 18)))),
            const SizedBox(width: 10),
            SizedBox(width: 110, child: TextField(controller: _sshPort, keyboardType: TextInputType.number, style: YmTextStyles.mono, decoration: const InputDecoration(labelText: 'SSH port'))),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: TextField(controller: _user, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('User SSH', 'SSH user'), prefixIcon: const Icon(Icons.person_outline_rounded, size: 18)))),
            const SizedBox(width: 10),
            Expanded(child: TextField(
              controller: _pass,
              obscureText: !_showPass,
              style: YmTextStyles.mono,
              decoration: InputDecoration(
                labelText: tr('Password SSH', 'SSH password'),
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                suffixIcon: IconButton(icon: Icon(_showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18), onPressed: () => setState(() => _showPass = !_showPass)),
              ),
            )),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _key, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('Path private key (opsional, ganti password)', 'Private key path (optional, instead of password)'), hintText: r'C:\Users\kamu\.ssh\id_rsa', prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18))),
          const SizedBox(height: 6),
          Text(tr('Kredensial SSH hanya dikirim ke server lokalmu untuk konek — tidak disimpan ke disk.',
              'SSH credentials are only sent to your local server to connect — not stored on disk.'),
              style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ElevatedButton.icon(
            onPressed: _busy ? null : () => _do('install'),
            icon: _busy ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.download_rounded, size: 18),
            label: Text(tr('Auto-install & Jalankan', 'Auto-install & Run')),
          ),
          OutlinedButton.icon(onPressed: _busy ? null : () => _do('status'), icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(tr('Cek status', 'Check status'))),
          OutlinedButton.icon(onPressed: _busy ? null : () => _do('stop'), style: OutlinedButton.styleFrom(foregroundColor: YmColors.danger), icon: const Icon(Icons.stop_rounded, size: 18), label: Text(tr('Stop & hapus', 'Stop & remove'))),
          ElevatedButton.icon(
            onPressed: () => launchUrl(Uri.parse(_openUrl), mode: LaunchMode.externalApplication),
            style: ElevatedButton.styleFrom(backgroundColor: YmColors.success),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(tr('Buka UI SpiderFoot', 'Open SpiderFoot UI')),
          ),
          if (_running != null)
            SoftChip(
              _running! ? tr('AKTIF', 'RUNNING') : tr('MATI', 'STOPPED'),
              icon: _running! ? Icons.circle : Icons.circle_outlined,
              fg: _running! ? YmColors.onSuccessSoft : YmColors.textMuted,
              bg: _running! ? YmColors.successContainer.withOpacity(0.5) : YmColors.surfaceContainerHigh,
              pill: true, bold: true,
            ),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(color: YmColors.warningSoft.withOpacity(0.5), borderRadius: BorderRadius.circular(9)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 17, color: YmColors.onWarningSoft),
            const SizedBox(width: 9),
            Expanded(child: Text(
              tr('UI SpiderFoot tanpa login bawaan — di VPS jangan ekspos port-nya ke internet (pakai bind 127.0.0.1 + SSH tunnel, atau reverse proxy + auth). Pakai untuk aset/penggunaan milikmu.',
                  'SpiderFoot UI has no built-in login — on a VPS don\'t expose its port to the internet (bind 127.0.0.1 + SSH tunnel, or reverse proxy + auth). Use for your own assets/usage.'),
              style: YmTextStyles.labelSm.copyWith(color: YmColors.onWarningSoft))),
          ]),
        ),
      ]),
    );
  }

  Widget _logCard() {
    return HoverCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Log', style: YmTextStyles.labelMd.copyWith(fontWeight: FontWeight.w800, color: YmColors.textMuted)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 280),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
          child: SingleChildScrollView(child: SelectableText(_log, style: const TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Consolas', 'monospace'], fontSize: 11.5, height: 1.4))),
        ),
      ]),
    );
  }
}
