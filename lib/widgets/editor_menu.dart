import 'package:flutter/material.dart';

/// Satu aksi tambahan untuk menu klik-kanan editor.
class EditAction {
  final String label;
  final VoidCallback onTap;
  const EditAction(this.label, this.onTap);
}

/// contextMenuBuilder untuk TextField DAN SelectableText.
/// Di Flutter, SelectableText juga memakai EditableTextState (teks read-only),
/// jadi satu fungsi ini dipakai untuk keduanya.
/// Menyisipkan aksi kustom (mis. "Tanya AI") DI ATAS menu bawaan (Cut/Copy/Paste).
Widget Function(BuildContext, EditableTextState) editableMenu(List<EditAction> extra) {
  return (context, state) {
    final items = List<ContextMenuButtonItem>.from(state.contextMenuButtonItems);
    for (final a in extra.reversed) {
      items.insert(
        0,
        ContextMenuButtonItem(
          label: a.label,
          onPressed: () {
            ContextMenuController.removeAny();
            a.onTap();
          },
        ),
      );
    }
    return AdaptiveTextSelectionToolbar.buttonItems(anchors: state.contextMenuAnchors, buttonItems: items);
  };
}
