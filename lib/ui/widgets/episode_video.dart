import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/player_service.dart';
import 'embedded_web.dart';

/// Versión en vídeo (YouTube) del episodio que suena, empezando donde iba el
/// audio. Informa al reproductor de su posición para volver al audio en el
/// mismo punto.
class EpisodeVideo extends StatefulWidget {
  const EpisodeVideo({super.key, required this.videoId, required this.start});
  final String videoId;
  final Duration start;

  @override
  State<EpisodeVideo> createState() => _EpisodeVideoState();
}

class _EpisodeVideoState extends State<EpisodeVideo> with FullscreenWebHost<EpisodeVideo> {
  late final WebViewController _controller;
  late final PlayerService _player;

  @override
  void initState() {
    super.initState();
    _player = context.read<PlayerService>();
    _controller = EmbeddedWeb.controller(media: true, fullscreenHost: this)
      ..addJavaScriptChannel('Pos', onMessageReceived: (m) {
        final secs = double.tryParse(m.message);
        if (secs != null) _player.updateVideoPosition(Duration(milliseconds: (secs * 1000).round()));
      })
      ..loadHtmlString(_page(widget.videoId, widget.start.inSeconds), baseUrl: EmbeddedWeb.baseUrl);
    _player.attachVideo(pause: () => _controller.runJavaScript('try{player.pauseVideo()}catch(e){}'));
  }

  @override
  void dispose() {
    _player.detachVideo();
    // Al cerrar el reproductor estando en vídeo, se sigue en audio.
    if (_player.videoMode) _player.exitVideo(resume: true);
    super.dispose();
  }

  static String _page(String id, int start) {
    final origin = EmbeddedWeb.baseUrl.substring(0, EmbeddedWeb.baseUrl.length - 1);
    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>
  html, body { margin: 0; padding: 0; height: 100%; background: #000; overflow: hidden; }
  #p, iframe { width: 100%; height: 100%; border: 0; display: block; }
</style>
</head>
<body>
<div id="p"></div>
<script>
  var player;
  function onYouTubeIframeAPIReady() {
    player = new YT.Player('p', {
      videoId: '$id',
      host: 'https://www.youtube-nocookie.com',
      playerVars: { start: $start, autoplay: 1, playsinline: 1, rel: 0, modestbranding: 1, origin: '$origin' },
      events: { onReady: function (e) { e.target.playVideo(); } }
    });
    setInterval(function () {
      if (player && player.getCurrentTime) { Pos.postMessage(String(player.getCurrentTime())); }
    }, 1000);
  }
</script>
<script src="https://www.youtube.com/iframe_api"></script>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(color: Colors.black, child: WebViewWidget(controller: _controller)),
      ),
    );
  }
}
