import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';

class LocaleProvider with ChangeNotifier {
  Locale _locale = const Locale('vi');

  Locale get locale => _locale;

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(AppConstants.prefLocale) ?? 'vi';
    _locale = Locale(languageCode);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefLocale, locale.languageCode);
    notifyListeners();
  }

  bool get isVietnamese => _locale.languageCode == 'vi';

  void toggleLocale() {
    if (_locale.languageCode == 'vi') {
      setLocale(const Locale('en'));
    } else {
      setLocale(const Locale('vi'));
    }
  }
}
