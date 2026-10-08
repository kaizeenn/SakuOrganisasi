import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

// Key for SharedPreferences
const _kThemeKey = 'theme_mode';

// Provider storing the current ThemeMode
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_kThemeKey);
    if (index != null && index >= 0 && index < ThemeMode.values.length) {
      state = ThemeMode.values[index];
    } else {
      state = ThemeMode.light;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeKey, mode.index);
  }
}

/// Re-export design system themes untuk kompatibilitas.
class AppThemeLegacy {
  static ThemeData get lightTheme => AppTheme.light;
  static ThemeData get darkTheme => AppTheme.dark;
}
