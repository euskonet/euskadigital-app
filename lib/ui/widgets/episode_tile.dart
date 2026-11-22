import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/episode.dart';
import '../../services/download_manager.dart';
import '../../services/library_store.dart';
import '../../services/player_service.dart';
import '../format.dart';
import '../screens/episode_screen.dart';
import 'artwork.dart';
import 'episode_actions.dart';

/// Fila de episodio: portada, programa, título, duración/progreso y
/// botón de reproducir.
class EpisodeTile extends StatelessWidget {
  const EpisodeTile({super.key, required this.episode, this.showArtwork = true, this.showProgram = true});

  final Episode episode;
  final bool showArtwork;
  final bool showProgram;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lib = context.watch<LibraryStore>();
    final dm = context.watch<DownloadManager>();
    final v = EpisodeVisuals.of(context, episode, listen: true);
    final played = lib.isPlayed(episode.id);
    final fraction = lib.fractionOf(episode);
    final downloaded = lib.isDownloaded(episode.id);

    final meta = <String>[
      if (showProgram) v.programTitle,
      formatDate(episode.pubDate),
    ].where((s) => s.isNotEmpty).join(' · ');

    String? lengthText;
    if (played) {
      lengthText = 'Escuchado';
    } else if (episode.duration != null) {
      final left = episode.duration! - lib.progressOf(episode.id);
      lengthText = lib.progressOf(episode.id) > Duration.zero
          ? 'Quedan ${formatLength(left)}'
          : formatLength(episode.duration!);
    }

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EpisodeScreen(episode: episode)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showArtwork) ...[
              Artwork(url: v.imageUrl, fallbackAsset: v.fallbackAsset, size: 64, radius: 12),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (meta.isNotEmpty)
                    Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary)),
                  const SizedBox(height: 2),
                  Text(
                    episode.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: played ? scheme.onSurfaceVariant : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (downloaded) ...[
                        Icon(Icons.download_done_rounded, size: 16, color: scheme.primary),
                        const SizedBox(width: 4),
                      ],
                      if (dm.isDownloading(episode.id)) ...[
                        SizedBox.square(
                          dimension: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: (dm.progressOf(episode.id) ?? -1) < 0 ? null : dm.progressOf(episode.id),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (lengthText != null)
                        Text(lengthText,
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      if (fraction != null && fraction > 0 && fraction < 1) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: fraction, minHeight: 4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (episode.hasAudio) _PlayButton(episode: episode),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.episode});
  final Episode episode;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final isCurrent = player.isCurrent(episode.id);
    final playing = player.isPlayingId(episode.id);
    return IconButton.filledTonal(
      tooltip: playing ? 'Pausar' : 'Reproducir',
      onPressed: () => EpisodeActions.play(context, episode),
      icon: isCurrent && player.buffering
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
          : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
    );
  }
}
