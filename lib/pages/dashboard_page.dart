import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/nav.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    Api.instance.onFlow.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Api.instance,
      builder: (context, _) {
        final api = Api.instance;
        final flows = api.flows;
        final hosts = <String>{for (final f in flows) f['host'] as String};
        final https = flows.where((f) => f['scheme'] == 'https').length;
        final errs = flows.where((f) => (f['status'] as int? ?? 0) >= 400).length;
        return PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                crumbs: ['Mini MITM', tr('Dashboard', 'Dashboard')],
                title: tr('Dashboard', 'Dashboard'),
                subtitle: tr('Ringkasan proxy dan lalu lintas yang sedang kamu intip. Hanya untuk aplikasi & perangkat milikmu sendiri.',
                    'Overview of the proxy and the traffic you are inspecting. Only for your own apps & devices.'),
                actions: [
                  if (!api.proxyRunning)
                    ElevatedButton.icon(onPressed: api.start, icon: const Icon(Icons.play_arrow_rounded, size: 18), label: Text(tr('Mulai proxy', 'Start proxy')))
                  else
                    OutlinedButton.icon(onPressed: api.stop, icon: const Icon(Icons.stop_rounded, size: 18), label: Text(tr('Hentikan', 'Stop'))),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 1100 ? 4 : (c.maxWidth > 680 ? 2 : 1);
                final w = (c.maxWidth - (cols - 1) * 16) / cols;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(width: w, child: StatCard(label: tr('Total request', 'Total requests'), value: '${flows.length}', icon: Icons.swap_vert_rounded, color: YmColors.primary, onTap: () => Nav.go('history'))),
                    SizedBox(width: w, child: StatCard(label: tr('Host unik', 'Unique hosts'), value: '${hosts.length}', icon: Icons.dns_outlined, color: YmColors.accent)),
                    SizedBox(width: w, child: StatCard(label: tr('HTTPS (didekripsi)', 'HTTPS (decrypted)'), value: '$https', icon: Icons.lock_outline_rounded, color: YmColors.success)),
                    SizedBox(width: w, child: StatCard(label: tr('Response error (4xx/5xx)', 'Response errors (4xx/5xx)'), value: '$errs', icon: Icons.error_outline_rounded, color: YmColors.danger)),
                  ],
                );
              }),
              const SizedBox(height: 24),
              Text(tr('Lalu lintas terbaru', 'Recent traffic'), style: YmTextStyles.sectionTitle),
              const SizedBox(height: 12),
              if (flows.isEmpty)
                HoverCard(
                  child: SizedBox(
                    height: 240,
                    child: EmptyState(
                      icon: Icons.wifi_tethering_rounded,
                      title: api.proxyRunning ? tr('Menunggu lalu lintas…', 'Waiting for traffic…') : tr('Proxy belum jalan', 'Proxy not running'),
                      message: api.proxyRunning
                          ? tr('Atur proxy perangkat/aplikasimu ke alamat proxy, lalu buka aplikasi. Request akan muncul di sini secara langsung.',
                              'Point your device/app proxy to this address, then open the app. Requests will appear here live.')
                          : tr('Buka halaman Proxy untuk menyalakan proxy dan memasang sertifikat.',
                              'Open the Proxy page to start the proxy and install the certificate.'),
                      action: ElevatedButton(onPressed: () => Nav.go('proxy'), child: Text(tr('Buka halaman Proxy', 'Open Proxy page'))),
                    ),
                  ),
                )
              else
                HoverCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final f in flows.take(12))
                        InkWell(
                          onTap: () => Nav.go('history'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                SizedBox(width: 54, child: Text(f['method'] as String, style: YmTextStyles.labelSm.copyWith(color: methodColor(f['method'] as String), fontWeight: FontWeight.w700))),
                                SizedBox(width: 44, child: Text('${f['status']}', style: YmTextStyles.labelSm.copyWith(color: statusColor(f['status'] as int? ?? 0), fontWeight: FontWeight.w700))),
                                Expanded(child: Text(f['url'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.bodySm)),
                                const SizedBox(width: 8),
                                Text('${f['length']} B', style: YmTextStyles.labelSm),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
