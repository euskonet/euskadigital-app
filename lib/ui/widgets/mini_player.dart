import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/player_service.dart';
import '../screens/player_screen.dart';
import 'artwork.dart';

/// Barra compacta encima de la navegación con lo que está sonando.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final now = player.current;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: now == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Material(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => PlayerScreen.show(context),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 4, 6),
                        child: Row(
                          children: [
                            Artwork(url: now.imageUrl, fallbackAsset: now.fallbackImage, size: 44, radius: 10),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(now.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(color: scheme.onSecondaryContainer)),
                                  Text(player.error ?? now.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                          color: player.error != null
                                              ? scheme.error
                                              : scheme.onSecondaryContainer.withValues(alpha: 0.8))),
                                ],
                              ),
                            ),
                            if (!now.isLive)
                              IconButton(
                                tooltip: 'Retroceder 15 segundos',
                                onPressed: () => player.skip(const Duration(seconds: -15)),
                                icon: const Icon(Icons.replay_rounded),
                              ),
                            IconButton(
                              tooltip: player.playing ? 'Pausar' : 'Reproducir',
                              onPressed: player.togglePlay,
                              icon: player.buffering
                                  ? const SizedBox.square(
                                      dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                                  : Icon(player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      size: 30),
                            ),
                            IconButton(
                              tooltip: 'Cerrar',
                              onPressed: player.stop,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      if (!now.isLive) const _ThinProgress(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _ThinProgress extends StatelessWidget {
  const _ThinProgress();

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerService>();
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final total = player.duration;
        final v = (total == null || total.inMilliseconds == 0)
            ? 0.0
            : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
        return LinearProgressIndicator(value: v, minHeight: 3, backgroundColor: Colors.transparent);
      },
    );
  }
}
