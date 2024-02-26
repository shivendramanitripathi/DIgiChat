import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  ThemeData getTheme() {
    return _isDarkMode ? _darkTheme : _lightTheme;
  }

  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: ColorConstants.primaryColor,
    hintColor: ColorConstants.themeColor,
    scaffoldBackgroundColor: Colors.white,
  );

  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: ColorConstants.primaryColor,
    hintColor: ColorConstants.themeColor,
    scaffoldBackgroundColor: Colors.black,
    // Add more dark mode specific theme configurations here
  );
}

class ColorConstants {
  static const themeColor = Color(0xffdc1f1f);
  static const primaryColor = Color(0xff841742);
  static const greyColor = Color(0xffaeaeae);
  static const greyColor2 = Color(0xffE8E8E8);
}
