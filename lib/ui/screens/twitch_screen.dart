import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../config/app_config.dart';
import '../../services/player_service.dart';

/// Canal de Twitch integrado: reproductor de vídeo arriba y chat debajo.
///
/// Los embeds de Twitch exigen declarar el dominio de la página que los
/// inserta (`parent`). Por eso cargamos un HTML propio con `baseUrl` en
/// ese dominio y dentro el iframe oficial de Twitch.
class TwitchScreen extends StatefulWidget {
  const TwitchScreen({super.key, required this.config});
  final TwitchConfig config;

  static void open(BuildContext context, TwitchConfig config) {
    // Evitar que suenen a la vez la radio/podcast y el vídeo.
    final player = context.read<PlayerService>();
    if (player.playing) player.togglePlay();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TwitchScreen(config: config)));
  }

  @override
  State<TwitchScreen> createState() => _TwitchScreenState();
}

class _TwitchScreenState extends State<TwitchScreen> {
  late final WebViewController _video;
  late final WebViewController _chat;
  bool _showChat = true;

  TwitchConfig get c => widget.config;
  String get _base => 'https://${c.parentDomain}/';

  @override
  void initState() {
    super.initState();
    _video = _createController(media: true)
      ..loadHtmlString(
        _page(
          'https://player.twitch.tv/?channel=${c.channel}&parent=${c.parentDomain}&autoplay=true&muted=false',
          background: '#000000',
        ),
        baseUrl: _base,
      );
    _chat = _createController(media: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? '#18181b' : '#ffffff';
    _chat.loadHtmlString(
      _page(
        'https://www.twitch.tv/embed/${c.channel}/chat?parent=${c.parentDomain}${dark ? '&darkpopout' : ''}',
        background: bg,
      ),
      baseUrl: _base,
    );
  }

  WebViewController _createController({required bool media}) {
    PlatformWebViewControllerCreationParams params = const PlatformWebViewControllerCreationParams();
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      // iOS: reproducir dentro de la página (no saltar a pantalla completa).
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    }
    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(media ? Colors.black : Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          // La página inicial y los iframes de Twitch se cargan dentro;
          // cualquier otro enlace (perfil, suscripción...) va fuera.
          if (!req.isMainFrame || req.url == _base || req.url.startsWith('about:')) {
            return NavigationDecision.navigate;
          }
          launchUrl(Uri.parse(req.url), mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
      ));

    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
      if (media) {
        platform.setCustomWidgetCallbacks(
          onShowCustomWidget: (widget, onHidden) => _enterFullscreen(widget, onHidden),
          onHideCustomWidget: _exitFullscreen,
        );
      }
    }
    return controller;
  }

  static String _page(String src, {required String background}) => '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>
  html, body { margin: 0; padding: 0; height: 100%; background: $background; overflow: hidden; }
  iframe { border: 0; width: 100%; height: 100%; display: block; }
</style>
</head>
<body>
<iframe src="$src" allow="autoplay; fullscreen; encrypted-media; picture-in-picture" allowfullscreen scrolling="no"></iframe>
</body>
</html>''';

  // ------------------------------------------------- pantalla completa (Android)

  bool _fullscreen = false;

  void _enterFullscreen(Widget video, VoidCallback onHidden) {
    if (_fullscreen) return;
    _fullscreen = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    Navigator.of(context, rootNavigator: true)
        .push(PageRouteBuilder(
          opaque: true,
          pageBuilder: (_, _, _) => PopScope(
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) onHidden();
            },
            child: ColoredBox(color: Colors.black, child: video),
          ),
        ))
        .then((_) => _restoreSystemUi());
  }

  void _exitFullscreen() {
    if (!_fullscreen) return;
    Navigator.of(context, rootNavigator: true).maybePop();
  }

  void _restoreSystemUi() {
    _fullscreen = false;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const []);
  }

  @override
  void dispose() {
    if (_fullscreen) _restoreSystemUi();
    super.dispose();
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Twitch'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: () {
              _video.reload();
              _chat.reload();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Abrir en Twitch',
            onPressed: () => launchUrl(Uri.parse(c.channelUrl), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: Colors.black, child: WebViewWidget(controller: _video)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Icon(Icons.live_tv_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('twitch.tv/${c.channel}', style: theme.textTheme.titleSmall),
                      if (c.subtitle != null)
                        Text(c.subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _showChat = !_showChat),
                  icon: Icon(_showChat ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded),
                  label: Text(_showChat ? 'Ocultar chat' : 'Ver chat'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _showChat
                ? WebViewWidget(controller: _chat)
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Para escribir en el chat, ábrelo en la app de Twitch.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
