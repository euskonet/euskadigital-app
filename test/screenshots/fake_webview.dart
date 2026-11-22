// WebView simulada para las capturas: los tests no pueden dibujar vistas
// web nativas, así que se muestra un marcador indicando qué va en cada hueco.
import 'package:flutter/material.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams params) =>
      _FakeController(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(PlatformNavigationDelegateCreationParams params) =>
      _FakeDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) =>
      _FakeWidget(params);
}

class _FakeController extends PlatformWebViewController {
  _FakeController(super.params) : super.implementation();
  final html = ValueNotifier<String>('');

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async {}
  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async => this.html.value = html;
  @override
  Future<void> reload() async {}
}

class _FakeDelegate extends PlatformNavigationDelegate {
  _FakeDelegate(super.params) : super.implementation();
  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback onNavigationRequest) async {}
}

class _FakeWidget extends PlatformWebViewWidget {
  _FakeWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) {
    final c = params.controller as _FakeController;
    return ValueListenableBuilder<String>(
      valueListenable: c.html,
      builder: (context, html, _) {
        final video = html.contains('player.twitch.tv');
        final fg = video ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant;
        return Container(
          color: video ? Colors.black : Theme.of(context).colorScheme.surfaceContainerLowest,
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: fg.withValues(alpha: 0.5), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(video ? Icons.smart_display_rounded : Icons.forum_rounded, color: fg, size: 36),
                const SizedBox(height: 8),
                Text(
                  video ? 'Aquí se ve el vídeo de Twitch' : 'Aquí aparece el chat de Twitch',
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                ),
                Text('(marcador de la captura)', style: TextStyle(color: fg, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}
