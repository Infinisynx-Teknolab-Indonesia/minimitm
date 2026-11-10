import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================================
///  TEMA APLIKASI  (dipindah dari ArsipDokumenPU, disesuaikan untuk MITM Proxy)
///  Semua warna diambil dari [AppPalette] yang aktif. Pilihan disimpan di PC ini.
/// ============================================================================
class AppPalette {
  final String id;
  final String name;
  final String note;
  final bool dark;
  final Color primary;
  final Color onPrimary;
  final Color primaryDeep;
  final Color primarySoft;
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceContainer;
  final Color surfaceHigh;
  final Color sidebar;
  final Color outline;
  final Color line;
  final Color text;
  final Color muted;
  final Color link;
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color successSoft;
  final Color warningSoft;
  final Color dangerSoft;
  final Color? primaryContainer;
  final Color? onPrimaryContainer;
  final Color? primaryFixed;
  final Color? onPrimaryFixed;
  final Color? onSuccessSoft;
  final Color? successContainer;
  final Color? onWarningSoft;
  final Color? onDangerSoft;
  final Color? outlineVariant;
  final Color? inverseSurface;
  final Color? inversePrimary;
  final Color? warningDim;

  const AppPalette({
    required this.id,
    required this.name,
    required this.note,
    this.dark = false,
    required this.primary,
    this.onPrimary = Colors.white,
    required this.primaryDeep,
    required this.primarySoft,
    required this.bg,
    this.surface = Colors.white,
    required this.surfaceAlt,
    required this.surfaceContainer,
    required this.surfaceHigh,
    required this.sidebar,
    required this.line,
    required this.text,
    required this.muted,
    required this.outline,
    Color? link,
    required this.accent,
    this.success = const Color(0xFF006C4A),
    this.warning = const Color(0xFF6E3900),
    this.danger = const Color(0xFFBA1A1A),
    this.successSoft = const Color(0xFFCDFBE6),
    this.warningSoft = const Color(0xFFFFDCC3),
    this.dangerSoft = const Color(0xFFFFDAD6),
    this.primaryContainer,
    this.onPrimaryContainer,
    this.primaryFixed,
    this.onPrimaryFixed,
    this.onSuccessSoft,
    this.successContainer,
    this.onWarningSoft,
    this.onDangerSoft,
    this.outlineVariant,
    this.inverseSurface,
    this.inversePrimary,
    this.warningDim,
  }) : link = link ?? primary;
}

final appPalettes = <AppPalette>[
  AppPalette(
    id: 'indigo',
    name: 'Indigo',
    note: 'Bawaan - biru indigo',
    primary: Color(0xFF293CA0),
    primaryDeep: Color(0xFF1A2670),
    primarySoft: Color(0xFFDEE0FF),
    bg: Color(0xFFF8F9FF),
    surfaceAlt: Color(0xFFEFF4FF),
    surfaceContainer: Color(0xFFE5EEFF),
    surfaceHigh: Color(0xFFD3E4FE),
    sidebar: Color(0xFFF3F6FF),
    line: Color(0xFFDDE3F0),
    text: Color(0xFF0B1C30),
    muted: Color(0xFF454652),
    outline: Color(0xFF757684),
    accent: Color(0xFF4355B9),
    primaryContainer: Color(0xFF4355B9),
    onPrimaryContainer: Color(0xFFD1D6FF),
    primaryFixed: Color(0xFFDEE0FF),
    onPrimaryFixed: Color(0xFF00105C),
    onSuccessSoft: Color(0xFF005137),
    successContainer: Color(0xFF82F5C1),
    onWarningSoft: Color(0xFF2F1500),
    onDangerSoft: Color(0xFF93000A),
    outlineVariant: Color(0xFFC5C5D4),
    inverseSurface: Color(0xFF213145),
    inversePrimary: Color(0xFFBAC3FF),
    warningDim: Color(0xFFFFB77D),
  ),
  AppPalette(
    id: 'zamrud',
    name: 'Zamrud',
    note: 'Hijau teduh, nyaman kerja lama',
    primary: Color(0xFF0E7A5A),
    primaryDeep: Color(0xFF0A3B2C),
    primarySoft: Color(0xFFD5F0E5),
    bg: Color(0xFFF6F9F7),
    surfaceAlt: Color(0xFFEDF5F1),
    surfaceContainer: Color(0xFFE2EFE9),
    surfaceHigh: Color(0xFFD0E8DD),
    sidebar: Color(0xFFF0F6F3),
    line: Color(0xFFDCE7E2),
    text: Color(0xFF10201A),
    muted: Color(0xFF45534D),
    outline: Color(0xFF6C7A74),
    accent: Color(0xFFE0A100),
  ),
  AppPalette(
    id: 'grafit',
    name: 'Grafit',
    note: 'Hitam-putih tegas',
    primary: Color(0xFF15181F),
    primaryDeep: Color(0xFF0B0D12),
    primarySoft: Color(0xFFE7E8EB),
    bg: Color(0xFFF8F8F9),
    surfaceAlt: Color(0xFFF2F3F5),
    surfaceContainer: Color(0xFFEAEBEE),
    surfaceHigh: Color(0xFFE0E2E6),
    sidebar: Color(0xFFF4F4F6),
    line: Color(0xFFE3E5E9),
    text: Color(0xFF111318),
    muted: Color(0xFF4B5160),
    outline: Color(0xFF6B7280),
    link: Color(0xFF2563EB),
    accent: Color(0xFF2563EB),
  ),
  AppPalette(
    id: 'malam',
    name: 'Malam',
    note: 'Gelap, hemat mata',
    dark: true,
    primary: Color(0xFF7385F7),
    primaryDeep: Color(0xFF070A12),
    primarySoft: Color(0xFF232B5A),
    bg: Color(0xFF0B0F1A),
    surface: Color(0xFF131929),
    surfaceAlt: Color(0xFF182033),
    surfaceContainer: Color(0xFF1D263C),
    surfaceHigh: Color(0xFF253153),
    sidebar: Color(0xFF0F1424),
    line: Color(0xFF252E46),
    text: Color(0xFFE6E9F2),
    muted: Color(0xFFB2B8CA),
    outline: Color(0xFF8189A0),
    link: Color(0xFF94A2FF),
    accent: Color(0xFF94A2FF),
    success: Color(0xFF4ADE9F),
    warning: Color(0xFFFBBF6A),
    danger: Color(0xFFFF8A80),
    successSoft: Color(0xFF123B2E),
    warningSoft: Color(0xFF3D2A12),
    dangerSoft: Color(0xFF441B1B),
  ),
];

class ThemeCtl extends ChangeNotifier {
  ThemeCtl._();
  static final ThemeCtl instance = ThemeCtl._();

  AppPalette palette = appPalettes.first;
  int generation = 0;

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final id = sp.getString('theme_id') ?? 'indigo';
      palette = appPalettes.firstWhere((p) => p.id == id, orElse: () => appPalettes.first);
    } catch (_) {}
  }

  Future<void> set(String id) async {
    final p = appPalettes.firstWhere((e) => e.id == id, orElse: () => appPalettes.first);
    if (p.id == palette.id) return;
    palette = p;
    generation++;
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('theme_id', id);
    } catch (_) {}
  }
}

class YmColors {
  YmColors._();
  static AppPalette get _p => ThemeCtl.instance.palette;
  static bool get isDark => _p.dark;

  static Color get primary => _p.primary;
  static Color get onPrimary => _p.onPrimary;
  static Color get primarySoft => _p.primarySoft;
  static Color get primaryDeep => _p.primaryDeep;
  static Color get paper => _p.bg;
  static Color get surface => _p.surface;
  static Color get surfaceAlt => _p.surfaceAlt;
  static Color get surfaceContainer => _p.surfaceContainer;
  static Color get surfaceHigh => _p.surfaceHigh;
  static Color get surfaceContainerHigh => Color.lerp(_p.surfaceContainer, _p.surfaceHigh, 0.5)!;
  static Color get sidebar => _p.sidebar;
  static Color get outline => _p.outline;
  static Color get successSoft => _p.successSoft;
  static Color get warningSoft => _p.warningSoft;
  static Color get dangerSoft => _p.dangerSoft;

  static Color get primaryContainer => _p.primaryContainer ?? Color.lerp(_p.primary, Colors.white, 0.14)!;
  static Color get onPrimaryContainer => _p.onPrimaryContainer ?? Colors.white.withOpacity(0.78);
  static Color get primaryFixed => _p.primaryFixed ?? _p.primarySoft;
  static Color get onPrimaryFixed => _p.onPrimaryFixed ?? (_p.dark ? Colors.white : Color.lerp(_p.primary, Colors.black, 0.55)!);
  static Color get onSuccessSoft => _p.onSuccessSoft ?? (_p.dark ? _p.success : Color.lerp(_p.success, Colors.black, 0.25)!);
  static Color get successContainer => _p.successContainer ?? (_p.dark ? const Color(0xFF14533F) : const Color(0xFF82F5C1));
  static Color get onSuccessContainer => _p.dark ? _p.success : const Color(0xFF00714E);
  static Color get onWarningSoft => _p.onWarningSoft ?? (_p.dark ? _p.warning : const Color(0xFF2F1500));
  static Color get onDangerSoft => _p.onDangerSoft ?? (_p.dark ? _p.danger : const Color(0xFF93000A));
  static Color get outlineVariant => _p.outlineVariant ?? Color.lerp(_p.line, _p.outline, 0.35)!;
  static Color get inverseSurface => _p.inverseSurface ?? (_p.dark ? const Color(0xFFE6E9F2) : const Color(0xFF213145));
  static Color get line => _p.line;
  static Color get link => _p.link;
  static Color get accent => _p.accent;
  static Color get success => _p.success;
  static Color get warning => _p.warning;
  static Color get danger => _p.danger;
  static Color get textDark => _p.text;
  static Color get textMuted => _p.muted;
}

const kFont = 'Inter';
const kFontDisplay = 'PlusJakartaSans';
const kFontFallback = ['Segoe UI', 'Arial'];

class YmTextStyles {
  YmTextStyles._();

  static TextStyle get display => TextStyle(
      fontFamily: kFontDisplay, fontFamilyFallback: kFontFallback, fontSize: 32, height: 40 / 32, fontWeight: FontWeight.w700, letterSpacing: -0.64, color: YmColors.textDark);
  static TextStyle get headlineMd => TextStyle(
      fontFamily: kFontDisplay, fontFamilyFallback: kFontFallback, fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: YmColors.textDark);
  static TextStyle get headlineSm => TextStyle(
      fontFamily: kFontDisplay, fontFamilyFallback: kFontFallback, fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600, color: YmColors.textDark);
  static TextStyle get sectionTitle => headlineMd;
  static TextStyle get pageTitle => display;
  static TextStyle get bigNumber => display;

  static TextStyle get labelLg =>
      TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500, color: YmColors.textDark);
  static TextStyle get labelMd => TextStyle(
      fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, letterSpacing: 0.12, color: YmColors.textDark);
  static TextStyle get labelSm => TextStyle(
      fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w600, letterSpacing: 0.22, color: YmColors.textMuted);
  static TextStyle get bodyMd => TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 14, height: 22 / 14, color: YmColors.textMuted);
  static TextStyle get bodySm => TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 12, height: 18 / 12, color: YmColors.textMuted);
  static TextStyle get label =>
      TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 11.5, color: YmColors.textMuted, height: 1.35);
  static TextStyle get mono =>
      TextStyle(fontFamily: 'monospace', fontFamilyFallback: const ['Consolas', 'Menlo', 'monospace'], fontSize: 12.5, height: 1.5, color: YmColors.textDark);
}

const ymBorderRadius = 12.0;
const kMotion = Duration(milliseconds: 320);
const kMotionCurve = Curves.easeOutCubic;

Duration motion(BuildContext context, [Duration d = kMotion]) =>
    MediaQuery.maybeOf(context)?.disableAnimations == true ? Duration.zero : d;
bool reduceMotion(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations == true;

List<BoxShadow> get shadowSm => YmColors.isDark ? const [] : const [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))];
List<BoxShadow> get shadowMd => YmColors.isDark
    ? const []
    : const [
        BoxShadow(color: Color(0x1A000000), blurRadius: 6, spreadRadius: -1, offset: Offset(0, 4)),
        BoxShadow(color: Color(0x1A000000), blurRadius: 4, spreadRadius: -2, offset: Offset(0, 2)),
      ];
List<BoxShadow> get softShadow => shadowSm;
List<BoxShadow> get hoverShadow => shadowMd;

ThemeData buildAppTheme() {
  final p = ThemeCtl.instance.palette;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.primary,
    brightness: p.dark ? Brightness.dark : Brightness.light,
    primary: p.primary,
    onPrimary: p.onPrimary,
    secondary: p.accent,
    surface: p.surface,
    onSurface: p.text,
    error: p.danger,
  );
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.line));
  final base = ThemeData(brightness: p.dark ? Brightness.dark : Brightness.light, useMaterial3: true);
  return ThemeData(
    useMaterial3: true,
    brightness: p.dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    fontFamily: kFont,
    fontFamilyFallback: kFontFallback,
    textTheme: base.textTheme.apply(fontFamily: kFont, bodyColor: p.text, displayColor: p.text),
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.surface,
    cardColor: p.surface,
    hoverColor: p.primary.withOpacity(0.05),
    splashColor: p.primary.withOpacity(0.08),
    highlightColor: Colors.transparent,
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: p.muted),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: TextStyle(color: p.muted, fontSize: 13),
      hintStyle: TextStyle(color: p.muted.withOpacity(0.8), fontSize: 13),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: p.primary, width: 1.6)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        backgroundColor: p.surface,
        side: BorderSide(color: p.line),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.link, textStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600, fontSize: 13)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.primary,
      unselectedLabelColor: p.muted,
      indicatorColor: p.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: p.line,
      labelStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w700, fontSize: 13.5),
      unselectedLabelStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w500, fontSize: 13.5),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : p.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : p.surfaceAlt),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : p.line),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(6),
      radius: const Radius.circular(6),
      thumbColor: WidgetStateProperty.all(p.muted.withOpacity(0.35)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: p.dark ? const Color(0xFF2A3247) : const Color(0xFF1B2033), borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontFamily: kFont, color: Colors.white, fontSize: 12),
      waitDuration: const Duration(milliseconds: 400),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.dark ? const Color(0xFF2A3247) : const Color(0xFF1B2033),
      contentTextStyle: const TextStyle(fontFamily: kFont, color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
