import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';

/// Menu "Recon (OSINT)" — passive reconnaissance gaya SpiderFoot untuk domain/
/// aset MILIKMU sendiri. Modul passive: crt.sh subdomain, DNS, WHOIS, Wayback,
/// robots.txt, HTTP fingerprint. Tidak ada modul pengumpulan data pribadi orang.
class ReconPage extends StatefulWidget {
  const ReconPage({super.key});
  @override
  State<ReconPage> createState() => _ReconPageState();
}

class _ReconPageState extends State<ReconPage> {
  final _target = TextEditingController();
  final Set<String> _mods = {'dns', 'subdomains', 'whois', 'wayback', 'robots', 'fingerprint'};
  bool _busy = false;
  Map<String, dynamic>? _results;
  String _log = '';
  String _ranFor = '';

  static const _labels = {
    'dns': 'DNS', 'subdomains': 'Subdomain (crt.sh)', 'whois': 'WHOIS',
    'wayback': 'Wayback URL', 'robots': 'robots.txt', 'fingerprint': 'Fingerprint',
  };
  static const _icons = {
    'dns': Icons.dns_rounded, 'subdomains': Icons.account_tree_rounded, 'whois': Icons.badge_outlined,
    'wayback': Icons.history_rounded, 'robots': Icons.smart_toy_outlined, 'fingerprint': Icons.fingerprint_rounded,
  };

  @override
  void dispose() { _target.dispose(); super.dispose(); }

  void _copy(String v) {
    Clipboard.setData(ClipboardData(text: v));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Disalin.', 'Copied.'))));
  }

  Future<void> _run() async {
    final t = _target.text.trim();
    final looksPhone = RegExp(r'^\+?[\d\s\-()]{6,}$').hasMatch(t);
    if (t.isEmpty || (!t.contains('.') && !looksPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Isi domain, email, atau nomor telepon.', 'Enter a domain, email, or phone number.'))));
      return;
    }
    if (_mods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Pilih minimal satu modul.', 'Pick at least one module.'))));
      return;
    }
    setState(() { _busy = true; _results = null; _log = ''; });
    try {
      final r = await Api.instance.reconRun(t, _mods.toList());
      if (!mounted) return;
      setState(() {
        _busy = false;
        _log = (r['log'] ?? '').toString();
        if (r['ok'] == true) {
          _results = (r['results'] as Map?)?.cast<String, dynamic>() ?? {};
          _ranFor = (r['target'] ?? t).toString();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r['error'] ?? tr('Gagal', 'Failed')}')));
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
            crumbs: [tr('Alat', 'Tools'), 'Recon'],
            title: tr('Recon (OSINT)', 'Recon (OSINT)'),
            subtitle: tr(
                'Passive recon gaya SpiderFoot untuk domain/aset milikmu: subdomain, DNS, WHOIS, Wayback, robots, fingerprint. Hanya untuk aset milikmu / yang kamu diizinkan uji.',
                'SpiderFoot-style passive recon for your own domain/assets: subdomains, DNS, WHOIS, Wayback, robots, fingerprint. Only for assets you own or are authorized to test.'),
          ),
          const SizedBox(height: 14),
          _controls(),
          const SizedBox(height: 16),
          if (_busy)
            HoverCard(padding: const EdgeInsets.all(18), child: Row(children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: YmColors.primary)),
              const SizedBox(width: 12),
              Text(tr('Menjalankan recon…', 'Running recon…'), style: YmTextStyles.bodySm.copyWith(color: YmColors.outline)),
            ]))
          else if (_results != null)
            _resultsView()
          else
            HoverCard(padding: const EdgeInsets.all(18), child: Text(
              tr('Masukkan domain lalu klik "Jalankan recon".', 'Enter a domain then click "Run recon".'),
              style: YmTextStyles.bodySm.copyWith(color: YmColors.outline))),
        ],
      ),
    );
  }

  Widget _controls() {
    return HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _target,
          style: YmTextStyles.mono,
          onSubmitted: (_) => _busy ? null : _run(),
          decoration: InputDecoration(
            labelText: tr('Target: domain / email / no. telepon (milikmu)', 'Target: domain / email / phone (yours)'),
            hintText: 'example.com  •  kamu@domain.com  •  +62812xxxx',
            prefixIcon: const Icon(Icons.travel_explore_rounded, size: 18),
          ),
        ),
        const SizedBox(height: 12),
        Text(tr('Modul:', 'Modules:'), style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in _labels.keys)
            InkWell(
              onTap: _busy ? null : () => setState(() { _mods.contains(m) ? _mods.remove(m) : _mods.add(m); }),
              borderRadius: BorderRadius.circular(999),
              child: SoftChip(
                _labels[m]!,
                icon: _icons[m],
                fg: _mods.contains(m) ? YmColors.onPrimaryFixed : YmColors.textMuted,
                bg: _mods.contains(m) ? YmColors.primaryFixed : YmColors.surfaceContainerHigh,
                pill: true, bold: _mods.contains(m),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: _busy ? null : _run,
          icon: const Icon(Icons.radar_rounded, size: 18),
          label: Text(tr('Jalankan recon', 'Run recon')),
        ),
        const SizedBox(height: 8),
        Text(
          tr('Semua passive & hanya untuk aset milikmu. Email → audit keamanan domain-nya (MX/SPF/DMARC/DKIM) + recon domain. Telepon → metadata format saja (negara/kode), bukan cari pemilik.',
              'All passive & only for your own assets. Email → its domain mail-security audit (MX/SPF/DMARC/DKIM) + domain recon. Phone → format metadata only (country/code), not owner lookup.'),
          style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontStyle: FontStyle.italic),
        ),
      ]),
    );
  }

  List<Widget> _domainCards(Map<String, dynamic> res) {
    final w = <Widget>[];
    if (res['dns'] is Map) w.add(_dnsCard((res['dns'] as Map).cast<String, dynamic>()));
    if (res['subdomains'] is List) w.add(_listCard(Icons.account_tree_rounded, tr('Subdomain (crt.sh)', 'Subdomains (crt.sh)'), (res['subdomains'] as List).map((e) => e.toString()).toList()));
    if (res['fingerprint'] is Map) w.add(_fingerprintCard((res['fingerprint'] as Map).cast<String, dynamic>()));
    if (res['wayback'] is List) w.add(_listCard(Icons.history_rounded, tr('Wayback URL', 'Wayback URLs'), (res['wayback'] as List).map((e) => e.toString()).toList()));
    if (res['robots'] is Map && (res['robots'] as Map)['content'] != null) w.add(_textCard(Icons.smart_toy_outlined, 'robots.txt', (res['robots'] as Map)['content'].toString()));
    if (res['whois'] is String && (res['whois'] as String).trim().isNotEmpty) w.add(_textCard(Icons.badge_outlined, 'WHOIS', res['whois'].toString()));
    if (res['_errors'] is Map) {
      final errs = (res['_errors'] as Map).entries.map((e) => '${e.key}: ${e.value}').join('\n');
      w.add(_textCard(Icons.error_outline_rounded, tr('Error modul', 'Module errors'), errs));
    }
    return w;
  }

  Widget _resultsView() {
    final res = _results!;
    final kind = (res['kind'] ?? 'domain').toString();
    final widgets = <Widget>[Text('${tr('Hasil untuk', 'Results for')} $_ranFor', style: YmTextStyles.headlineSm), const SizedBox(height: 10)];

    if (kind == 'phone') {
      widgets.add(_phoneCard((res['phone'] as Map?)?.cast<String, dynamic>() ?? {}));
    } else if (kind == 'email') {
      widgets.add(_emailCard(res));
      final dr = (res['domain_results'] as Map?)?.cast<String, dynamic>() ?? {};
      widgets.addAll(_domainCards(dr));
    } else {
      widgets.addAll(_domainCards(res));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final w in widgets) Padding(padding: const EdgeInsets.only(bottom: 12), child: w)],
    );
  }

  Widget _phoneCard(Map<String, dynamic> p) {
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(k, style: YmTextStyles.labelMd.copyWith(fontWeight: FontWeight.w700, color: YmColors.primary))),
        const SizedBox(width: 8),
        Expanded(child: SelectableText(v, style: YmTextStyles.mono)),
      ]),
    );
    return HoverCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _cardHeader(Icons.phone_iphone_rounded, tr('Nomor telepon (metadata)', 'Phone number (metadata)')),
      const SizedBox(height: 10),
      row('E.164', (p['e164'] ?? '-').toString()),
      row(tr('Kode panggil', 'Calling code'), (p['calling_code'] ?? '-').toString().isEmpty ? '-' : p['calling_code'].toString()),
      row(tr('Negara', 'Country'), (p['country'] ?? '-').toString()),
      row(tr('No. nasional', 'National no.'), (p['national_number'] ?? '-').toString()),
      row(tr('Jumlah digit', 'Digits'), '${p['digits'] ?? '-'}'),
      row(tr('Masuk akal?', 'Plausible?'), (p['plausible'] == true) ? tr('ya', 'yes') : tr('tidak', 'no')),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: YmColors.warningSoft.withOpacity(0.5), borderRadius: BorderRadius.circular(9)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, size: 16, color: YmColors.onWarningSoft),
          const SizedBox(width: 8),
          Expanded(child: Text((p['note'] ?? '').toString(), style: YmTextStyles.labelSm.copyWith(color: YmColors.onWarningSoft))),
        ]),
      ),
    ]));
  }

  Widget _emailCard(Map<String, dynamic> res) {
    final ms = (res['mail_security'] as Map?)?.cast<String, dynamic>() ?? {};
    final mx = (ms['mx'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final spf = (ms['spf'] ?? '').toString();
    final dmarc = (ms['dmarc'] ?? '').toString();
    final dkim = (ms['dkim_selectors'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final notes = (ms['notes'] as List?)?.map((e) => e.toString()).toList() ?? [];
    Widget flag(String label, bool ok, String val) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 16, color: ok ? YmColors.success : YmColors.danger),
        const SizedBox(width: 8),
        SizedBox(width: 70, child: Text(label, style: YmTextStyles.labelMd.copyWith(fontWeight: FontWeight.w700))),
        Expanded(child: SelectableText(val.isEmpty ? '-' : val, style: YmTextStyles.mono.copyWith(fontSize: 11))),
      ]),
    );
    return HoverCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _cardHeader(Icons.mark_email_read_outlined, tr('Keamanan email domain', 'Email domain security')),
      const SizedBox(height: 4),
      Text('${res['email']}  •  ${tr('format', 'format')}: ${res['email_valid'] == true ? 'ok' : tr('tidak valid', 'invalid')}  •  domain: ${res['domain']}',
          style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
      const SizedBox(height: 10),
      flag('MX', mx.isNotEmpty, mx.join(', ')),
      flag('SPF', spf.isNotEmpty, spf),
      flag('DMARC', dmarc.isNotEmpty, dmarc),
      flag('DKIM', dkim.isNotEmpty, dkim.isEmpty ? '' : dkim.join(', ')),
      if (notes.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: YmColors.warningSoft.withOpacity(0.5), borderRadius: BorderRadius.circular(9)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final n in notes) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('• $n', style: YmTextStyles.labelSm.copyWith(color: YmColors.onWarningSoft))),
          ]),
        ),
      ],
    ]));
  }

  Widget _cardHeader(IconData ic, String title, {int? count, String? copyAll}) {
    return Row(children: [
      Icon(ic, size: 18, color: YmColors.primary),
      const SizedBox(width: 8),
      Text(title, style: YmTextStyles.headlineSm),
      if (count != null) ...[const SizedBox(width: 8), SoftChip('$count', pill: true)],
      const Spacer(),
      if (copyAll != null)
        IconButton(tooltip: tr('Salin semua', 'Copy all'), icon: Icon(Icons.copy_all_rounded, size: 18, color: YmColors.outline), onPressed: () => _copy(copyAll)),
    ]);
  }

  Widget _dnsCard(Map<String, dynamic> dns) {
    final rows = <Widget>[];
    dns.forEach((k, v) {
      if (k.startsWith('_')) return;
      final vals = (v as List?)?.map((e) => e.toString()).toList() ?? [];
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 56, child: Text(k, style: YmTextStyles.labelMd.copyWith(fontWeight: FontWeight.w800, color: YmColors.primary))),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(vals.join('\n'), style: YmTextStyles.mono)),
        ]),
      ));
    });
    return HoverCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _cardHeader(Icons.dns_rounded, 'DNS'),
      const SizedBox(height: 10),
      if (rows.isEmpty) Text(tr('(tidak ada record)', '(no records)'), style: YmTextStyles.bodySm.copyWith(color: YmColors.outline)) else ...rows,
    ]));
  }

  Widget _fingerprintCard(Map<String, dynamic> fp) {
    final tech = (fp['tech'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final headers = (fp['headers'] as Map?)?.cast<String, dynamic>() ?? {};
    return HoverCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _cardHeader(Icons.fingerprint_rounded, 'Fingerprint'),
      const SizedBox(height: 10),
      if ((fp['title'] ?? '').toString().isNotEmpty) ...[
        Text('${tr('Judul', 'Title')}: ${fp['title']}', style: YmTextStyles.bodySm), const SizedBox(height: 4),
      ],
      Text('${tr('Status', 'Status')}: ${fp['status'] ?? '-'}   •   ${fp['url'] ?? ''}', style: YmTextStyles.labelSm.copyWith(color: YmColors.outline)),
      if (tech.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final t in tech) SoftChip(t, icon: Icons.memory_rounded, pill: true, fg: YmColors.onPrimaryFixed, bg: YmColors.primaryFixed, bold: true)]),
      ],
      if (headers.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
          child: SelectableText(headers.entries.map((e) => '${e.key}: ${e.value}').join('\n'), style: YmTextStyles.mono),
        ),
      ],
    ]));
  }

  Widget _listCard(IconData ic, String title, List<String> items) {
    return HoverCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _cardHeader(ic, title, count: items.length, copyAll: items.join('\n')),
      const SizedBox(height: 8),
      if (items.isEmpty)
        Text(tr('(kosong)', '(empty)'), style: YmTextStyles.bodySm.copyWith(color: YmColors.outline))
      else
        Container(
          constraints: const BoxConstraints(maxHeight: 260),
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
          child: SingleChildScrollView(child: SelectableText(items.join('\n'), style: YmTextStyles.mono)),
        ),
    ]));
  }

  Widget _textCard(IconData ic, String title, String text) {
    return HoverCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _cardHeader(ic, title, copyAll: text),
      const SizedBox(height: 8),
      Container(
        constraints: const BoxConstraints(maxHeight: 260),
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
        child: SingleChildScrollView(child: SelectableText(text, style: YmTextStyles.mono)),
      ),
    ]));
  }
}
