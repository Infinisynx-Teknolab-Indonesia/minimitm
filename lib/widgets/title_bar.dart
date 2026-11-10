import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_theme.dart';

/// Title bar sendiri (bawaan Windows disembunyikan) - gaya ArsipDokumenPU.
class AppTitleBar extends StatelessWidget {
  const AppTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return const SizedBox.shrink();
    return Container(
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [YmColors.primaryDeep, YmColors.primary]),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.shield_moon_outlined, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          const Text('Mini MITM Proxy',
              style: TextStyle(color: Colors.white, fontFamily: kFontDisplay, fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: 0.2)),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async => await windowManager.isMaximized() ? windowManager.unmaximize() : windowManager.maximize(),
              child: const SizedBox(height: 36),
            ),
          ),
          _WinBtn(icon: Icons.fullscreen, onTap: () async => windowManager.setFullScreen(!(await windowManager.isFullScreen()))),
          _WinBtn(icon: Icons.remove, onTap: () => windowManager.minimize()),
          _WinBtn(icon: Icons.crop_square, onTap: () async => await windowManager.isMaximized() ? windowManager.unmaximize() : windowManager.maximize()),
          _WinBtn(icon: Icons.close, hoverRed: true, onTap: () => windowManager.close()),
        ],
      ),
    );
  }
}

class _WinBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool hoverRed;
  const _WinBtn({required this.icon, required this.onTap, this.hoverRed = false});
  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 44,
          height: 36,
          color: _h ? (widget.hoverRed ? const Color(0xFFE81123) : Colors.white24) : Colors.transparent,
          child: Icon(widget.icon, size: 15, color: Colors.white),
        ),
      ),
    );
  }
}
