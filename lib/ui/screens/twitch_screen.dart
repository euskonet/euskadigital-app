import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/app_config.dart';
import '../../services/player_service.dart';
import '../widgets/embedded_web.dart';

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

class _TwitchScreenState extends State<TwitchScreen> with FullscreenWebHost<TwitchScreen> {
  late final WebViewController _video;
  late final WebViewController _chat;
  bool _showChat = true;

  TwitchConfig get c => widget.config;

  /// Twitch exige declarar los dominios de la página que inserta el
  /// reproductor; se incluyen con y sin www por seguridad.
  String get _parents {
    final host = Uri.parse(EmbeddedWeb.baseUrl).host;
    return {host, host.replaceFirst('www.', ''), c.parentDomain}.map((h) => 'parent=$h').join('&');
  }

  @override
  void initState() {
    super.initState();
    _video = EmbeddedWeb.controller(media: true, fullscreenHost: this)
      ..loadHtmlString(
        EmbeddedWeb.page(
          'https://player.twitch.tv/?channel=${c.channel}&$_parents&autoplay=true&muted=false',
          background: '#000000',
        ),
        baseUrl: EmbeddedWeb.baseUrl,
      );
    _chat = EmbeddedWeb.controller(media: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dark = Theme.of(context).brightness == Brightness.dark;
    _chat.loadHtmlString(
      EmbeddedWeb.page(
        'https://www.twitch.tv/embed/${c.channel}/chat?$_parents${dark ? '&darkpopout' : ''}',
        background: dark ? '#18181b' : '#ffffff',
      ),
      baseUrl: EmbeddedWeb.baseUrl,
    );
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
