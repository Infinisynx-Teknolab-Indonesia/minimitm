import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';

const _wheres = ['request_header', 'request_body', 'response_header', 'response_body'];

class MatchReplacePage extends StatefulWidget {
  const MatchReplacePage({super.key});
  @override
  State<MatchReplacePage> createState() => _MatchReplacePageState();
}

class _MatchReplacePageState extends State<MatchReplacePage> {
  List<Map<String, dynamic>> _rules = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cfg = await Api.instance.getConfig();
      _rules = ((cfg['match_replace'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    setState(() => _loaded = true);
  }

  Future<void> _save() async {
    await Api.instance.putConfig({'match_replace': _rules});
  }

  String _whereLabel(String w) => switch (w) {
        'request_header' => tr('Header request', 'Request header'),
        'request_body' => tr('Body request', 'Request body'),
        'response_header' => tr('Header response', 'Response header'),
        _ => tr('Body response', 'Response body'),
      };

  void _edit([int? idx]) {
    final r = idx != null ? Map<String, dynamic>.from(_rules[idx]) : {'enabled': true, 'where': 'response_body', 'match': '', 'replace': '', 'regex': false, 'host': ''};
    final match = TextEditingController(text: r['match'] as String? ?? '');
    final replace = TextEditingController(text: r['replace'] as String? ?? '');
    final host = TextEditingController(text: r['host'] as String? ?? '');
    String where = r['where'] as String? ?? 'response_body';
    bool regex = r['regex'] == true;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(idx == null ? tr('Aturan baru', 'New rule') : tr('Ubah aturan', 'Edit rule')),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  initialValue: where,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: tr('Lokasi', 'Where')),
                  items: [for (final w in _wheres) DropdownMenuItem(value: w, child: Text(_whereLabel(w)))],
                  onChanged: (v) => where = v ?? where,
                ),
                const SizedBox(height: 10),
                TextField(controller: match, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('Cari (match)', 'Match'))),
                const SizedBox(height: 10),
                TextField(controller: replace, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('Ganti (replace)', 'Replace'))),
                const SizedBox(height: 10),
                TextField(controller: host, decoration: InputDecoration(labelText: tr('Host (opsional, kosong = semua)', 'Host (optional, empty = all)'))),
                const SizedBox(height: 4),
                StatefulBuilder(
                  builder: (context, s2) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: regex,
                    onChanged: (v) => s2(() => regex = v ?? false),
                    title: Text(tr('Pakai regex', 'Use regex'), style: YmTextStyles.labelMd),
                  ),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Batal', 'Cancel'))),
            ElevatedButton(
              onPressed: () {
                final nr = {'enabled': r['enabled'] ?? true, 'where': where, 'match': match.text, 'replace': replace.text, 'regex': regex, 'host': host.text.trim()};
                setState(() {
                  if (idx == null) {
                    _rules.add(nr);
                  } else {
                    _rules[idx] = nr;
                  }
                });
                _save();
                Navigator.pop(context);
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
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            crumbs: [tr('Alat', 'Tools'), 'Match & Replace'],
            title: 'Match & Replace',
            subtitle: tr('Ganti teks otomatis di request/response saat proxy jalan (mis. "premium: false" → true). Untuk aplikasi milikmu.',
                'Auto-replace text in requests/responses while the proxy runs (e.g. "premium: false" → true). For your own apps.'),
            actions: [
              ElevatedButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded, size: 18), label: Text(tr('Aturan baru', 'New rule'))),
            ],
          ),
          const SizedBox(height: 20),
          if (_rules.isEmpty)
            HoverCard(child: SizedBox(height: 200, child: EmptyState(icon: Icons.find_replace_rounded, title: tr('Belum ada aturan', 'No rules yet'), message: tr('Tambah aturan untuk mengganti teks di lalu lintas secara otomatis.', 'Add a rule to auto-replace text in traffic.'))))
          else
            for (var i = 0; i < _rules.length; i++) _ruleCard(i),
        ],
      ),
    );
  }

  Widget _ruleCard(int i) {
    final r = _rules[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HoverCard(
        onTap: () => _edit(i),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Switch(value: r['enabled'] == true, onChanged: (v) { setState(() => r['enabled'] = v); _save(); }),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SoftChip.neutral(_whereLabel(r['where'] as String? ?? '')),
                if (r['regex'] == true) ...[const SizedBox(width: 6), SoftChip('regex', fg: YmColors.link, bg: YmColors.primarySoft, pill: true, bold: true)],
                if ((r['host'] as String? ?? '').isNotEmpty) ...[const SizedBox(width: 6), SoftChip.neutral(r['host'] as String)],
              ]),
              const SizedBox(height: 6),
              Text('${r['match']}  →  ${r['replace']}', style: YmTextStyles.mono, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 18, color: YmColors.danger),
            onPressed: () { setState(() => _rules.removeAt(i)); _save(); },
          ),
        ]),
      ),
    );
  }
}
