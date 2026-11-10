import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CtxItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  const CtxItem(this.label, this.icon, this.onTap, {this.danger = false});
}

/// Tampilkan menu klik-kanan di posisi kursor.
Future<void> showCtxMenu(BuildContext context, Offset globalPos, List<CtxItem> items) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final picked = await showMenu<int>(
    context: context,
    position: RelativeRect.fromRect(globalPos & const Size(40, 40), Offset.zero & overlay.size),
    color: YmColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: YmColors.line)),
    items: [
      for (var i = 0; i < items.length; i++)
        PopupMenuItem<int>(
          value: i,
          height: 40,
          child: Row(children: [
            Icon(items[i].icon, size: 17, color: items[i].danger ? YmColors.danger : YmColors.textMuted),
            const SizedBox(width: 10),
            Text(items[i].label, style: YmTextStyles.labelMd.copyWith(color: items[i].danger ? YmColors.danger : YmColors.textDark)),
          ]),
        ),
    ],
  );
  if (picked != null) items[picked].onTap();
}
