import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Utilidades para insertar reproductores web (Twitch, YouTube) en la app.
///
/// Se carga un HTML propio con `baseUrl` en el dominio de EuskaDigital y,
/// dentro, el iframe oficial del servicio: Twitch exige declarar ese dominio
/// (`parent`) y YouTube necesita un origen válido para reproducir.
class EmbeddedWeb {
  EmbeddedWeb._();

  static const baseUrl = 'https://www.euskadigital.eus/';

  /// Página mínima que ocupa todo el espacio con un iframe.
  static String page(String src, {required String background}) => '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>
  html, body { margin: 0; padding: 0; height: 100%; background: $background; overflow: hidden; }
  iframe { border: 0; width: 100%; height: 100%; display: block; }
</style>
</head>
<body>
<iframe src="$src" allow="autoplay; fullscreen; encrypted-media; picture-in-picture" allowfullscreen scrolling="no"></iframe>
</body>
</html>''';

  /// Controlador configurado para medios: reproducción en línea en iOS,
  /// autoplay en Android y enlaces externos fuera de la app.
  static WebViewController controller({
    required bool media,
    FullscreenWebHost? fullscreenHost,
  }) {
    PlatformWebViewControllerCreationParams params = const PlatformWebViewControllerCreationParams();
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
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
          // La página propia y los iframes se cargan dentro; cualquier otro
          // enlace (perfil, suscripción, ver en la web...) se abre fuera.
          if (!req.isMainFrame || req.url == baseUrl || req.url.startsWith('about:')) {
            return NavigationDecision.navigate;
          }
          launchUrl(Uri.parse(req.url), mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
      ));

    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
      if (media && fullscreenHost != null) {
        platform.setCustomWidgetCallbacks(
          onShowCustomWidget: fullscreenHost.enterFullscreen,
          onHideCustomWidget: fullscreenHost.exitFullscreen,
        );
      }
    }
    return controller;
  }
}

/// Pantalla completa del vídeo en Android (botón de pantalla completa del
/// reproductor): ruta negra a pantalla completa y en horizontal.
mixin FullscreenWebHost<T extends StatefulWidget> on State<T> {
  bool _fullscreen = false;

  void enterFullscreen(Widget video, VoidCallback onHidden) {
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

  void exitFullscreen() {
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
}
