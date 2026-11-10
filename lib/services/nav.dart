import 'package:flutter/foundation.dart';

/// Navigasi antar halaman di dalam shell.
class Nav {
  static final ValueNotifier<String> page = ValueNotifier('dashboard');
  static void go(String id) => page.value = id;
}
