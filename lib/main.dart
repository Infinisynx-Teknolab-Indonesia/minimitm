import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'theme/app_theme.dart';
import 'services/api.dart';
import 'services/i18n.dart';
import 'services/backend.dart';
import 'widgets/title_bar.dart';
import 'screens/shell_screen.dart';

final bool _isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_isDesktop) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1320, 820),
      minimumSize: Size(900, 560),
      center: true,
      title: 'Mini MITM Proxy',
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  await ThemeCtl.instance.load();
  await L.instance.load();
  await BackendManager.instance.load();
  Api.instance.connect();
  if (_isDesktop && BackendManager.instance.autoStart) {
    // ignore: discarded_futures
    BackendManager.instance.ensureStarted();
  }
  runApp(const MitmApp());
}

class MitmApp extends StatefulWidget {
  const MitmApp({super.key});
  @override
  State<MitmApp> createState() => _MitmAppState();
}

class _MitmAppState extends State<MitmApp> with WindowListener, TrayListener {
  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
      trayManager.addListener(this);
      _initTray();
      HardwareKeyboard.instance.addHandler(_onKey);
    }
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.f11) {
      _toggleFull();
      return true;
    }
    return false;
  }

  Future<void> _initTray() async {
    try {
      await trayManager.setIcon(Platform.isWindows ? 'assets/icons/app_icon.ico' : 'assets/icons/app_icon.png');
      await trayManager.setToolTip('Mini MITM Proxy');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'show', label: tr('Buka', 'Open')),
        MenuItem(key: 'fullscreen', label: tr('Layar penuh', 'Full screen')),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: tr('Keluar', 'Quit')),
      ]));
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
      HardwareKeyboard.instance.removeHandler(_onKey);
    }
    super.dispose();
  }

  // ---- tray ----
  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem item) async {
    switch (item.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'fullscreen':
        await windowManager.setFullScreen(!(await windowManager.isFullScreen()));
        break;
      case 'exit':
        await _quit();
        break;
    }
  }

  // ---- window ----
  @override
  void onWindowClose() async {
    await _quit();
  }

  Future<void> _quit() async {
    BackendManager.instance.stop();
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      await trayManager.destroy();
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  Future<void> _toggleFull() async {
    await windowManager.setFullScreen(!(await windowManager.isFullScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ThemeCtl.instance, L.instance]),
      builder: (context, _) => MaterialApp(
        title: 'Mini MITM Proxy',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        builder: (context, child) => Column(
          children: [
            const AppTitleBar(),
            Expanded(child: child ?? const SizedBox()),
          ],
        ),
        home: const ShellScreen(),
      ),
    );
  }
}
