import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../config/app_config.dart';
import '../models/episode.dart';
import 'library_store.dart';
import 'settings_store.dart';

/// Lo que está sonando ahora mismo.
class NowPlaying {
  const NowPlaying({
    required this.id,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.fallbackImage,
    this.episode,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? fallbackImage;

  /// `null` si es el directo.
  final Episode? episode;

  bool get isLive => episode == null;
}

/// Reproductor único de la app: episodios y directo, con controles en
/// la notificación / pantalla de bloqueo y reproducción en segundo plano.
class PlayerService extends ChangeNotifier {
  PlayerService(this._config, this._library, this._settings) {
    _player.playerStateStream.listen((_) => notifyListeners());
    _player.processingStateStream.listen(_onProcessingState);
    _player.positionStream.listen(_onPosition);
    _player.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace st) {
      _error = 'No se ha podido reproducir. Inténtalo de nuevo.';
      notifyListeners();
    });
    _initSession();
  }

  static const liveId = 'live';

  final AppConfig _config;
  final LibraryStore _library;
  final SettingsStore _settings;
  final AudioPlayer _player = AudioPlayer();

  NowPlaying? _current;
  String? _error;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _sleepTimer;
  DateTime? _sleepAt;
  bool _sleepAtEnd = false;

  AudioPlayer get player => _player;
  NowPlaying? get current => _current;
  String? get error => _error;
  bool get playing => _player.playing;
  bool get isLiveActive => _current?.isLive ?? false;
  bool get buffering =>
      _player.processingState == ProcessingState.loading ||
      _player.processingState == ProcessingState.buffering;
  double get speed => _player.speed;
  DateTime? get sleepAt => _sleepAt;
  bool get sleepAtEnd => _sleepAtEnd;

  Stream<Duration> get positionStream => _player.positionStream;
  Duration? get duration => _player.duration;

  bool isCurrent(String id) => _current?.id == id;
  bool isPlayingId(String id) => isCurrent(id) && playing;

  Future<void> _initSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      // Pausar si se desconectan los auriculares.
      session.becomingNoisyEventStream.listen((_) => _player.pause());
    } catch (e) {
      debugPrint('No se ha podido configurar la sesión de audio: $e');
    }
  }

  /// Muestra un elemento como "sonando" sin reproducir (capturas/tests).
  @visibleForTesting
  void debugShow(NowPlaying item) {
    _current = item;
    notifyListeners();
  }

  // ------------------------------------------------------------- episodios

  Future<void> playEpisode(Episode e, {String? programTitle, String? fallbackImage, String? programImage}) async {
    if (isCurrent(e.id)) {
      return togglePlay();
    }
    _saveCurrentProgress(force: true);
    final title = programTitle ?? _config.programById(e.feedId)?.title ?? _config.name;
    final image = e.imageUrl ?? programImage;
    _current = NowPlaying(
      id: e.id,
      title: e.title,
      subtitle: title,
      imageUrl: image,
      fallbackImage: fallbackImage ?? _config.programById(e.feedId)?.fallbackImage,
      episode: e,
    );
    _error = null;
    notifyListeners();

    final tag = MediaItem(
      id: e.id,
      title: e.title,
      album: title,
      artist: 'EuskaDigital',
      artUri: image == null ? null : Uri.tryParse(image),
      duration: e.duration,
    );
    final local = _library.downloadPath(e.id);
    final source = local != null && File(local).existsSync()
        ? AudioSource.file(local, tag: tag)
        : AudioSource.uri(Uri.parse(e.audioUrl!), tag: tag);

    final resume = _library.isPlayed(e.id) ? Duration.zero : _library.progressOf(e.id);
    _library.addToHistory(e);
    try {
      await _player.setAudioSource(source, initialPosition: resume);
      await _player.setSpeed(_settings.playbackSpeed);
      unawaited(_player.play());
    } catch (err) {
      debugPrint('Error reproduciendo: $err');
      _error = 'No se ha podido cargar el episodio.';
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- directo

  /// Reproduce el directo. Usa el primer stream de la configuración y, si
  /// no responde, prueba automáticamente los siguientes (respaldo).
  Future<void> playLive({bool restart = false}) async {
    final live = _config.live;
    if (isLiveActive && !restart) return togglePlay();
    _saveCurrentProgress(force: true);
    _current = NowPlaying(
      id: liveId,
      title: live.title,
      subtitle: live.subtitle,
      fallbackImage: 'assets/branding/logo_margenes.png',
    );
    _error = null;
    notifyListeners();
    for (final stream in live.streamsFor(_settings.liveQuality)) {
      try {
        await _player.setAudioSource(AudioSource.uri(
          Uri.parse(stream.url),
          tag: MediaItem(id: liveId, title: live.title, album: live.subtitle, artist: 'EuskaDigital'),
        ));
        await _player.setSpeed(1);
        unawaited(_player.play());
        return;
      } catch (err) {
        debugPrint('Stream ${stream.id} no disponible: $err');
      }
    }
    _error = 'El directo no está disponible ahora mismo.';
    notifyListeners();
  }

  LiveQuality get liveQuality => _settings.liveQuality;

  /// Cambia la calidad del directo; si está sonando, continúa con la nueva.
  Future<void> setLiveQuality(LiveQuality q) async {
    if (q == _settings.liveQuality) return;
    _settings.liveQuality = q;
    notifyListeners();
    if (isLiveActive && (_player.playing || buffering)) await playLive(restart: true);
  }

  // --------------------------------------------------------------- control

  Future<void> togglePlay() async {
    if (_player.playing) {
      await _player.pause();
      _saveCurrentProgress(force: true);
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      if (isLiveActive) {
        // En directo, reanudar = volver al punto actual de la emisión.
        await playLive(restart: true);
        return;
      }
      unawaited(_player.play());
    }
  }

  Future<void> seek(Duration d) => _player.seek(d);

  Future<void> skip(Duration delta) async {
    final pos = _player.position + delta;
    final max = _player.duration ?? pos;
    await _player.seek(pos < Duration.zero ? Duration.zero : (pos > max ? max : pos));
  }

  Future<void> setSpeed(double s) async {
    _settings.playbackSpeed = s;
    if (!isLiveActive) await _player.setSpeed(s);
    notifyListeners();
  }

  Future<void> stop() async {
    _saveCurrentProgress(force: true);
    await _player.stop();
    _current = null;
    cancelSleepTimer();
    notifyListeners();
  }

  // ------------------------------------------------------ temporizador sueño

  void setSleepTimer(Duration d) {
    cancelSleepTimer(notify: false);
    _sleepAt = DateTime.now().add(d);
    _sleepTimer = Timer(d, () {
      _player.pause();
      _saveCurrentProgress(force: true);
      cancelSleepTimer();
    });
    notifyListeners();
  }

  void setSleepAtEnd() {
    cancelSleepTimer(notify: false);
    _sleepAtEnd = true;
    notifyListeners();
  }

  void cancelSleepTimer({bool notify = true}) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepAt = null;
    _sleepAtEnd = false;
    if (notify) notifyListeners();
  }

  // --------------------------------------------------------------- interno

  void _onPosition(Duration _) => _saveCurrentProgress();

  void _saveCurrentProgress({bool force = false}) {
    final e = _current?.episode;
    if (e == null) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastSave) < const Duration(seconds: 10)) return;
    _lastSave = now;
    _library.saveProgress(e, _player.position, _player.duration);
  }

  void _onProcessingState(ProcessingState s) {
    if (s == ProcessingState.completed) {
      final e = _current?.episode;
      if (e != null) _library.markPlayed(e, played: true);
      if (_sleepAtEnd) cancelSleepTimer();
      _player.pause();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}
