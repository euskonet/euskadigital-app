import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../models/episode.dart';
import '../../services/download_manager.dart';
import '../../services/library_store.dart';
import '../../services/player_service.dart';
import '../format.dart';
import '../widgets/artwork.dart';
import '../widgets/episode_actions.dart';
import '../widgets/html_body.dart';
import 'podcast_screen.dart';

/// Detalle de un episodio con acciones y notas del programa.
class EpisodeScreen extends StatelessWidget {
  const EpisodeScreen({super.key, required this.episode});
  final Episode episode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final player = context.watch<PlayerService>();
    final lib = context.watch<LibraryStore>();
    final dm = context.watch<DownloadManager>();
    final v = EpisodeVisuals.of(context, episode, listen: true);
    final program = context.read<AppConfig>().programById(episode.feedId);
    final playing = player.isPlayingId(episode.id);
    final progress = lib.progressOf(episode.id);
    final played = lib.isPlayed(episode.id);
    final fav = lib.isFavorite(episode.id);
    final downloaded = lib.isDownloaded(episode.id);
    final downloading = dm.isDownloading(episode.id);

    final meta = [
      formatDate(episode.pubDate),
      if (episode.duration != null) formatLength(episode.duration!),
    ].where((s) => s.isNotEmpty).join(' · ');

    String playLabel;
    if (playing) {
      playLabel = 'Pausar';
    } else if (progress > Duration.zero && !played) {
      playLabel = 'Continuar (${formatDuration(progress)})';
    } else {
      playLabel = 'Reproducir';
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Compartir',
            onPressed: () => EpisodeActions.share(context, episode, programTitle: v.programTitle),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (a) {
              switch (a) {
                case 'played':
                  lib.markPlayed(episode, played: !played);
                case 'web':
                  launchUrl(Uri.parse(episode.link!), mode: LaunchMode.externalApplication);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'played', child: Text(played ? 'Marcar como no escuchado' : 'Marcar como escuchado')),
              if (episode.link != null) const PopupMenuItem(value: 'web', child: Text('Abrir en la web')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Center(child: Artwork(url: v.imageUrl, fallbackAsset: v.fallbackAsset, size: 220, radius: 24)),
          const SizedBox(height: 20),
          InkWell(
            onTap: program == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PodcastScreen(program: program))),
            child: Text(v.programTitle.toUpperCase(),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary, letterSpacing: 0.8)),
          ),
          const SizedBox(height: 8),
          Text(episode.title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(meta,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 20),
          if (episode.hasAudio)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () => EpisodeActions.play(context, episode),
                    icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    label: Text(playLabel),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: fav ? 'Quitar de favoritos' : 'Añadir a favoritos',
                  onPressed: () => lib.toggleFavorite(episode),
                  icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                ),
                IconButton.filledTonal(
                  tooltip: downloaded
                      ? 'Borrar descarga'
                      : downloading
                          ? 'Cancelar descarga'
                          : 'Descargar',
                  onPressed: () => EpisodeActions.toggleDownload(context, episode),
                  icon: downloading
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            value: (dm.progressOf(episode.id) ?? -1) < 0 ? null : dm.progressOf(episode.id),
                          ),
                        )
                      : Icon(downloaded ? Icons.download_done_rounded : Icons.download_rounded),
                ),
              ],
            ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          if (episode.body.trim().isNotEmpty)
            HtmlBody(episode.body)
          else
            Text('Este episodio no tiene descripción.',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
