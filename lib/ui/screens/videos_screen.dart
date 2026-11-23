import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/app_config.dart';
import '../../models/episode.dart';
import '../../services/feed_parser.dart';
import '../../services/feed_repository.dart';
import '../../services/player_service.dart';
import '../format.dart';
import '../widgets/common.dart';
import '../widgets/embedded_web.dart';
import '../widgets/net_image.dart';

/// Miniatura 16:9 de un vídeo con su título y fecha.
class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.video, this.width});
  final Episode video;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => VideoScreen.open(context, video),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (video.imageUrl != null)
                    NetImage(
                      imageUrl: video.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => ColoredBox(color: scheme.surfaceContainerHighest),
                      errorWidget: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest),
                    )
                  else
                    ColoredBox(color: scheme.surfaceContainerHighest),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(formatDate(video.pubDate),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
    return width == null ? card : SizedBox(width: width, child: card);
  }
}

/// Fila horizontal de últimos vídeos para Inicio.
class LatestVideosRow extends StatelessWidget {
  const LatestVideosRow({super.key, required this.videos});
  final List<Episode> videos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 228,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: videos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) => VideoCard(video: videos[i], width: 240),
      ),
    );
  }
}

/// Todos los vídeos del canal.
class VideosScreen extends StatelessWidget {
  const VideosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final feeds = context.watch<FeedRepository>();
    final yt = context.read<AppConfig>().youtube!;
    final state = feeds.videos;

    return Scaffold(
      appBar: AppBar(
        title: Text(yt.title),
        actions: [
          IconButton(
            tooltip: 'Ver el canal completo',
            onPressed: () => launchUrl(Uri.parse(yt.channelUrl), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => feeds.refresh(FeedRepository.videosId, force: true),
        child: state.items.isEmpty
            ? ListView(children: [
                SizedBox(
                  height: 420,
                  child: state.loading
                      ? const Center(child: CircularProgressIndicator())
                      : MessageView(
                          icon: Icons.smart_display_outlined,
                          title: 'No se han podido cargar los vídeos',
                          message: state.error,
                          actionLabel: 'Reintentar',
                          onAction: () => feeds.refresh(FeedRepository.videosId, force: true),
                        ),
                ),
              ])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: state.items.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 20),
                itemBuilder: (context, i) {
                  if (i < state.items.length) return VideoCard(video: state.items[i]);
                  return Center(
                    child: TextButton.icon(
                      onPressed: () => launchUrl(Uri.parse(yt.channelUrl), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Ver todos los vídeos del canal'),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Reproductor de un vídeo dentro de la app.
class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key, required this.video});
  final Episode video;

  static void open(BuildContext context, Episode video) {
    // Evitar que suenen a la vez la radio/podcast y el vídeo.
    final player = context.read<PlayerService>();
    if (player.playing) player.togglePlay();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => VideoScreen(video: video)));
  }

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> with FullscreenWebHost<VideoScreen> {
  late final WebViewController _controller;
  String? get _id => FeedParser.youtubeVideoId(widget.video);

  @override
  void initState() {
    super.initState();
    _controller = EmbeddedWeb.controller(media: true, fullscreenHost: this);
    final id = _id;
    if (id != null) {
      final origin = Uri.encodeComponent(EmbeddedWeb.baseUrl.substring(0, EmbeddedWeb.baseUrl.length - 1));
      _controller.loadHtmlString(
        EmbeddedWeb.page(
          'https://www.youtube-nocookie.com/embed/$id?autoplay=1&playsinline=1&rel=0&modestbranding=1&origin=$origin',
          background: '#000000',
        ),
        baseUrl: EmbeddedWeb.baseUrl,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final v = widget.video;
    final watchUrl = v.link ?? (_id == null ? null : 'https://www.youtube.com/watch?v=$_id');

    return Scaffold(
      appBar: AppBar(
        title: Text(context.read<AppConfig>().youtube?.title ?? 'Vídeo'),
        actions: [
          if (watchUrl != null)
            IconButton(
              tooltip: 'Abrir en YouTube',
              onPressed: () => launchUrl(Uri.parse(watchUrl), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: Colors.black, child: WebViewWidget(controller: _controller)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(formatDate(v.pubDate),
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                if (watchUrl != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(watchUrl), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Abrir en YouTube'),
                  ),
                ],
                if ((v.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SelectableText(v.description!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
