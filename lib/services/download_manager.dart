import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/episode.dart';
import 'library_store.dart';
import 'settings_store.dart';

class DownloadBlockedException implements Exception {
  DownloadBlockedException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Descarga episodios para escucharlos sin conexión.
class DownloadManager extends ChangeNotifier {
  DownloadManager(this._library, this._settings, {http.Client? client})
      : _client = client ?? http.Client();

  final LibraryStore _library;
  final SettingsStore _settings;
  final http.Client _client;

  final Map<String, double> _progress = {}; // 0–1, o -1 si no se sabe el tamaño
  final Set<String> _cancelled = {};

  bool isDownloading(String id) => _progress.containsKey(id);
  double? progressOf(String id) => _progress[id];

  Future<Directory> _dir() async {
    final d = Directory('${(await getApplicationDocumentsDirectory()).path}/downloads');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static String _fileNameFor(Episode e) {
    final ext = RegExp(r'\.(mp3|m4a|aac|ogg|opus|wav)(\?|$)', caseSensitive: false)
            .firstMatch(e.audioUrl ?? '')
            ?.group(1)
            ?.toLowerCase() ??
        'mp3';
    final safe = e.id.hashCode.toUnsigned(32).toRadixString(16);
    return '${e.feedId}_$safe.$ext';
  }

  /// Lanza [DownloadBlockedException] si la descarga no está permitida.
  Future<void> download(Episode e) async {
    if (!e.hasAudio || isDownloading(e.id) || _library.isDownloaded(e.id)) return;

    if (_settings.wifiOnlyDownloads) {
      final c = await Connectivity().checkConnectivity();
      final onWifi = c.contains(ConnectivityResult.wifi) || c.contains(ConnectivityResult.ethernet);
      if (!onWifi) {
        throw DownloadBlockedException(
            'Las descargas solo están permitidas con wifi. Puedes cambiarlo en Ajustes.');
      }
    }

    _progress[e.id] = 0;
    _cancelled.remove(e.id);
    notifyListeners();

    final file = File('${(await _dir()).path}/${_fileNameFor(e)}');
    final tmp = File('${file.path}.part');
    IOSink? sink;
    try {
      final req = http.Request('GET', Uri.parse(e.audioUrl!))
        ..headers['User-Agent'] = 'EuskaDigitalApp/1.0';
      final res = await _client.send(req);
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final total = res.contentLength ?? 0;
      var received = 0;
      var lastNotify = DateTime.now();
      sink = tmp.openWrite();
      await for (final chunk in res.stream) {
        if (_cancelled.contains(e.id)) throw const _Cancelled();
        sink.add(chunk);
        received += chunk.length;
        if (DateTime.now().difference(lastNotify) > const Duration(milliseconds: 250)) {
          _progress[e.id] = total > 0 ? received / total : -1;
          lastNotify = DateTime.now();
          notifyListeners();
        }
      }
      await sink.close();
      sink = null;
      await tmp.rename(file.path);
      _library.registerDownload(e, file.path);
    } on _Cancelled {
      // Nada: cancelado por el usuario.
    } finally {
      await sink?.close();
      if (await tmp.exists()) await tmp.delete();
      _progress.remove(e.id);
      _cancelled.remove(e.id);
      notifyListeners();
    }
  }

  void cancel(String id) {
    if (isDownloading(id)) _cancelled.add(id);
  }

  Future<void> delete(String id) async {
    final path = _library.downloadPath(id);
    if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    _library.unregisterDownload(id);
  }

  Future<void> deleteAll() async {
    for (final e in _library.downloads) {
      await delete(e.id);
    }
  }

  /// Espacio ocupado por las descargas, en bytes.
  Future<int> usedBytes() async {
    var total = 0;
    for (final e in _library.downloads) {
      final p = _library.downloadPath(e.id);
      if (p != null) {
        final f = File(p);
        if (await f.exists()) total += await f.length();
      }
    }
    return total;
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}
