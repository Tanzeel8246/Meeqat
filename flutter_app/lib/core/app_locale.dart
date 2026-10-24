import 'package:flutter/material.dart';

/// AppLocale - Centralized bilingual localization & typography management
/// Supports instant toggle between Urdu (with Jameel Noori Nastaleeq) and English.
class AppLocale {
  static final ValueNotifier<bool> isUrduNotifier = ValueNotifier<bool>(true);

  static bool get isUrdu => isUrduNotifier.value;

  static void toggle() {
    isUrduNotifier.value = !isUrduNotifier.value;
  }

  static void setUrdu(bool value) {
    isUrduNotifier.value = value;
  }

  static String get fontFamily => isUrdu ? 'Jameel Noori Nastaleeq' : 'Segoe UI';

  static TextDirection get textDirection => isUrdu ? TextDirection.rtl : TextDirection.ltr;

  static String t({required String ur, required String en}) {
    return isUrdu ? ur : en;
  }
}
