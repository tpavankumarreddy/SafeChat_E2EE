import 'package:emailchat/themes/light_mode.dart';
import 'package:flutter/material.dart';
import 'darkmode.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeData _themeData = lightMode;

  ThemeData get themedata =>_themeData;

  bool get isDarkmode => _themeData == darkMode;

  set themeData(ThemeData themeData) {
    _themeData = themeData;
    notifyListeners();

  }
  void toggleTheme() {
    if (_themeData == lightMode) {
      themeData = darkMode;
    }else{
      themeData = lightMode;

    }
  }
}