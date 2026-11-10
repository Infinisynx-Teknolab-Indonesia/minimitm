import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dua bahasa: Indonesia ('id') & English ('en').
class L extends ChangeNotifier {
  L._();
  static final L instance = L._();
  String lang = 'id';

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      lang = sp.getString('lang') ?? 'id';
    } catch (_) {}
  }

  Future<void> set(String v) async {
    if (v == lang) return;
    lang = v;
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('lang', v);
    } catch (_) {}
  }

  void toggle() => set(lang == 'id' ? 'en' : 'id');
}

/// Pilih teks sesuai bahasa aktif. tr('Indonesia', 'English').
String tr(String id, String en) => L.instance.lang == 'en' ? en : id;
