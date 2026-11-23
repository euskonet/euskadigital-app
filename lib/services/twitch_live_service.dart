import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// Sabe si el canal de Twitch está emitiendo, sin claves de API.
///
/// Twitch publica una vista previa del directo de cada canal en su CDN. Si
/// el canal no emite, esa dirección redirige a una imagen genérica de
/// «desconectado»; si emite, devuelve la imagen. Se comprueba al abrir la
/// app, al volver a ella y cada pocos minutos mientras está en primer plano.
class TwitchLiveService extends ChangeNotifier with WidgetsBindingObserver {
  TwitchLiveService(this.channel, {http.Client? client, bool autoStart = true})
      : _client = client ?? http.Client() {
    if (autoStart) {
      WidgetsBinding.instance.addObserver(this);
      check();
      _startTimer();
    }
  }

  static const _interval = Duration(minutes: 2);

  final String channel;
  final http.Client _client;
  Timer? _timer;
  bool _live = false;
  DateTime _checkedAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isLive => _live;

  /// Vista previa del directo (cambia la URL en cada comprobación para no
  /// mostrar una imagen antigua de la caché).
  String? get previewUrl => debugDisablePreview
      ? null
      : 'https://static-cdn.jtvnw.net/previews-ttv/live_user_$channel-640x360.jpg?t=${_checkedAt.millisecondsSinceEpoch ~/ 1000}';

  /// Sin vista previa (las capturas no pueden cargar imágenes de red).
  @visibleForTesting
  bool debugDisablePreview = false;

  String get _probeUrl => 'https://static-cdn.jtvnw.net/previews-ttv/live_user_$channel-80x45.jpg';

  Future<void> check() async {
    try {
      final req = http.Request('GET', Uri.parse(_probeUrl))..followRedirects = false;
      final res = await _client.send(req).timeout(const Duration(seconds: 15));
      await res.stream.drain<void>();
      final live = res.statusCode == 200 && (res.headers['content-type'] ?? '').startsWith('image/');
      _checkedAt = DateTime.now();
      if (live != _live) {
        _live = live;
        notifyListeners();
      } else if (live) {
        notifyListeners(); // refrescar la vista previa
      }
    } catch (e) {
      // Sin conexión: se mantiene el último estado conocido.
      debugPrint('No se ha podido comprobar el directo de Twitch: $e');
    }
  }

  /// Fuerza el estado (capturas y tests).
  @visibleForTesting
  void debugSetLive(bool live) {
    _live = live;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      check();
      _startTimer();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
