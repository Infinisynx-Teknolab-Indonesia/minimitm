import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/i18n.dart';

/// Deretan tab (gaya Burp): pilih, tambah (+), tutup (✕ / klik-kanan / klik-tengah).
class TabStrip extends StatelessWidget {
  final List<String> titles;
  final int active;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;
  final VoidCallback onAdd;
  const TabStrip({
    super.key,
    required this.titles,
    required this.active,
    required this.onSelect,
    required this.onClose,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: YmColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < titles.length; i++) _tab(context, i),
              ],
            ),
          ),
          Tooltip(
            message: tr('Tab baru', 'New tab'),
            child: InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.add_rounded, size: 20, color: YmColors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, int i) {
    final sel = i == active;
    return GestureDetector(
      onTap: () => onSelect(i),
      onTertiaryTapDown: (_) => onClose(i),   // klik-tengah = tutup
      onSecondaryTapDown: (_) => onClose(i),  // klik-kanan  = tutup
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 4, 0, 0),
        padding: const EdgeInsets.only(left: 12, right: 6),
        decoration: BoxDecoration(
          color: sel ? YmColors.surface : YmColors.surfaceAlt,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          border: Border.all(color: sel ? YmColors.primary.withOpacity(0.4) : YmColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: sel ? YmColors.primary : YmColors.outline, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(titles[i], maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: YmTextStyles.labelMd.copyWith(color: sel ? YmColors.textDark : YmColors.textMuted, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => onClose(i),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(Icons.close_rounded, size: 14, color: YmColors.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
