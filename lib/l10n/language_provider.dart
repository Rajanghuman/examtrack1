import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's current language and persists the choice across
/// app restarts. Wrapped around the whole app in main.dart via
/// ChangeNotifierProvider, so any widget can read/change it with
/// Provider.of<LanguageProvider>(context) or context.watch/read.
class LanguageProvider extends ChangeNotifier {
  static const String _prefsKey = 'app_language';

  // 'en' or 'hi' — matches AppStrings' map keys directly.
  String _languageCode = 'en';

  String get languageCode => _languageCode;
  bool get isHindi => _languageCode == 'hi';

  /// Call once at app startup (see main.dart) to load any previously
  /// saved choice before the first frame renders.
  Future<void> loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == 'hi' || saved == 'en') {
        _languageCode = saved!;
        notifyListeners();
      }
    } catch (e) {
      // If prefs fail to load for any reason, silently keep the
      // default ('en') rather than crashing startup.
    }
  }

  /// Switch language and persist the choice. Pass 'en' or 'hi'.
  Future<void> setLanguage(String code) async {
    if (code != 'en' && code != 'hi') return;
    if (_languageCode == code) return; // no-op, avoid extra rebuilds

    _languageCode = code;
    notifyListeners(); // triggers rebuild of every widget watching this

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    } catch (e) {
      // Saving failed — language still switched for this session,
      // just won't persist after app restart. Not worth crashing over.
    }
  }

  void toggleLanguage() {
    setLanguage(_languageCode == 'en' ? 'hi' : 'en');
  }
}
