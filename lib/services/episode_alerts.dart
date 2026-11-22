import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../config/app_config.dart';
import '../models/episode.dart';
import 'feed_parser.dart';

/// Identificador de la tarea periódica. En iOS debe coincidir con
/// `BGTaskSchedulerPermittedIdentifiers` de `Info.plist`.
const episodeAlertsTask = 'eus.euskadigital.app.newEpisodes';

/// Cada cuánto se pide al sistema revisar los feeds. Es orientativo: Android
/// lo respeta aproximadamente; iOS decide según el uso que se haga de la app.
const _checkEvery = Duration(hours: 3);

/// Punto de entrada de la tarea en segundo plano (isolate aparte).
@pragma('vm:entry-point')
void episodeAlertsDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final config = await AppConfig.load();
      final prefs = await SharedPreferences.getInstance();
      await EpisodeAlerts.initNotifications();
      await EpisodeAlerts.checkNow(config: config, prefs: prefs);
    } catch (e) {
      debugPrint('Error revisando episodios nuevos: $e');
    }
    return true;
  });
}

/// Avisos de episodios nuevos: suscripciones por programa, comprobación en
/// segundo plano y notificaciones locales (sin servidor).
class EpisodeAlerts {
  EpisodeAlerts._();

  static const _channelId = 'new_episodes';
  static const _kPrograms = 'alerts.programs';
  static String _kLatest(String programId) => 'alerts.latest.$programId';

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Programa a abrir al pulsar una notificación (lo escucha la UI).
  static final pendingProgram = ValueNotifier<String?>(null);

  // ------------------------------------------------------- notificaciones

  static Future<void> initNotifications() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) => pendingProgram.value = r.payload,
    );
  }

  /// Si la app se abrió pulsando una notificación, devuelve el programa.
  static Future<String?> launchProgram() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) return details!.notificationResponse?.payload;
    return null;
  }

  static Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    return false;
  }

  static Future<void> _notify({
    required int id,
    required String title,
    required String body,
    required String programId,
  }) =>
      _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Episodios nuevos',
            channelDescription: 'Aviso cuando un programa publica un episodio',
            importance: Importance.defaultImportance,
            color: Color(0xFFFC0001),
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: programId,
      );

  // --------------------------------------------------------- suscripciones

  static Set<String> subscribed(SharedPreferences prefs) =>
      (prefs.getStringList(_kPrograms) ?? const []).toSet();

  static Future<void> setSubscribed(SharedPreferences prefs, Set<String> ids) async {
    await prefs.setStringList(_kPrograms, ids.toList());
    await syncSchedule(prefs);
  }

  /// Programa o cancela la tarea periódica según haya suscripciones.
  static Future<void> syncSchedule(SharedPreferences prefs) async {
    try {
      if (subscribed(prefs).isEmpty) {
        await Workmanager().cancelByUniqueName(episodeAlertsTask);
      } else {
        await Workmanager().registerPeriodicTask(
          episodeAlertsTask,
          episodeAlertsTask,
          frequency: _checkEvery,
          initialDelay: _checkEvery,
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        );
      }
    } catch (e) {
      debugPrint('No se ha podido programar la revisión de episodios: $e');
    }
  }

  // ------------------------------------------------------------ revisión

  /// Fecha del episodio más reciente conocido de un programa.
  static DateTime? _latestOf(Iterable<Episode> items) {
    DateTime? latest;
    for (final e in items) {
      if (!e.hasAudio || e.pubDate == null) continue;
      if (latest == null || e.pubDate!.isAfter(latest)) latest = e.pubDate;
    }
    return latest;
  }

  /// La app ha cargado un feed en primer plano: lo que ya se ha visto no
  /// debe notificarse después.
  static Future<void> rememberSeen(SharedPreferences prefs, String programId, List<Episode> items) async {
    final latest = _latestOf(items);
    if (latest == null) return;
    await prefs.reload();
    final stored = DateTime.tryParse(prefs.getString(_kLatest(programId)) ?? '');
    if (stored == null || latest.isAfter(stored)) {
      await prefs.setString(_kLatest(programId), latest.toIso8601String());
    }
  }

  /// Descarga los feeds suscritos y notifica los episodios nuevos.
  /// Devuelve cuántos episodios nuevos se han encontrado.
  static Future<int> checkNow({
    required AppConfig config,
    required SharedPreferences prefs,
    http.Client? client,
  }) async {
    await prefs.reload();
    final ids = subscribed(prefs);
    final c = client ?? http.Client();
    var total = 0;
    for (final program in config.allPrograms.where((p) => ids.contains(p.id))) {
      try {
        final res = await c.get(Uri.parse(program.feedUrl), headers: {
          'User-Agent': 'EuskaDigitalApp/1.0 (+https://www.euskadigital.eus)',
        }).timeout(const Duration(seconds: 25));
        if (res.statusCode != 200) continue;
        final body = res.body;
        final feed = FeedParser.parse(body, feedId: program.id);
        final found = newEpisodes(prefs, program.id, feed.items);
        await _saveFeedCache(program.id, body);
        if (found.isEmpty) continue;
        total += found.length;
        await _notify(
          id: program.id.hashCode & 0x7fffffff,
          title: found.length == 1 ? 'Nuevo episodio de ${program.title}' : '${found.length} episodios nuevos de ${program.title}',
          body: found.first.title,
          programId: program.id,
        );
      } catch (e) {
        debugPrint('Aviso: no se ha podido revisar ${program.id}: $e');
      }
    }
    return total;
  }

  /// Episodios posteriores al último conocido (más recientes primero) y
  /// actualiza la referencia. La primera vez solo guarda la referencia.
  @visibleForTesting
  static List<Episode> newEpisodes(SharedPreferences prefs, String programId, List<Episode> items) {
    final latest = _latestOf(items);
    if (latest == null) return const [];
    final key = _kLatest(programId);
    final stored = DateTime.tryParse(prefs.getString(key) ?? '');
    prefs.setString(key, (stored != null && stored.isAfter(latest) ? stored : latest).toIso8601String());
    if (stored == null) return const [];
    final fresh = items.where((e) => e.hasAudio && e.pubDate != null && e.pubDate!.isAfter(stored)).toList()
      ..sort((a, b) => b.pubDate!.compareTo(a.pubDate!));
    return fresh;
  }

  /// Guarda el feed donde lo busca FeedRepository, para que al abrir la app
  /// el episodio nuevo ya aparezca aunque no haya conexión.
  static Future<void> _saveFeedCache(String feedId, String body) async {
    try {
      final dir = Directory('${(await getApplicationSupportDirectory()).path}/feeds');
      if (!await dir.exists()) await dir.create(recursive: true);
      await File('${dir.path}/$feedId.xml').writeAsString(body);
    } catch (_) {}
  }
}
