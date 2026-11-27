import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../models/episode.dart';
import 'feed_parser.dart';
import 'video_matcher.dart';

/// Estado de carga de un feed.
class FeedState {
  const FeedState({this.feed, this.loading = false, this.error, this.updatedAt});

  final ParsedFeed? feed;
  final bool loading;
  final String? error;
  final DateTime? updatedAt;

  List<Episode> get items => feed?.items ?? const [];
  FeedChannel? get channel => feed?.channel;

  FeedState copyWith({ParsedFeed? feed, bool? loading, String? error, DateTime? updatedAt, bool clearError = false}) =>
      FeedState(
        feed: feed ?? this.feed,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// Descarga, cachea y expone los feeds de programas y noticias.
///
/// Cada feed se guarda en disco para que la app funcione sin conexión;
/// al abrir se muestra la copia local y se refresca en segundo plano.
class FeedRepository extends ChangeNotifier {
  FeedRepository(this.config, {http.Client? client, this.onFeedLoaded}) : _client = client ?? http.Client();

  /// Se llama cada vez que un feed se descarga correctamente.
  final void Function(String feedId, ParsedFeed feed)? onFeedLoaded;

  static const newsId = 'news';
  static const videosId = 'youtube';

  /// Feed de la lista de YouTube con los vídeos de un programa.
  static String videoFeedId(String programId) => 'video-$programId';
  static const _maxAge = Duration(minutes: 30);

  final AppConfig config;
  final http.Client _client;
  final Map<String, FeedState> _states = {};
  Directory? _cacheDir;

  FeedState state(String feedId) => _states[feedId] ?? const FeedState();

  FeedState get news => state(newsId);
  FeedState get videos => state(videosId);

  /// Imagen de portada del programa (del feed si existe).
  String? programImage(String programId) => state(programId).channel?.imageUrl;

  /// Últimos episodios con audio de todos los programas, más recientes primero.
  List<Episode> latestEpisodes({int limit = 30}) {
    final all = <Episode>[
      for (final p in config.allPrograms) ...state(p.id).items.where((e) => e.hasAudio),
    ];
    all.sort((a, b) => (b.pubDate ?? DateTime(1970)).compareTo(a.pubDate ?? DateTime(1970)));
    return all.take(limit).toList();
  }

  Episode? findEpisode(String id) {
    for (final s in _states.values) {
      for (final e in s.items) {
        if (e.id == id) return e;
      }
    }
    return null;
  }

  /// Carga datos directamente (tests y capturas de pantalla).
  @visibleForTesting
  void seed(String feedId, ParsedFeed feed) {
    _states[feedId] = FeedState(feed: feed, updatedAt: DateTime.now());
    _videoCache.clear();
    notifyListeners();
  }

  String _urlFor(String feedId) {
    if (feedId == newsId) return config.news.feedUrl;
    if (feedId == videosId) return config.youtube!.feedUrl;
    if (feedId.startsWith('video-')) return config.programById(feedId.substring(6))!.videoFeedUrl!;
    return config.programById(feedId)!.feedUrl;
  }

  Iterable<String> get _allIds => [
        newsId,
        if (config.youtube != null) videosId,
        ...config.allPrograms.map((p) => p.id),
        for (final p in config.allPrograms)
          if (p.videoPlaylistId != null) videoFeedId(p.id),
      ];

  /// Vídeo de YouTube (id) con la versión en vídeo de un episodio, si existe.
  String? videoFor(Episode e) {
    final program = config.programById(e.feedId);
    if (program?.videoPlaylistId == null) return null;
    // La lista del programa y, por si falta algún vídeo en ella, los últimos
    // vídeos del canal.
    final candidates = [...state(videoFeedId(program!.id)).items, ...videos.items];
    return _videoCache.putIfAbsent(e.id, () => VideoMatcher.match(e, program.title, candidates));
  }

  final Map<String, String?> _videoCache = {};

  /// Carga la caché local de todos los feeds y luego los refresca.
  Future<void> init() async {
    await Future.wait(_allIds.map(_loadFromDisk));
    notifyListeners();
    unawaited(refreshAll());
  }

  Future<void> refreshAll({bool force = false}) =>
      Future.wait(_allIds.map((id) => refresh(id, force: force)));

  Future<void> refresh(String feedId, {bool force = false}) async {
    final current = state(feedId);
    if (current.loading) return;
    if (!force &&
        current.updatedAt != null &&
        DateTime.now().difference(current.updatedAt!) < _maxAge &&
        current.error == null) {
      return;
    }
    _states[feedId] = current.copyWith(loading: true);
    notifyListeners();
    try {
      final res = await _client.get(Uri.parse(_urlFor(feedId)), headers: {
        'User-Agent': 'EuskaDigitalApp/1.0 (+https://www.euskadigital.eus)',
        'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
      }).timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final body = _decode(res);
      final parsed = await compute(_parseIsolate, [body, feedId]);
      _states[feedId] = FeedState(feed: parsed, updatedAt: DateTime.now());
      _videoCache.clear();
      onFeedLoaded?.call(feedId, parsed);
      unawaited(_saveToDisk(feedId, body));
    } catch (e) {
      debugPrint('Error cargando $feedId: $e');
      _states[feedId] = current.copyWith(
        loading: false,
        error: current.feed == null
            ? 'No se ha podido cargar el contenido. Revisa tu conexión.'
            : 'Mostrando la última copia guardada.',
      );
    }
    notifyListeners();
  }

  static ParsedFeed _parseIsolate(List<String> args) =>
      FeedParser.parse(args[0], feedId: args[1]);

  /// Respeta la codificación declarada; si no hay, intenta UTF-8.
  static String _decode(http.Response res) {
    final ct = res.headers['content-type'] ?? '';
    if (ct.toLowerCase().contains('charset=')) {
      try {
        return res.body;
      } catch (_) {}
    }
    return utf8.decode(res.bodyBytes, allowMalformed: true);
  }

  Future<File> _cacheFile(String feedId) async {
    _cacheDir ??= Directory('${(await getApplicationSupportDirectory()).path}/feeds');
    if (!await _cacheDir!.exists()) await _cacheDir!.create(recursive: true);
    return File('${_cacheDir!.path}/$feedId.xml');
  }

  Future<void> _loadFromDisk(String feedId) async {
    try {
      final f = await _cacheFile(feedId);
      if (!await f.exists()) return;
      final parsed = await compute(_parseIsolate, [await f.readAsString(), feedId]);
      // updatedAt null => se refrescará igualmente desde la red.
      _states[feedId] = FeedState(feed: parsed);
      _videoCache.clear();
    } catch (e) {
      debugPrint('Caché inválida para $feedId: $e');
    }
  }

  Future<void> _saveToDisk(String feedId, String body) async {
    try {
      await (await _cacheFile(feedId)).writeAsString(body);
    } catch (_) {}
  }
}
