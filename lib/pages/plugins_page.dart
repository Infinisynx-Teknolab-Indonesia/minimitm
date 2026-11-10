import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';
import '../widgets/ai_dialog.dart';

class PluginsPage extends StatefulWidget {
  const PluginsPage({super.key});
  @override
  State<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends State<PluginsPage> {
  List<Map<String, dynamic>> _plugins = [];
  bool _loading = true;
  String _filter = '';
  String _tab = 'all'; // all | auto | manual | on

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reload = false}) async {
    setState(() => _loading = true);
    try {
      _plugins = reload ? await Api.instance.reloadPlugins() : await Api.instance.plugins();
    } catch (_) {
      _plugins = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(Map<String, dynamic> p, bool v) async {
    setState(() => p['enabled'] = v); // optimistis
    final r = await Api.instance.togglePlugin(p['name'] as String, v);
    if (r['ok'] != true) {
      setState(() => p['enabled'] = !v);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Gagal', 'Failed')}: ${r['error'] ?? tr('tidak diketahui', 'unknown')}')));
    } else {
      setState(() => p['enabled'] = r['enabled'] == true);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _plugins.where((p) {
      if (_tab == 'auto' && p['auto'] != true) return false;
      if (_tab == 'manual' && p['has_action'] != true) return false;
      if (_tab == 'on' && p['enabled'] != true) return false;
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      return (p['name'] as String).toLowerCase().contains(q) ||
          (p['description'] as String? ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final onCount = _plugins.where((p) => p['enabled'] == true).length;
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            crumbs: [tr('Alat', 'Tools'), 'Plugins'],
            title: 'Plugins',
            subtitle: tr('Modul gaya Burp: otomatis (ubah tiap request/response) atau manual (jalankan pada satu request). Hanya untuk aplikasi milikmu.',
                'Burp-style modules: automatic (modify each request/response) or manual (run on one request). Only for your own apps.'),
            actions: [
              SoftChip.neutral('${_plugins.length} ${tr('plugin', 'plugins')} • $onCount ${tr('aktif', 'on')}'),
              OutlinedButton.icon(onPressed: () => _load(reload: true), icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(tr('Muat ulang', 'Reload'))),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            SegmentedToggle<String>(
              value: _tab,
              items: [('all', tr('Semua', 'All')), ('auto', tr('Otomatis', 'Automatic')), ('manual', tr('Manual', 'Manual')), ('on', tr('Aktif', 'On'))],
              onChanged: (v) => setState(() => _tab = v),
            ),
            const Spacer(),
            SizedBox(
              width: 260,
              child: TextField(
                decoration: InputDecoration(hintText: tr('Cari plugin…', 'Search plugins…'), prefixIcon: const Icon(Icons.search_rounded, size: 18)),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            HoverCard(child: SizedBox(height: 200, child: EmptyState(icon: Icons.extension_outlined, title: tr('Tidak ada plugin', 'No plugins'), message: tr('Pastikan backend jalan, lalu Muat ulang.', 'Make sure the backend is running, then Reload.'))))
          else
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth > 1100 ? 2 : 1;
              final w = (c.maxWidth - (cols - 1) * 16) / cols;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [for (final p in _filtered) SizedBox(width: w, child: _card(p))],
              );
            }),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> p) {
    final err = p['error'] as String?;
    final requires = (p['requires'] as List?)?.cast<String>() ?? const [];
    return HoverCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: YmColors.surfaceContainer, borderRadius: BorderRadius.circular(10)),
                child: Icon(p['auto'] == true ? Icons.bolt_rounded : Icons.play_circle_outline_rounded, size: 20, color: p['auto'] == true ? YmColors.warning : YmColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['name'] as String, style: YmTextStyles.headlineSm),
                  const SizedBox(height: 2),
                  Text(p['description'] as String? ?? '', style: YmTextStyles.bodySm, maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
              Switch(value: p['enabled'] == true, onChanged: err != null ? null : (v) => _toggle(p, v)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (p['auto'] == true) SoftChip(tr('OTOMATIS', 'AUTO'), fg: YmColors.onWarningSoft, bg: YmColors.warningSoft, pill: true, bold: true, icon: Icons.bolt_rounded),
            if (p['has_action'] == true) SoftChip('MANUAL', fg: YmColors.link, bg: YmColors.primarySoft, pill: true, bold: true, icon: Icons.touch_app_outlined),
            for (final r in requires) SoftChip.neutral('pip: $r'),
            if (err != null) SoftChip.danger(tr('gagal dimuat', 'load failed'), icon: Icons.error_outline_rounded),
          ]),
          if (p['has_action'] == true && err == null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _runDialog(p),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(tr('Jalankan pada request…', 'Run on a request…')),
              ),
            ),
          ],
          if (err != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: YmColors.dangerSoft.withOpacity(0.4), borderRadius: BorderRadius.circular(8)),
              child: Text(err, style: YmTextStyles.mono.copyWith(fontSize: 11), maxLines: 4, overflow: TextOverflow.ellipsis),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runDialog(Map<String, dynamic> p) async {
    final flows = Api.instance.flows;
    if (flows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Belum ada request di History. Lewatkan trafik dulu.', 'No requests in History yet. Capture some traffic first.'))));
      return;
    }
    final flow = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(padding: const EdgeInsets.all(16), child: Text('${tr('Pilih request untuk', 'Pick a request for')} "${p['name']}"', style: YmTextStyles.headlineSm)),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final f in flows.take(60))
                      ListTile(
                        dense: true,
                        title: Text(f['url'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.bodySm),
                        leading: Text(f['method'] as String, style: YmTextStyles.labelSm.copyWith(color: methodColor(f['method'] as String), fontWeight: FontWeight.w700)),
                        onTap: () => Navigator.pop(context, f),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (flow == null) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    final r = await Api.instance.runPlugin(p['name'] as String, flow['id'] as int);
    if (!mounted) return;
    Navigator.pop(context); // tutup loading
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.extension_outlined, color: YmColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${p['name']} — ${tr('hasil', 'result')}', style: YmTextStyles.headlineSm)),
                  if (r['ok'] == true)
                    TextButton.icon(
                      onPressed: () => showAiDialog(context, title: p['name'] as String, attachment: r['result'] as String? ?? ''),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: Text(tr('Tanya AI', 'Ask AI')),
                    ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ]),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    r['ok'] == true ? (r['result'] as String? ?? tr('(kosong)', '(empty)')) : '${tr('Gagal', 'Failed')}: ${r['error']}',
                    style: YmTextStyles.mono,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
