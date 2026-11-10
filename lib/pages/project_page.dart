import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';

class ProjectPage extends StatefulWidget {
  const ProjectPage({super.key});
  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  final _path = TextEditingController();
  String _msg = '';

  Future<void> _import() async {
    if (_path.text.trim().isEmpty) {
      setState(() => _msg = tr('Isi path file project.json dulu.', 'Enter the project.json file path first.'));
      return;
    }
    final r = await Api.instance.projectImportPath(_path.text.trim());
    setState(() => _msg = r['ok'] == true
        ? '${tr('Berhasil dimuat', 'Loaded')}: ${r['imported_flows']} ${tr('request', 'requests')}.'
        : '${tr('Gagal', 'Failed')}: ${r['error']}');
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            crumbs: [tr('Akun', 'Account'), 'Project'],
            title: tr('Simpan / Muat Project', 'Save / Load Project'),
            subtitle: tr('Simpan semua lalu lintas + pengaturan ke satu file, lalu muat lagi nanti.',
                'Save all traffic + settings to a single file, then load it again later.'),
          ),
          const SizedBox(height: 20),
          HoverCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.save_alt_rounded, color: YmColors.primary, size: 20), const SizedBox(width: 8), Text(tr('Simpan project', 'Save project'), style: YmTextStyles.headlineSm)]),
              const SizedBox(height: 6),
              Text(tr('Unduh file minimitm-project.json berisi history + pengaturan.', 'Download minimitm-project.json with history + settings.'), style: YmTextStyles.bodySm),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => launchUrl(Uri.parse(Api.instance.projectExportUrl()), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(tr('Unduh project', 'Download project')),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          HoverCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.folder_open_rounded, color: YmColors.primary, size: 20), const SizedBox(width: 8), Text(tr('Muat project', 'Load project'), style: YmTextStyles.headlineSm)]),
              const SizedBox(height: 6),
              Text(tr('Masukkan path lengkap file project.json di PC ini.', 'Enter the full path to the project.json file on this PC.'), style: YmTextStyles.bodySm),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _path, style: YmTextStyles.mono, decoration: InputDecoration(labelText: tr('Path file', 'File path'), hintText: r'C:\Users\kamu\Downloads\minimitm-project.json'))),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _import, child: Text(tr('Muat', 'Load'))),
              ]),
              if (_msg.isNotEmpty) ...[const SizedBox(height: 10), Text(_msg, style: YmTextStyles.bodySm.copyWith(color: YmColors.primary))],
            ]),
          ),
        ],
      ),
    );
  }
}
