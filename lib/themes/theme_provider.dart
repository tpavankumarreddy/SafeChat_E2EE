import 'package:flutter/material.dart';

import 'darkmode.dart';
import 'light_mode.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeData _themeData = lightMode;
  ColorScheme? _dynamicColorScheme;

  ThemeData get themedata {
    if (_dynamicColorScheme != null) {
      return ThemeData(
        colorScheme: _dynamicColorScheme!,
        useMaterial3: true,
      );
    }
    return _themeData;
  }

  bool get isDarkmode => _themeData == darkMode;

  void setDynamicColorScheme(ColorScheme? colorScheme) {
    _dynamicColorScheme = colorScheme;
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeData == lightMode) {
      _themeData = darkMode;
    } else {
      _themeData = lightMode;
    }
    notifyListeners();
  }
}
