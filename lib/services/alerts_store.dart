import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'episode_alerts.dart';

enum AlertToggleResult { enabled, disabled, permissionDenied }

/// Estado de los avisos de episodios nuevos para la interfaz.
class AlertsStore extends ChangeNotifier {
  AlertsStore(this._prefs) : _ids = EpisodeAlerts.subscribed(_prefs);

  final SharedPreferences _prefs;
  Set<String> _ids;

  bool isOn(String programId) => _ids.contains(programId);
  int get count => _ids.length;

  Future<AlertToggleResult> toggle(String programId) async {
    final next = {..._ids};
    if (next.contains(programId)) {
      next.remove(programId);
      await _save(next);
      return AlertToggleResult.disabled;
    }
    if (!await EpisodeAlerts.requestPermission()) return AlertToggleResult.permissionDenied;
    next.add(programId);
    await _save(next);
    return AlertToggleResult.enabled;
  }

  Future<AlertToggleResult> setAll(Iterable<String> programIds, bool on) async {
    if (on && !await EpisodeAlerts.requestPermission()) return AlertToggleResult.permissionDenied;
    await _save(on ? programIds.toSet() : <String>{});
    return on ? AlertToggleResult.enabled : AlertToggleResult.disabled;
  }

  Future<void> _save(Set<String> ids) async {
    _ids = ids;
    notifyListeners();
    await EpisodeAlerts.setSubscribed(_prefs, ids);
  }
}
