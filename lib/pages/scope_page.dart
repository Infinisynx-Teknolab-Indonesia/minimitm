import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';

class ScopePage extends StatefulWidget {
  const ScopePage({super.key});
  @override
  State<ScopePage> createState() => _ScopePageState();
}

class _ScopePageState extends State<ScopePage> {
  bool _enabled = false;
  List<String> _include = [];
  List<String> _exclude = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cfg = await Api.instance.getConfig();
      final sc = (cfg['scope'] ?? {}) as Map<String, dynamic>;
      _enabled = sc['enabled'] == true;
      _include = ((sc['include'] as List?) ?? []).cast<String>();
      _exclude = ((sc['exclude'] as List?) ?? []).cast<String>();
    } catch (_) {}
    setState(() => _loaded = true);
  }

  Future<void> _save() async {
    await Api.instance.putConfig({
      'scope': {'enabled': _enabled, 'include': _include, 'exclude': _exclude}
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Scope disimpan.', 'Scope saved.'))));
  }

  void _add(List<String> list) async {
    final v = await _ask();
    if (v != null && v.trim().isNotEmpty) {
      setState(() => list.add(v.trim()));
      _save();
    }
  }

  Future<String?> _ask() {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Tambah pola host', 'Add host pattern')),
        content: TextField(controller: c, autofocus: true, decoration: InputDecoration(hintText: tr('mis. united.com  atau  *united.com*  atau  *.united.com', 'e.g. united.com  or  *united.com*  or  *.united.com'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Batal', 'Cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, c.text), child: Text(tr('Tambah', 'Add'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            crumbs: [tr('Lalu lintas', 'Traffic'), 'Scope'],
            title: 'Scope',
            subtitle: tr('Batasi target: hanya host yang cocok yang di-intercept & di-scan. Kosongkan include = semua (kecuali exclude).',
                'Limit targets: only matching hosts are intercepted & scanned. Empty include = all (except exclude).'),
            actions: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(tr('Aktif', 'Enabled'), style: YmTextStyles.labelMd),
                const SizedBox(width: 8),
                Switch(value: _enabled, onChanged: (v) { setState(() => _enabled = v); _save(); }),
              ]),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, c) {
            final two = c.maxWidth > 820;
            final w = two ? (c.maxWidth - 16) / 2 : c.maxWidth;
            return Wrap(spacing: 16, runSpacing: 16, children: [
              SizedBox(width: w, child: _listCard(tr('Include (hanya ini)', 'Include (only these)'), _include, Icons.check_circle_outline_rounded, YmColors.success)),
              SizedBox(width: w, child: _listCard(tr('Exclude (abaikan)', 'Exclude (ignore)'), _exclude, Icons.block_rounded, YmColors.danger)),
            ]);
          }),
        ],
      ),
    );
  }

  Widget _listCard(String title, List<String> list, IconData icon, Color color) {
    return HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: YmTextStyles.headlineSm)),
            IconButton(onPressed: () => _add(list), icon: Icon(Icons.add_rounded, color: YmColors.primary)),
          ]),
          const SizedBox(height: 8),
          if (list.isEmpty)
            Padding(padding: const EdgeInsets.all(8), child: Text(tr('(kosong)', '(empty)'), style: YmTextStyles.bodySm))
          else
            for (final h in list)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(h, style: YmTextStyles.mono),
                trailing: IconButton(
                  icon: Icon(Icons.close_rounded, size: 16, color: YmColors.outline),
                  onPressed: () { setState(() => list.remove(h)); _save(); },
                ),
              ),
        ],
      ),
    );
  }
}
