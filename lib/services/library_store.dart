import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/episode.dart';

/// Datos personales del usuario: favoritos, progreso, escuchados,
/// historial y descargas. Todo se guarda en el dispositivo.
class LibraryStore extends ChangeNotifier {
  LibraryStore(this._prefs) {
    _favorites = _readEpisodes('favorites');
    _history = _readEpisodes('history');
    _downloads = _readEpisodes('downloads');
    _downloadPaths = Map<String, String>.from(_readMap('downloadPaths'));
    _progress = _readMap('progress').map((k, v) => MapEntry(k, v as int));
    _played = (_prefs.getStringList('played') ?? const []).toSet();
  }

  static const _historyLimit = 100;

  final SharedPreferences _prefs;
  late Map<String, Episode> _favorites;
  late Map<String, Episode> _history; // orden de inserción = más antiguo primero
  late Map<String, Episode> _downloads;
  late Map<String, String> _downloadPaths;
  late Map<String, int> _progress; // segundos
  late Set<String> _played;

  // -------------------------------------------------------------- favoritos

  List<Episode> get favorites => _favorites.values.toList().reversed.toList();
  bool isFavorite(String id) => _favorites.containsKey(id);

  void toggleFavorite(Episode e) {
    if (_favorites.remove(e.id) == null) _favorites[e.id] = e;
    _writeEpisodes('favorites', _favorites);
    notifyListeners();
  }

  // --------------------------------------------------- progreso / escuchados

  Duration progressOf(String id) => Duration(seconds: _progress[id] ?? 0);
  bool isPlayed(String id) => _played.contains(id);

  /// Fracción escuchada (0–1) si se conoce la duración.
  double? fractionOf(Episode e) {
    if (isPlayed(e.id)) return 1;
    final p = _progress[e.id];
    final d = e.duration?.inSeconds;
    if (p == null || d == null || d == 0) return null;
    return (p / d).clamp(0, 1).toDouble();
  }

  void saveProgress(Episode e, Duration position, Duration? total) {
    final secs = position.inSeconds;
    final totalSecs = total?.inSeconds ?? e.duration?.inSeconds;
    if (totalSecs != null && totalSecs > 0 && secs >= totalSecs * 0.95) {
      markPlayed(e, played: true);
      return;
    }
    if (secs < 5) return;
    _progress[e.id] = secs;
    _prefs.setString('progress', jsonEncode(_progress));
    _addToHistory(e, notify: false);
    notifyListeners();
  }

  void markPlayed(Episode e, {required bool played}) {
    if (played) {
      _played.add(e.id);
      _progress.remove(e.id);
    } else {
      _played.remove(e.id);
    }
    _prefs.setStringList('played', _played.toList());
    _prefs.setString('progress', jsonEncode(_progress));
    notifyListeners();
  }

  /// Episodios empezados y sin terminar, más recientes primero.
  List<Episode> get inProgress => _history.values
      .where((e) => _progress.containsKey(e.id) && !_played.contains(e.id))
      .toList()
      .reversed
      .toList();

  // -------------------------------------------------------------- historial

  List<Episode> get history => _history.values.toList().reversed.toList();

  void _addToHistory(Episode e, {bool notify = true}) {
    _history.remove(e.id);
    _history[e.id] = e;
    while (_history.length > _historyLimit) {
      _history.remove(_history.keys.first);
    }
    _writeEpisodes('history', _history);
    if (notify) notifyListeners();
  }

  void addToHistory(Episode e) => _addToHistory(e);

  void clearHistory() {
    _history.clear();
    _writeEpisodes('history', _history);
    notifyListeners();
  }

  // -------------------------------------------------------------- descargas

  List<Episode> get downloads => _downloads.values.toList().reversed.toList();
  String? downloadPath(String id) => _downloadPaths[id];
  bool isDownloaded(String id) => _downloadPaths.containsKey(id);

  void registerDownload(Episode e, String path) {
    _downloads[e.id] = e;
    _downloadPaths[e.id] = path;
    _writeEpisodes('downloads', _downloads);
    _prefs.setString('downloadPaths', jsonEncode(_downloadPaths));
    notifyListeners();
  }

  void unregisterDownload(String id) {
    _downloads.remove(id);
    _downloadPaths.remove(id);
    _writeEpisodes('downloads', _downloads);
    _prefs.setString('downloadPaths', jsonEncode(_downloadPaths));
    notifyListeners();
  }

  // ---------------------------------------------------------------- helpers

  Map<String, Episode> _readEpisodes(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return {};
    try {
      final list = jsonDecode(raw) as List;
      return {
        for (final j in list)
          (j as Map<String, dynamic>)['id'] as String: Episode.fromJson(j)
      };
    } catch (_) {
      return {};
    }
  }

  void _writeEpisodes(String key, Map<String, Episode> map) =>
      _prefs.setString(key, jsonEncode([for (final e in map.values) e.toJson()]));

  Map<String, dynamic> _readMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
