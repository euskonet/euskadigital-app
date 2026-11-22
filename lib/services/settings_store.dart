import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias del usuario.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  ThemeMode get themeMode =>
      ThemeMode.values.byName(_prefs.getString('themeMode') ?? ThemeMode.system.name);
  set themeMode(ThemeMode v) {
    _prefs.setString('themeMode', v.name);
    notifyListeners();
  }

  bool get wifiOnlyDownloads => _prefs.getBool('wifiOnlyDownloads') ?? true;
  set wifiOnlyDownloads(bool v) {
    _prefs.setBool('wifiOnlyDownloads', v);
    notifyListeners();
  }

  double get playbackSpeed => _prefs.getDouble('playbackSpeed') ?? 1.0;
  set playbackSpeed(double v) {
    _prefs.setDouble('playbackSpeed', v);
    notifyListeners();
  }
}
