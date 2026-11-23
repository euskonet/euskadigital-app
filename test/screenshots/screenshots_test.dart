// Genera capturas de pantalla con datos de ejemplo:
//   flutter test test/screenshots --update-goldens --tags screenshots
// Las imágenes se guardan en test/screenshots/goldens/.
@Tags(['screenshots'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:euskadigital/config/app_config.dart';
import 'package:euskadigital/models/episode.dart';
import 'package:euskadigital/services/alerts_store.dart';
import 'package:euskadigital/services/download_manager.dart';
import 'package:euskadigital/services/feed_parser.dart';
import 'package:euskadigital/services/feed_repository.dart';
import 'package:euskadigital/services/library_store.dart';
import 'package:euskadigital/services/player_service.dart';
import 'package:euskadigital/services/settings_store.dart';
import 'package:euskadigital/services/twitch_live_service.dart';
import 'package:euskadigital/ui/app_shell.dart';
import 'package:euskadigital/ui/screens/home_screen.dart';
import 'package:euskadigital/ui/screens/player_screen.dart';
import 'package:euskadigital/ui/screens/twitch_screen.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'fake_webview.dart';
import 'package:euskadigital/ui/theme.dart';
import 'package:euskadigital/ui/widgets/net_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _store = bool.fromEnvironment('STORE');

/// Con --dart-define=REAL=true usa los feeds e imágenes reales descargados
/// con tool/descargar_datos_reales.py (test/screenshots/real_data/).
const _real = bool.fromEnvironment('REAL');
const _realDir = 'test/screenshots/real_data';

Future<void> _loadFonts() async {
  const dir = '/opt/sdk/flutter/bin/cache/artifacts/material_fonts';
  Future<ByteData> f(String name) async =>
      ByteData.view(Uint8List.fromList(File('$dir/$name').readAsBytesSync()).buffer);
  await (FontLoader('Roboto')
        ..addFont(f('Roboto-Regular.ttf'))
        ..addFont(f('Roboto-Medium.ttf'))
        ..addFont(f('Roboto-Bold.ttf'))
        ..addFont(f('Roboto-Black.ttf')))
      .load();
  await (FontLoader('MaterialIcons')..addFont(f('MaterialIcons-Regular.otf'))).load();
}

/// Datos de ejemplo (no reales) para ilustrar el diseño.
ParsedFeed _sample(ProgramConfig p, int seed) {
  final now = DateTime.now();
  const topics = [
    'Inteligencia artificial en el día a día',
    'Ciberseguridad para principiantes',
    'Lo mejor de la feria tecnológica',
    'Videojuegos retro y emulación',
    'Redes sociales y privacidad',
    'Entrevista: comunidad maker',
  ];
  return ParsedFeed(
    channel: FeedChannel(
      title: p.title,
      author: 'EuskaDigital',
      description:
          'Programa de tecnología y cultura digital de EuskaDigital. Actualidad, entrevistas y mucho más cada semana.',
    ),
    items: [
      for (var i = 0; i < 6; i++)
        Episode(
          id: '${p.id}-$i',
          feedId: p.id,
          title: '${p.title} ${120 - i}: ${topics[(i + seed) % topics.length]}',
          audioUrl: 'https://example.com/${p.id}/$i.mp3',
          pubDate: now.subtract(Duration(days: i * 7 + seed, hours: seed * 3)),
          duration: Duration(minutes: 38 + (i * 13 + seed * 7) % 50),
          description:
              '<p>En este episodio hablamos de <b>${topics[(i + seed) % topics.length].toLowerCase()}</b>.</p>',
        ),
    ],
  );
}

void main() {
  late AppConfig config;
  late SettingsStore settings;
  late LibraryStore library;
  late FeedRepository feeds;
  late PlayerService player;
  late SharedPreferences prefs;
  late TwitchLiveService twitchLive;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
    await initializeDateFormatting('es');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    config = await AppConfig.load();
    if (_store) {
      // Las capturas de la tienda no pueden mostrar marcas de terceros (Twitch).
      final raw = jsonDecode(await rootBundle.loadString('assets/config/app_config.json')) as Map<String, dynamic>;
      raw.remove('twitch');
      raw.remove('youtube');
      (raw['links'] as List).removeWhere((l) => l['id'] == 'twitch' || l['id'] == 'youtube');
      config = AppConfig.fromJson(raw);
    }
    settings = SettingsStore(prefs);
    library = LibraryStore(prefs);
    feeds = FeedRepository(config);
    if (_real) {
      _seedReal(config, feeds);
    } else {
      var i = 0;
      for (final p in config.allPrograms) {
        feeds.seed(p.id, _sample(p, i++));
      }
      feeds.seed(
        FeedRepository.newsId,
        ParsedFeed(
          channel: const FeedChannel(title: 'Noticias'),
          items: [
            for (var n = 0; n < 5; n++)
              Episode(
                id: 'n$n',
                feedId: 'news',
                title: [
                  'Nueva temporada de programas en EuskaDigital',
                  'Así fue nuestra cobertura de la feria tecnológica',
                  'Abrimos inscripciones para el taller de podcasting',
                  'Renovamos la app: más rápida y sin publicidad',
                  'Entrevista especial en directo este jueves',
                ][n],
                pubDate: DateTime.now().subtract(Duration(days: n * 2)),
                description: '<p>Resumen de ejemplo de la noticia para ilustrar el diseño de la tarjeta.</p>',
              ),
          ],
        ),
      );
      if (config.youtube != null) {
        // Sin miniaturas: la caché de imágenes de red no funciona en los tests.
        final yt = FeedParser.parse(
          File('test/fixtures/youtube.xml').readAsStringSync(),
          feedId: FeedRepository.videosId,
        );
        feeds.seed(
          FeedRepository.videosId,
          ParsedFeed(
            channel: yt.channel,
            items: [
              for (final v in yt.items)
                Episode(
                  id: v.id,
                  feedId: v.feedId,
                  title: v.title,
                  link: v.link,
                  pubDate: v.pubDate,
                  description: v.description,
                ),
            ],
          ),
        );
      }
    }
    // «Continúa escuchando»: dos episodios empezados.
    for (final (id, index, fraction) in [('enredando', 1, 0.4), ('gaming-room', 0, 0.7)]) {
      final items = feeds.state(id).items.where((e) => e.hasAudio).toList();
      if (items.length <= index) continue;
      final e = items[index];
      final total = e.duration ?? const Duration(hours: 1);
      library.saveProgress(e, total * fraction, total);
    }
    player = PlayerService(config, library, settings);
    // Capturas con el canal «en directo» para mostrar la tarjeta.
    twitchLive = TwitchLiveService('euskadigital', autoStart: false)
      ..debugDisablePreview = true
      ..debugSetLive(config.twitch != null);
  });

  Widget app(ThemeMode mode) => MultiProvider(
    providers: [
      Provider.value(value: config),
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: library),
      ChangeNotifierProvider.value(value: feeds),
      ChangeNotifierProvider(create: (_) => AlertsStore(prefs)),
      ChangeNotifierProvider<TwitchLiveService?>.value(value: twitchLive),
      ChangeNotifierProvider(create: (_) => DownloadManager(library, settings)),
      ChangeNotifierProvider.value(value: player),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AppShell(),
    ),
  );

  Future<void> pumpApp(WidgetTester tester, ThemeMode mode) async {
    // Con --dart-define=STORE=true: 1080x1920 (formato admitido por Google Play).
    tester.view.physicalSize = _store ? const Size(1080, 1920) : const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 24 * 3, bottom: 48 * 3);
    tester.view.viewPadding = const FakeViewPadding(top: 24 * 3, bottom: 48 * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(mode));
    await settle(tester);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '${_store
            ? 'goldens_store'
            : _real
            ? 'goldens_real'
            : 'goldens'}/$name.png',
      ),
    );
  }

  testWidgets('inicio (claro)', (tester) async {
    await pumpApp(tester, ThemeMode.light);
    await shot(tester, '01_inicio_claro');
  });

  testWidgets('inicio (oscuro) con mini reproductor', (tester) async {
    await pumpApp(tester, ThemeMode.dark);
    // Un episodio de un programa propio para el mini reproductor.
    final own = feeds.state('enredando').items.where((e) => e.hasAudio);
    final e = own.isNotEmpty ? own.first : feeds.latestEpisodes().first;
    player.debugShow(
      NowPlaying(
        id: e.id,
        title: e.title,
        subtitle: config.programById(e.feedId)!.title,
        fallbackImage: config.programById(e.feedId)!.fallbackImage,
        episode: e,
      ),
    );
    await shot(tester, '02_inicio_oscuro');
  });

  testWidgets('programas', (tester) async {
    await pumpApp(tester, ThemeMode.light);
    await tester.tap(find.text('Programas').last);
    await shot(tester, '03_programas');
  });

  testWidgets('ficha de programa', (tester) async {
    await pumpApp(tester, ThemeMode.light);
    await tester.tap(find.text('Programas').last);
    await settle(tester);
    await tester.scrollUntilVisible(find.text('EnRedAndo'), 200, scrollable: find.byType(Scrollable).last);
    await settle(tester);
    await tester.tap(find.text('EnRedAndo'));
    await shot(tester, '04_programa');
  });

  testWidgets('reproductor (directo)', (tester) async {
    await pumpApp(tester, ThemeMode.dark);
    player.debugShow(
      NowPlaying(
        id: PlayerService.liveId,
        title: config.live.title,
        subtitle: config.live.subtitle,
        fallbackImage: 'assets/branding/logo.png',
      ),
    );
    await settle(tester);
    PlayerScreen.show(tester.element(find.byType(AppShell)));
    await shot(tester, '05_reproductor_directo');
  });

  testWidgets('noticias', (tester) async {
    await pumpApp(tester, ThemeMode.light);
    await tester.tap(find.text('Noticias').last);
    await shot(tester, '06_noticias');
  });

  testWidgets('más', (tester) async {
    await pumpApp(tester, ThemeMode.light);
    await tester.tap(find.text('Más').last);
    await shot(tester, '07_mas');
  });

  testWidgets('lista con portada apaisada (sin recortar)', (tester) async {
    // Misma configuración, pero el primer programa usa como portada de
    // respaldo la imagen apaisada del directo (500x334).
    final raw = jsonDecode((await tester.runAsync(() => rootBundle.loadString('assets/config/app_config.json')))!);
    final first = raw['programGroups'][0]['programs'][0];
    first['fallbackImage'] = 'assets/images/live_cover.png';
    config = AppConfig.fromJson(raw);
    feeds = FeedRepository(config);
    final p = config.allPrograms.first;
    feeds.seed(p.id, _sample(p, 0));
    await pumpApp(tester, ThemeMode.light);
    await tester.tap(find.text('Programas').last);
    await settle(tester);
    await tester.tap(find.text(p.title).first);
    await shot(tester, '08_portada_apaisada');
  });

  testWidgets('twitch', skip: _store, (tester) async {
    WebViewPlatform.instance = FakeWebViewPlatform();
    await pumpApp(tester, ThemeMode.light);
    TwitchScreen.open(tester.element(find.byType(HomeScreen)), config.twitch!);
    await shot(tester, '09_twitch');
  });

  testWidgets('twitch (oscuro)', skip: _store, (tester) async {
    WebViewPlatform.instance = FakeWebViewPlatform();
    await pumpApp(tester, ThemeMode.dark);
    TwitchScreen.open(tester.element(find.byType(HomeScreen)), config.twitch!);
    await shot(tester, '10_twitch_oscuro');
  });

  testWidgets('avisos de episodios', (tester) async {
    await prefs.setStringList('alerts.programs', ['cibertxoko', 'enredando', 'gaming-room']);
    await pumpApp(tester, ThemeMode.light);
    await tester.tap(find.text('Más').last);
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Ajustes'), 200, scrollable: find.byType(Scrollable).last);
    await settle(tester);
    await tester.tap(find.text('Ajustes'));
    await settle(tester);
    await tester.tap(find.text('Episodios nuevos'));
    await shot(tester, '11_avisos');
  });

  testWidgets('programa con aviso activado', (tester) async {
    await prefs.setStringList('alerts.programs', ['enredando']);
    await pumpApp(tester, ThemeMode.light);
    await tester.tap(find.text('Programas').last);
    await settle(tester);
    await tester.scrollUntilVisible(find.text('EnRedAndo'), 200, scrollable: find.byType(Scrollable).last);
    await settle(tester);
    await tester.tap(find.text('EnRedAndo'));
    await shot(tester, '12_programa_aviso');
  });
}

/// Espera a que carguen las imágenes locales y terminen las animaciones.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() async {
      for (final el in find.byType(Image).evaluate()) {
        final img = el.widget as Image;
        await precacheImage(img.image, el);
      }
    });
    await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.pump(const Duration(seconds: 1));
}

/// Carga los feeds reales y sirve sus imágenes desde ficheros locales.
void _seedReal(AppConfig config, FeedRepository feeds) {
  final manifest = jsonDecode(File('$_realDir/manifest.json').readAsStringSync()) as Map<String, dynamic>;
  final images = (manifest['images'] as Map).cast<String, String>();
  // MemoryImage (y no FileImage, que no llega a cargar en los tests); se
  // guarda cada imagen para que la clave de caché sea estable.
  final loaded = <String, MemoryImage>{};
  NetImage.debugProvider = (url) {
    final f = images[url];
    if (f == null) return null;
    return loaded[url] ??= MemoryImage(File('$_realDir/$f').readAsBytesSync());
  };
  (manifest['feeds'] as Map).cast<String, String>().forEach((id, file) {
    final feedId = switch (id) {
      'news' => FeedRepository.newsId,
      'youtube' => FeedRepository.videosId,
      _ => id,
    };
    if (feedId == FeedRepository.videosId && config.youtube == null) return;
    feeds.seed(feedId, FeedParser.parse(File('$_realDir/$file').readAsStringSync(), feedId: feedId));
  });
}
