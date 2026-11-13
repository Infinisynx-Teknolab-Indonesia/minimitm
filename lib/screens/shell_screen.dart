import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api.dart';
import '../services/nav.dart';
import '../services/i18n.dart';
import '../widgets/ui.dart';
import '../widgets/guide.dart';
import '../pages/dashboard_page.dart';
import '../pages/proxy_page.dart';
import '../pages/history_page.dart';
import '../pages/repeater_page.dart';
import '../pages/intercept_page.dart';
import '../pages/scanner_page.dart';
import '../pages/plugins_page.dart';
import '../pages/intruder_page.dart';
import '../pages/usb_page.dart';
import '../pages/frida_page.dart';
import '../pages/websocket_page.dart';
import '../pages/decoder_page.dart';
import '../pages/jwt_page.dart';
import '../pages/totp_page.dart';
import '../pages/scope_page.dart';
import '../pages/matchreplace_page.dart';
import '../pages/comparer_page.dart';
import '../pages/collaborator_page.dart';
import '../pages/apk_page.dart';
import '../pages/recon_page.dart';
import '../pages/webscan_page.dart';
import '../pages/spiderfoot_page.dart';
import '../pages/email_login_page.dart';
import '../pages/sms_page.dart';
import '../pages/project_page.dart';
import '../pages/settings_page.dart';

class _NavEntry {
  final String id;
  final String label;
  final IconData icon;
  final String groupId; // '', traffic, tools, account
  const _NavEntry(this.id, this.label, this.icon, this.groupId);
  String get group => switch (groupId) {
        'traffic' => tr('Lalu lintas', 'Traffic'),
        'tools' => tr('Alat', 'Tools'),
        'account' => tr('Akun', 'Account'),
        _ => '',
      };
}

List<_NavEntry> get _entries => [
      _NavEntry('dashboard', tr('Dashboard', 'Dashboard'), Icons.space_dashboard_outlined, ''),
      _NavEntry('proxy', tr('Proxy', 'Proxy'), Icons.lan_outlined, ''),
      _NavEntry('history', tr('HTTP History', 'HTTP History'), Icons.history_rounded, 'traffic'),
      _NavEntry('intercept', tr('Intercept', 'Intercept'), Icons.pan_tool_outlined, 'traffic'),
      _NavEntry('websocket', tr('WebSocket', 'WebSocket'), Icons.swap_horiz_rounded, 'traffic'),
      _NavEntry('usb', tr('USB (ADB)', 'USB (ADB)'), Icons.usb_rounded, 'traffic'),
      _NavEntry('frida', 'Frida', Icons.bolt_outlined, 'traffic'),
      _NavEntry('scope', tr('Scope', 'Scope'), Icons.filter_alt_outlined, 'traffic'),
      _NavEntry('repeater', tr('Repeater', 'Repeater'), Icons.send_outlined, 'tools'),
      _NavEntry('intruder', tr('Intruder', 'Intruder'), Icons.rocket_launch_outlined, 'tools'),
      _NavEntry('scanner', tr('Scanner', 'Scanner'), Icons.radar_outlined, 'tools'),
      _NavEntry('matchreplace', tr('Match & Replace', 'Match & Replace'), Icons.find_replace_rounded, 'tools'),
      _NavEntry('comparer', tr('Comparer', 'Comparer'), Icons.compare_arrows_rounded, 'tools'),
      _NavEntry('collaborator', tr('Collaborator', 'Collaborator'), Icons.hub_outlined, 'tools'),
      _NavEntry('plugins', tr('Plugins', 'Plugins'), Icons.extension_outlined, 'tools'),
      _NavEntry('decoder', tr('Decoder', 'Decoder'), Icons.transform_rounded, 'tools'),
      _NavEntry('jwt', tr('JWT', 'JWT'), Icons.vpn_key_outlined, 'tools'),
      _NavEntry('totp', tr('TOTP / OTP', 'TOTP / OTP'), Icons.timer_outlined, 'tools'),
      _NavEntry('apk', tr('APK Tools', 'APK Tools'), Icons.android_rounded, 'tools'),
      _NavEntry('recon', tr('Recon (OSINT)', 'Recon (OSINT)'), Icons.travel_explore_rounded, 'tools'),
      _NavEntry('webscan', tr('Cek Kelemahan Web', 'Web Vuln Scan'), Icons.bug_report_outlined, 'tools'),
      _NavEntry('spiderfoot', 'SpiderFoot', Icons.hub_rounded, 'tools'),
      _NavEntry('email', tr('Email Login', 'Email Login'), Icons.mark_email_unread_outlined, 'tools'),
      _NavEntry('sms', tr('SMS Masuk', 'Inbound SMS'), Icons.sms_outlined, 'tools'),
      _NavEntry('project', tr('Project', 'Project'), Icons.folder_zip_outlined, 'account'),
      _NavEntry('settings', tr('Pengaturan', 'Settings'), Icons.settings_outlined, 'account'),
    ];

const _sidebarWidth = 272.0;

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  final _ids = _entries.map((e) => e.id).toList();

  @override
  void initState() {
    super.initState();
    Nav.page.addListener(_onNav);
  }

  @override
  void dispose() {
    Nav.page.removeListener(_onNav);
    super.dispose();
  }

  void _onNav() => setState(() {});

  // Bungkus tiap halaman dengan footer Panduan (muncul di semua menu).
  Widget _withGuide(String id, Widget page) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: page),
          GuideFooter(id: id),
        ],
      );

  Widget _build(String id) => switch (id) {
        'dashboard' => const DashboardPage(),
        'proxy' => const ProxyPage(),
        'history' => const HistoryPage(),
        'intercept' => const InterceptPage(),
        'websocket' => const WebSocketPage(),
        'usb' => const UsbPage(),
        'frida' => const FridaPage(),
        'scope' => const ScopePage(),
        'repeater' => const RepeaterPage(),
        'intruder' => const IntruderPage(),
        'scanner' => const ScannerPage(),
        'matchreplace' => const MatchReplacePage(),
        'comparer' => const ComparerPage(),
        'collaborator' => const CollaboratorPage(),
        'plugins' => const PluginsPage(),
        'decoder' => const DecoderPage(),
        'jwt' => const JwtPage(),
        'totp' => const TotpPage(),
        'apk' => const ApkPage(),
        'recon' => const ReconPage(),
        'webscan' => const WebScanPage(),
        'spiderfoot' => const SpiderFootPage(),
        'email' => const EmailLoginPage(),
        'sms' => const SmsPage(),
        'project' => const ProjectPage(),
        _ => const SettingsPage(),
      };

  @override
  Widget build(BuildContext context) {
    final active = Nav.page.value;
    final idx = _ids.indexOf(active).clamp(0, _ids.length - 1);
    return Scaffold(
      backgroundColor: YmColors.paper,
      body: Column(
        children: [
          const _TopBar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Sidebar(active: active),
                Expanded(
                  child: IndexedStack(
                    index: idx,
                    sizing: StackFit.expand,
                    children: [for (final e in _entries) _withGuide(e.id, _build(e.id))],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
//  TOP BAR
// ============================================================================
class _TopBar extends StatelessWidget {
  const _TopBar();
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Api.instance,
      builder: (context, _) {
        final api = Api.instance;
        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: YmColors.surface.withOpacity(0.95),
            border: YmColors.isDark ? Border(bottom: BorderSide(color: YmColors.line)) : null,
            boxShadow: YmColors.isDark ? null : const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 1))],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: YmColors.primary, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.shield_moon_outlined, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 10),
              Text('Mini MITM Proxy',
                  style: TextStyle(fontFamily: kFontDisplay, fontSize: 16, fontWeight: FontWeight.w800, color: YmColors.textDark, letterSpacing: -0.3)),
              const SizedBox(width: 14),
              StatusPill(running: api.proxyRunning, text: api.proxyRunning ? '${tr('Proxy ON', 'Proxy ON')} :${api.status['port']}' : tr('Proxy OFF', 'Proxy OFF')),
              const Spacer(),
              // koneksi ke backend
              SoftChip(
                api.connected ? tr('Backend tersambung', 'Backend connected') : tr('Backend terputus', 'Backend offline'),
                icon: api.connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                fg: api.connected ? YmColors.onSuccessSoft : YmColors.onDangerSoft,
                bg: api.connected ? YmColors.successContainer.withOpacity(0.4) : YmColors.dangerSoft,
                pill: true,
                bold: true,
              ),
              const SizedBox(width: 8),
              _LangButton(),
              const SizedBox(width: 4),
              const _ThemeMenu(),
            ],
          ),
        );
      },
    );
  }
}

class _LangButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr('Ganti bahasa', 'Change language'),
      child: OutlinedButton(
        onPressed: () => L.instance.toggle(),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: const Size(0, 36)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.translate_rounded, size: 15, color: YmColors.textMuted),
          const SizedBox(width: 6),
          Text(L.instance.lang.toUpperCase(), style: YmTextStyles.labelMd.copyWith(fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _ThemeMenu extends StatelessWidget {
  const _ThemeMenu();
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Tema tampilan',
      icon: Icon(Icons.palette_outlined, color: YmColors.textMuted, size: 20),
      onSelected: (id) => ThemeCtl.instance.set(id),
      itemBuilder: (context) => [
        for (final p in appPalettes)
          PopupMenuItem(
            value: p.id,
            child: Row(children: [
              Container(width: 16, height: 16, decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(5))),
              const SizedBox(width: 10),
              Text(p.name),
              const SizedBox(width: 8),
              if (p.id == ThemeCtl.instance.palette.id) Icon(Icons.check, size: 15, color: YmColors.primary),
            ]),
          ),
      ],
    );
  }
}

// ============================================================================
//  SIDEBAR
// ============================================================================
class _Sidebar extends StatefulWidget {
  final String active;
  const _Sidebar({required this.active});
  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  final _stackKey = GlobalKey();
  final _keys = <String, GlobalKey>{};
  Rect? _highlight;

  GlobalKey _key(String id) => _keys.putIfAbsent(id, () => GlobalKey());

  void _measure() {
    if (!mounted) return;
    final box = _keys[widget.active]?.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    Rect? r;
    if (box != null && stack != null && box.attached && stack.attached && box.hasSize) {
      final off = box.localToGlobal(Offset.zero, ancestor: stack);
      r = off & box.size;
    }
    if (r != _highlight) setState(() => _highlight = r);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final groups = <String, List<_NavEntry>>{};
    for (final e in _entries) {
      groups.putIfAbsent(e.group, () => []).add(e);
    }
    return Container(
      width: _sidebarWidth,
      decoration: BoxDecoration(
        color: Color.alphaBlend(YmColors.surfaceAlt.withOpacity(0.7), YmColors.paper),
        border: YmColors.isDark ? Border(right: BorderSide(color: YmColors.line)) : null,
        boxShadow: YmColors.isDark ? null : const [BoxShadow(color: Color(0x050F172A), blurRadius: 12, offset: Offset(1, 0))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
              child: Stack(
                key: _stackKey,
                children: [
                  if (_highlight != null)
                    AnimatedPositioned(
                      duration: motion(context, const Duration(milliseconds: 300)),
                      curve: Curves.easeOutCubic,
                      left: _highlight!.left,
                      top: _highlight!.top,
                      width: _highlight!.width,
                      height: _highlight!.height,
                      child: Container(
                        decoration: BoxDecoration(color: YmColors.surfaceHigh, borderRadius: BorderRadius.circular(12), boxShadow: shadowSm),
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in groups.entries) ...[
                        if (entry.key.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                            child: Text(entry.key.toUpperCase(),
                                style: YmTextStyles.labelSm.copyWith(color: YmColors.outline, letterSpacing: 0.55)),
                          ),
                        for (final e in entry.value)
                          _SideItem(
                            key: _key(e.id),
                            icon: e.icon,
                            label: e.label,
                            active: widget.active == e.id,
                            onTap: () => Nav.go(e.id),
                          ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const _InterceptBadge(),
        ],
      ),
    );
  }
}

class _SideItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SideItem({super.key, required this.icon, required this.label, required this.active, required this.onTap});
  @override
  State<_SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<_SideItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final w = widget;
    final fg = w.active ? YmColors.primary : (_hover ? YmColors.textDark : YmColors.textMuted);
    final iconColor = w.active ? YmColors.primary : (_hover ? YmColors.primary : YmColors.outline);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: w.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: motion(context, const Duration(milliseconds: 150)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: !w.active && _hover ? YmColors.surfaceContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(w.icon, color: iconColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(w.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: YmTextStyles.labelLg.copyWith(color: fg, fontWeight: w.active ? FontWeight.w600 : FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lencana jumlah request tertahan (intercept) di bawah sidebar.
class _InterceptBadge extends StatelessWidget {
  const _InterceptBadge();
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Api.instance,
      builder: (context, _) {
        final n = Api.instance.pendingIntercept.length;
        if (n == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.all(14),
          child: HoverCard(
            onTap: () => Nav.go('intercept'),
            color: YmColors.warningSoft,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.pan_tool_outlined, size: 18, color: YmColors.onWarningSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('$n ${tr('request tertahan', 'held requests')}', style: YmTextStyles.labelMd.copyWith(color: YmColors.onWarningSoft, fontWeight: FontWeight.w700)),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: YmColors.onWarningSoft),
              ],
            ),
          ),
        );
      },
    );
  }
}
