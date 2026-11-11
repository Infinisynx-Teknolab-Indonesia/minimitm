import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/i18n.dart';

/// TextEditingController yang menandai (highlight) hasil pencarian.
/// Semua kecocokan berwarna kuning, kecocokan aktif berwarna oranye.
class HighlightController extends TextEditingController {
  HighlightController({super.text});

  String _q = '';
  bool _cs = false;
  String _cacheText = '';
  String _cacheQ = '';
  bool _cacheCs = false;
  List<int> _m = const [];
  int current = 0;

  String get query => _q;
  List<int> get matches {
    _ensure();
    return _m;
  }

  void setQuery(String q, bool caseSensitive) {
    _q = q;
    _cs = caseSensitive;
    current = 0;
    notifyListeners();
  }

  void step(int delta) {
    final n = matches.length;
    if (n == 0) return;
    current = (current + delta) % n;
    if (current < 0) current += n;
    notifyListeners();
  }

  void _ensure() {
    final t = text;
    if (_q.isEmpty) {
      _m = const [];
      _cacheQ = '';
      return;
    }
    if (t == _cacheText && _q == _cacheQ && _cs == _cacheCs) return;
    _cacheText = t;
    _cacheQ = _q;
    _cacheCs = _cs;
    var hay = t;
    var needle = _q;
    if (!_cs) {
      final lh = t.toLowerCase();
      // toLowerCase bisa mengubah panjang pada karakter langka -> jangan dipakai bila beda
      if (lh.length == t.length) {
        hay = lh;
        needle = _q.toLowerCase();
      }
    }
    final res = <int>[];
    var i = 0;
    while (res.length < 5000) {
      i = hay.indexOf(needle, i);
      if (i < 0) break;
      res.add(i);
      i += math.max(1, needle.length);
    }
    _m = res;
    if (current >= _m.length) current = 0;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    _ensure();
    if (_m.isEmpty) return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    final t = text;
    final spans = <InlineSpan>[];
    var pos = 0;
    for (var i = 0; i < _m.length; i++) {
      final s = _m[i];
      if (s < pos) continue;
      final e = math.min(t.length, s + _q.length);
      if (s > pos) spans.add(TextSpan(text: t.substring(pos, s)));
      spans.add(TextSpan(
        text: t.substring(s, e),
        style: TextStyle(backgroundColor: i == current ? const Color(0xFFFF9632) : const Color(0xFFFFE082), color: Colors.black),
      ));
      pos = e;
    }
    if (pos < t.length) spans.add(TextSpan(text: t.substring(pos)));
    return TextSpan(style: style, children: spans);
  }
}

/// Tampilan teks (baca-saja atau bisa diedit) dengan fitur Cari:
/// tombol kaca pembesar di pojok kanan atas atau Ctrl+F. Enter = berikutnya,
/// Shift+Enter = sebelumnya, Esc = tutup.
///
/// Pakai `text:` untuk tampilan baca-saja, atau `controller:` (HighlightController)
/// untuk editor yang bisa diedit.
class FindableView extends StatefulWidget {
  final String? text;
  final HighlightController? controller;
  final bool readOnly;
  final Widget Function(BuildContext, EditableTextState)? contextMenuBuilder;
  const FindableView({super.key, this.text, this.controller, this.readOnly = true, this.contextMenuBuilder})
      : assert(text != null || controller != null);

  @override
  State<FindableView> createState() => _FindableViewState();
}

class _FindableViewState extends State<FindableView> {
  late HighlightController _c;
  bool _ownsC = false;
  final _scroll = ScrollController();
  final _qC = TextEditingController();
  final _qFocus = FocusNode();
  final _viewFocus = FocusNode();
  bool _show = false;
  bool _case = false;
  double _w = 600, _h = 300;

  static const _pad = 14.0;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    if (widget.controller != null) {
      _c = widget.controller!;
      _ownsC = false;
    } else {
      _c = HighlightController(text: widget.text ?? '');
      _ownsC = true;
    }
    _c.addListener(_onCtl);
  }

  void _onCtl() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant FindableView old) {
    super.didUpdateWidget(old);
    if (widget.controller != old.controller) {
      _c.removeListener(_onCtl);
      if (_ownsC) _c.dispose();
      _bind();
    } else if (_ownsC && widget.text != null && widget.text != _c.text) {
      _c.text = widget.text!;
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onCtl);
    if (_ownsC) _c.dispose();
    _scroll.dispose();
    _qC.dispose();
    _qFocus.dispose();
    _viewFocus.dispose();
    super.dispose();
  }

  void _open() {
    setState(() => _show = true);
    // isi otomatis dengan teks yang sedang dipilih
    final sel = _c.selection;
    if (sel.isValid && !sel.isCollapsed) {
      final picked = _c.text.substring(sel.start, sel.end);
      if (picked.isNotEmpty && !picked.contains('\n')) {
        _qC.text = picked;
        _qC.selection = TextSelection(baseOffset: 0, extentOffset: picked.length);
        _c.setQuery(picked, _case);
        _reveal();
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _qFocus.requestFocus();
    });
  }

  void _close() {
    _c.setQuery('', _case);
    setState(() => _show = false);
    _viewFocus.requestFocus();
  }

  void _onQuery(String q) {
    _c.setQuery(q, _case);
    _reveal();
  }

  void _step(int d) {
    _c.step(d);
    _reveal();
  }

  /// Gulung ke kecocokan aktif (posisi dihitung dengan TextPainter yang gayanya sama).
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final m = _c.matches;
      if (!mounted || m.isEmpty || !_scroll.hasClients) return;
      final tp = TextPainter(text: TextSpan(text: _c.text, style: YmTextStyles.mono), textDirection: TextDirection.ltr)
        ..layout(maxWidth: math.max(50.0, _w - _pad * 2));
      final dy = tp.getOffsetForCaret(TextPosition(offset: m[_c.current]), Rect.zero).dy;
      tp.dispose();
      final target = (dy - _h / 3).clamp(0.0, _scroll.position.maxScrollExtent).toDouble();
      _scroll.animateTo(target, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = _c.matches.length;
    final hasQ = _c.query.isNotEmpty;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _open,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _open,
        const SingleActivator(LogicalKeyboardKey.f3): () => _step(1),
        const SingleActivator(LogicalKeyboardKey.f3, shift: true): () => _step(-1),
        if (_show) const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Column(
        children: [
          if (_show)
            Container(
              color: YmColors.surfaceAlt,
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
              child: Row(children: [
                Icon(Icons.search_rounded, size: 18, color: YmColors.outline),
                const SizedBox(width: 8),
                SizedBox(
                  width: 260,
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.enter, shift: true): () => _step(-1),
                    },
                    child: TextField(
                      controller: _qC,
                      focusNode: _qFocus,
                      autofocus: true,
                      style: YmTextStyles.bodySm.copyWith(color: YmColors.textDark),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: tr('Cari di sini…', 'Find in text…'),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: _onQuery,
                      onSubmitted: (_) {
                        _step(1);
                        _qFocus.requestFocus();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  !hasQ ? '' : (n == 0 ? tr('Tidak ada', 'No results') : '${_c.current + 1} / $n${n >= 5000 ? '+' : ''}'),
                  style: YmTextStyles.labelSm,
                ),
                const Spacer(),
                Tooltip(
                  message: tr('Bedakan huruf besar/kecil', 'Match case'),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      setState(() => _case = !_case);
                      _onQuery(_qC.text);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _case ? YmColors.surfaceHigh : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _case ? YmColors.primary : YmColors.line),
                      ),
                      child: Text('Aa', style: YmTextStyles.labelSm.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: tr('Sebelumnya (Shift+Enter)', 'Previous (Shift+Enter)'),
                  visualDensity: VisualDensity.compact,
                  onPressed: n == 0 ? null : () => _step(-1),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
                IconButton(
                  tooltip: tr('Berikutnya (Enter)', 'Next (Enter)'),
                  visualDensity: VisualDensity.compact,
                  onPressed: n == 0 ? null : () => _step(1),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
                IconButton(
                  tooltip: tr('Tutup (Esc)', 'Close (Esc)'),
                  visualDensity: VisualDensity.compact,
                  onPressed: _close,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ]),
            ),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              _w = box.maxWidth;
              _h = box.maxHeight;
              return Stack(children: [
                Positioned.fill(
                  child: TextField(
                    controller: _c,
                    focusNode: _viewFocus,
                    scrollController: _scroll,
                    readOnly: widget.readOnly,
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style: YmTextStyles.mono,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.all(_pad),
                    ),
                    contextMenuBuilder: widget.contextMenuBuilder,
                  ),
                ),
                if (!_show)
                  Positioned(
                    top: 6,
                    right: 18,
                    child: Tooltip(
                      message: tr('Cari (Ctrl+F)', 'Find (Ctrl+F)'),
                      child: Material(
                        color: YmColors.surface.withOpacity(0.92),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: YmColors.line)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _open,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(Icons.search_rounded, size: 18, color: YmColors.primary),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]);
            }),
          ),
        ],
      ),
    );
  }
}
