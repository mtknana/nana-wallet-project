import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// App-wide theme preference. Stored in the app documents directory so the
/// selected appearance survives restarts without adding another dependency.
class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();
  static const _fileName = 'appearance.json';
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    try {
      final file = await _preferenceFile();
      if (!await file.exists()) return;
      final value = (await file.readAsString()).trim();
      _themeMode = value == 'light' ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {
      // Use the secure, high-contrast dark appearance if storage is unavailable.
      _themeMode = ThemeMode.dark;
    }
  }

  Future<void> setDarkMode(bool enabled) async {
    final nextMode = enabled ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == nextMode) return;
    _themeMode = nextMode;
    notifyListeners();
    try {
      final file = await _preferenceFile();
      await file.writeAsString(enabled ? 'dark' : 'light', flush: true);
    } catch (_) {
      // The appearance still changes for this session if persistence fails.
    }
  }

  Future<File> _preferenceFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }
}
