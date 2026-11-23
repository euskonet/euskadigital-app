import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'config/app_config.dart';
import 'services/alerts_store.dart';
import 'services/download_manager.dart';
import 'services/episode_alerts.dart';
import 'services/feed_repository.dart';
import 'services/library_store.dart';
import 'services/player_service.dart';
import 'services/settings_store.dart';
import 'services/twitch_live_service.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'eus.euskadigital.app.audio',
    androidNotificationChannelName: 'Reproducción',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'drawable/ic_stat_notification',
  );
  await initializeDateFormatting('es');

  final config = await AppConfig.load();
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsStore(prefs);
  final library = LibraryStore(prefs);
  final feeds = FeedRepository(
    config,
    // Lo que ya se ha visto en la app no se notifica después.
    onFeedLoaded: (id, feed) {
      if (config.programById(id) != null) EpisodeAlerts.rememberSeen(prefs, id, feed.items);
    },
  )..init();

  // Avisos de episodios nuevos (tarea en segundo plano + notificaciones).
  await Workmanager().initialize(episodeAlertsDispatcher);
  await EpisodeAlerts.initNotifications();
  await EpisodeAlerts.syncSchedule(prefs);
  EpisodeAlerts.pendingProgram.value ??= await EpisodeAlerts.launchProgram();

  runApp(MultiProvider(
    providers: [
      Provider.value(value: config),
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: library),
      ChangeNotifierProvider.value(value: feeds),
      ChangeNotifierProvider(create: (_) => AlertsStore(prefs)),
      if (config.twitch != null)
        ChangeNotifierProvider<TwitchLiveService?>(create: (_) => TwitchLiveService(config.twitch!.channel))
      else
        Provider<TwitchLiveService?>.value(value: null),
      ChangeNotifierProvider(create: (_) => DownloadManager(library, settings)),
      ChangeNotifierProvider(create: (_) => PlayerService(config, library, settings), lazy: false),
    ],
    child: const EuskaDigitalApp(),
  ));
}

class EuskaDigitalApp extends StatelessWidget {
  const EuskaDigitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsStore, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'EuskaDigital',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('eu')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppShell(),
    );
  }
}
