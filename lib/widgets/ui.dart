import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ============================================================================
//  Komponen tampilan bersama (gaya ArsipDokumenPU).
// ============================================================================

/// Muncul halus sekali: memudar + naik sedikit.
class Reveal extends StatefulWidget {
  final Widget child;
  final int index;
  const Reveal({super.key, required this.child, this.index = 0});
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _c.value = 1;
      return;
    }
    Future.delayed(Duration(milliseconds: 40 * (widget.index > 10 ? 10 : widget.index)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _a,
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(_a), child: widget.child),
      );
}

/// Kartu dengan efek hover (naik 1px + bayangan).
class HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final Color? hoverColor;
  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.radius = 12,
    this.hoverColor,
  });
  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final w = widget;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: w.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: w.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: motion(context, const Duration(milliseconds: 200)),
          curve: kMotionCurve,
          transform: Matrix4.translationValues(0, _hover && w.onTap != null && !reduceMotion(context) ? -1 : 0, 0),
          padding: w.padding,
          decoration: BoxDecoration(
            color: _hover && w.hoverColor != null ? w.hoverColor : (w.color ?? YmColors.surface),
            borderRadius: BorderRadius.circular(w.radius),
            border: w.borderColor != null
                ? Border.all(color: w.borderColor!)
                : (YmColors.isDark ? Border.all(color: _hover ? YmColors.primary.withOpacity(0.5) : YmColors.line) : null),
            boxShadow: _hover ? hoverShadow : softShadow,
          ),
          child: Material(type: MaterialType.transparency, child: w.child),
        ),
      ),
    );
  }
}

/// Chip kecil (pill / kotak).
class SoftChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? fg;
  final Color? bg;
  final bool pill;
  final bool bold;
  final Color? dot;
  const SoftChip(this.text, {super.key, this.icon, this.fg, this.bg, this.pill = false, this.bold = false, this.dot});

  factory SoftChip.success(String t, {IconData? icon, Color? dot}) =>
      SoftChip(t, icon: icon, dot: dot, fg: YmColors.onSuccessSoft, bg: YmColors.successContainer.withOpacity(0.5), pill: true, bold: true);
  factory SoftChip.primary(String t, {IconData? icon, Color? dot}) =>
      SoftChip(t, icon: icon, dot: dot, fg: YmColors.onPrimaryFixed, bg: YmColors.primaryFixed, pill: true, bold: true);
  factory SoftChip.warning(String t, {IconData? icon, Color? dot}) =>
      SoftChip(t, icon: icon, dot: dot, fg: YmColors.onWarningSoft, bg: YmColors.warningSoft, pill: true, bold: true);
  factory SoftChip.danger(String t, {IconData? icon, Color? dot}) =>
      SoftChip(t, icon: icon, dot: dot, fg: YmColors.onDangerSoft, bg: YmColors.dangerSoft, pill: true, bold: true);
  factory SoftChip.neutral(String t, {IconData? icon}) => SoftChip(t, icon: icon, fg: YmColors.textMuted, bg: YmColors.surfaceContainerHigh, pill: true);

  @override
  Widget build(BuildContext context) {
    final f = fg ?? YmColors.textMuted;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: pill ? 10 : 8, vertical: 2),
      decoration: BoxDecoration(color: bg ?? YmColors.surfaceContainer, borderRadius: BorderRadius.circular(pill ? 999 : 6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), const SizedBox(width: 6)],
          if (icon != null) ...[Icon(icon, size: 14, color: f), const SizedBox(width: 4)],
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: YmTextStyles.labelSm.copyWith(color: f, fontWeight: bold ? FontWeight.w600 : FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// Judul halaman: jejak + judul besar + keterangan + tombol aksi di kanan.
class PageHeader extends StatelessWidget {
  final List<String> crumbs;
  final String title;
  final String? subtitle;
  final Widget? badge;
  final List<Widget> actions;
  const PageHeader({super.key, this.crumbs = const [], required this.title, this.subtitle, this.badge, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (crumbs.isNotEmpty || badge != null)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < crumbs.length; i++) ...[
                if (i > 0) Text('/', style: YmTextStyles.labelSm.copyWith(color: YmColors.outlineVariant)),
                Text(crumbs[i],
                    style: YmTextStyles.labelMd.copyWith(
                        color: i == crumbs.length - 1 ? YmColors.textDark : YmColors.outline,
                        fontWeight: FontWeight.w500)),
              ],
              if (badge != null) badge!,
            ],
          ),
        Padding(
          padding: EdgeInsets.only(top: crumbs.isNotEmpty ? 4 : 0),
          child: Text(title, style: YmTextStyles.display),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: Text(subtitle!, style: YmTextStyles.bodyMd)),
        ],
      ],
    );
    if (actions.isEmpty) return left;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Flexible(child: Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8, children: actions)),
      ],
    );
  }
}

/// Kartu statistik.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color? tileBg;
  final String? sub;
  final Widget? chip;
  final VoidCallback? onTap;
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.tileBg,
    this.sub,
    this.chip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: tileBg ?? YmColors.surfaceContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              if (chip != null) chip!,
            ],
          ),
          const SizedBox(height: 16),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.labelMd.copyWith(color: YmColors.textMuted)),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: YmTextStyles.display),
          if (sub != null) ...[const SizedBox(height: 8), Text(sub!, style: YmTextStyles.bodySm, maxLines: 2, overflow: TextOverflow.ellipsis)],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Reveal(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(18)),
                  child: Icon(icon, size: 28, color: YmColors.primary),
                ),
                const SizedBox(height: 14),
                Text(title, textAlign: TextAlign.center, style: YmTextStyles.sectionTitle),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Text(message, textAlign: TextAlign.center, style: YmTextStyles.label.copyWith(fontSize: 13, height: 1.5)),
                ),
                if (action != null) ...[const SizedBox(height: 16), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pembungkus halaman: padding 24.
class PageBody extends StatelessWidget {
  final Widget child;
  final bool scroll;
  const PageBody({super.key, required this.child, this.scroll = true});
  @override
  Widget build(BuildContext context) {
    const pad = EdgeInsets.all(24);
    return scroll ? SingleChildScrollView(padding: pad, child: child) : Padding(padding: pad, child: child);
  }
}

/// Pilihan bersegmen dengan penanda meluncur.
class SegmentedToggle<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  const SegmentedToggle({super.key, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: YmColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, label) in items)
            GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: motion(context, const Duration(milliseconds: 180)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: v == value ? YmColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: v == value ? shadowSm : null,
                ),
                child: Text(label,
                    style: YmTextStyles.labelMd.copyWith(
                        color: v == value ? YmColors.primary : YmColors.textMuted, fontWeight: v == value ? FontWeight.w700 : FontWeight.w500)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pill status proxy (hijau = jalan, abu = mati).
class StatusPill extends StatelessWidget {
  final bool running;
  final String text;
  const StatusPill({super.key, required this.running, required this.text});
  @override
  Widget build(BuildContext context) {
    final c = running ? YmColors.success : YmColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (running ? YmColors.successContainer.withOpacity(0.4) : YmColors.surfaceContainer),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text, style: YmTextStyles.labelSm.copyWith(color: running ? YmColors.onSuccessSoft : YmColors.textMuted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Warna untuk metode HTTP dan kode status (dipakai di tabel history).
Color methodColor(String m) {
  switch (m.toUpperCase()) {
    case 'GET':
      return const Color(0xFF2563EB);
    case 'POST':
      return const Color(0xFF16A34A);
    case 'PUT':
    case 'PATCH':
      return const Color(0xFFD97706);
    case 'DELETE':
      return const Color(0xFFDC2626);
    default:
      return YmColors.textMuted;
  }
}

Color statusColor(int s) {
  if (s >= 500) return const Color(0xFFDC2626);
  if (s >= 400) return const Color(0xFFD97706);
  if (s >= 300) return const Color(0xFF7C3AED);
  if (s >= 200) return const Color(0xFF16A34A);
  return YmColors.textMuted;
}
