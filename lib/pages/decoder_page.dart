import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';

class DecoderPage extends StatefulWidget {
  const DecoderPage({super.key});
  @override
  State<DecoderPage> createState() => _DecoderPageState();
}

class _DecoderPageState extends State<DecoderPage> {
  final _in = TextEditingController();
  String _out = '';

  Future<void> _run(String op) async {
    final r = await Api.instance.decode(_in.text, op);
    setState(() => _out = r['ok'] == true ? (r['output'] as String) : 'Error: ${r['error']}');
  }

  @override
  Widget build(BuildContext context) {
    final ops = <(String, String)>[
      ('base64enc', 'Base64 ▸'),
      ('base64dec', 'Base64 ◂'),
      ('urlenc', 'URL ▸'),
      ('urldec', 'URL ◂'),
      ('hexenc', 'Hex ▸'),
      ('hexdec', 'Hex ◂'),
      ('htmlenc', 'HTML ▸'),
      ('htmldec', 'HTML ◂'),
    ];
    return PageBody(
      scroll: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(crumbs: [tr('Alat', 'Tools'), 'Decoder'], title: 'Decoder', subtitle: tr('Encode / decode Base64, URL, Hex, HTML. ▸ = encode, ◂ = decode.', 'Encode / decode Base64, URL, Hex, HTML. ▸ = encode, ◂ = decode.')),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (op, label) in ops) OutlinedButton(onPressed: () => _run(op), child: Text(label)),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _panel('Input', _in, editable: true)),
                const SizedBox(width: 12),
                Expanded(child: _panel(tr('Output', 'Output'), TextEditingController(text: _out), editable: false, copy: _out)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(String title, TextEditingController c, {required bool editable, String? copy}) {
    return Container(
      decoration: BoxDecoration(color: YmColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: YmColors.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: YmColors.surfaceAlt,
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            child: Row(children: [
              Text(title, style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (copy != null)
                IconButton(
                  icon: Icon(Icons.copy_rounded, size: 15, color: YmColors.outline),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: copy));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Disalin.', 'Copied.'))));
                  },
                ),
            ]),
          ),
          Expanded(
            child: TextField(
              controller: c,
              readOnly: !editable,
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: YmTextStyles.mono,
              decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(12)),
            ),
          ),
        ],
      ),
    );
  }
}
