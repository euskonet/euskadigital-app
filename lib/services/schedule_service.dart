import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../config/app_config.dart';
import 'player_service.dart';

/// Un programa de la parrilla. Las horas están en hora de Madrid (la del
/// emisor), igual que en la web.
class ScheduleEntry {
  const ScheduleEntry({required this.name, required this.start, required this.end, this.program});

  final String name;
  final DateTime start;
  final DateTime end;

  /// Programa de la app al que corresponde, si lo hay.
  final ProgramConfig? program;

  bool isOnAirAt(DateTime now) => !now.isBefore(start) && now.isBefore(end);
}

/// Parrilla de programación del emisor (la misma fuente que la web), con el
/// mismo filtro: hoy y los próximos días, sin lo que ya ha terminado.
class ScheduleService extends ChangeNotifier {
  ScheduleService(this.config, this._prefs, {http.Client? client}) : _client = client ?? http.Client() {
    _restoreCache();
  }

  static const _cacheKey = 'schedule.cache';
  static const daysToShow = 4; // hoy + 3, como en la web

  final AppConfig config;
  final SharedPreferences _prefs;
  final http.Client _client;
  List<ScheduleEntry> _entries = const [];
  bool _loading = false;
  String? _error;

  List<ScheduleEntry> get entries => _entries;

  /// Carga una parrilla directamente (capturas y pruebas).
  @visibleForTesting
  void debugSetBody(String body) {
    _entries = parse(body, config.allPrograms);
    notifyListeners();
  }
  bool get loading => _loading;
  String? get error => _error;

  static tz.Location? _madrid;
  static tz.Location get madrid {
    if (_madrid == null) {
      tzdata.initializeTimeZones();
      _madrid = tz.getLocation('Europe/Madrid');
    }
    return _madrid!;
  }

  /// Hora actual en Madrid como fecha «sin zona», comparable con la parrilla.
  static DateTime nowInMadrid() {
    final n = tz.TZDateTime.now(madrid);
    return DateTime(n.year, n.month, n.day, n.hour, n.minute, n.second);
  }

  Future<void> refresh() async {
    final url = config.schedule?.url;
    if (url == null || _loading) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await _client.get(Uri.parse(url), headers: {'Accept': 'application/json'}).timeout(
        const Duration(seconds: 20),
      );
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final body = utf8.decode(res.bodyBytes);
      _entries = parse(body, config.allPrograms);
      _error = null;
      await _prefs.setString(_cacheKey, body);
    } catch (e) {
      debugPrint('Error cargando la parrilla: $e');
      _error = _entries.isEmpty
          ? 'No se ha podido cargar la parrilla. Revisa tu conexión.'
          : 'Mostrando la última parrilla guardada.';
    }
    _loading = false;
    notifyListeners();
  }

  void _restoreCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      _entries = parse(raw, config.allPrograms);
    } catch (_) {}
  }

  /// Días a mostrar (hoy + 3) con sus programas pendientes, en orden.
  Map<DateTime, List<ScheduleEntry>> upcomingByDay({DateTime? now}) => groupUpcoming(_entries, now ?? nowInMadrid());

  /// Lee el JSON del emisor: un objeto con una lista de programas por día
  /// (`monday`, `tuesday`… `nextsunday`) o directamente una lista.
  @visibleForTesting
  static List<ScheduleEntry> parse(String body, List<ProgramConfig> programs) {
    final raw = jsonDecode(body);
    final list = <Map<String, dynamic>>[];
    if (raw is List) {
      list.addAll(raw.whereType<Map<String, dynamic>>());
    } else if (raw is Map) {
      for (final v in raw.values) {
        if (v is List) list.addAll(v.whereType<Map<String, dynamic>>());
      }
    }
    DateTime? date(Map<String, dynamic> e, List<String> keys) {
      for (final k in keys) {
        final v = e[k];
        if (v is String && v.isNotEmpty) {
          final d = DateTime.tryParse(v.replaceFirst(' ', 'T'));
          if (d != null) return d;
        }
      }
      return null;
    }

    final entries = <ScheduleEntry>[];
    for (final e in list) {
      final start = date(e, ['starts', 'start_timestamp', 'start']);
      final end = date(e, ['ends', 'end_timestamp', 'end']);
      final name = (e['name'] ?? e['title'] ?? '').toString().trim();
      if (start == null || name.isEmpty) continue;
      entries.add(ScheduleEntry(
        name: name,
        start: start,
        end: end ?? start.add(const Duration(hours: 1)),
        program: PlayerService.matchProgram(name, programs),
      ));
    }
    entries.sort((a, b) => a.start.compareTo(b.start));

    // Bloques seguidos con el mismo nombre (p. ej. «Tracks Night» por horas)
    // se unen en uno.
    final merged = <ScheduleEntry>[];
    for (final e in entries) {
      final last = merged.isEmpty ? null : merged.last;
      if (last != null && last.name == e.name && !e.start.isAfter(last.end)) {
        merged[merged.length - 1] = ScheduleEntry(
          name: last.name,
          start: last.start,
          end: e.end.isAfter(last.end) ? e.end : last.end,
          program: last.program,
        );
      } else {
        merged.add(e);
      }
    }
    return merged;
  }

  /// Filtro de la web: hoy y los 3 días siguientes; de hoy, solo lo que aún
  /// no ha terminado. Agrupado por día.
  @visibleForTesting
  static Map<DateTime, List<ScheduleEntry>> groupUpcoming(List<ScheduleEntry> entries, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final days = [for (var i = 0; i < daysToShow; i++) DateTime(today.year, today.month, today.day + i)];
    final out = {for (final d in days) d: <ScheduleEntry>[]};
    for (final e in entries) {
      final day = DateTime(e.start.year, e.start.month, e.start.day);
      if (!out.containsKey(day)) continue;
      if (!e.end.isAfter(now)) continue; // ya terminado
      out[day]!.add(e);
    }
    return out;
  }
}
