import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../services/feed_repository.dart';
import '../../services/player_service.dart';
import '../format.dart';
import '../widgets/artwork.dart';
import '../widgets/episode_actions.dart';

/// Reproductor a pantalla completa (hoja modal).
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    // SafeArea inferior: deja sitio a la barra de navegación / gestos de
    // Android (la app se dibuja de borde a borde).
    builder: (_) => const FractionallySizedBox(heightFactor: 1, child: SafeArea(top: false, child: PlayerScreen())),
  );

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final now = player.current;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (now == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox.shrink();
    }

    // Si por la radio suena uno de nuestros programas, su portada.
    final liveProgram = now.isLive ? player.liveProgram : null;
    final feeds = context.watch<FeedRepository>();
    final artUrl = liveProgram != null ? feeds.programImage(liveProgram.id) : now.imageUrl;
    final artFallback = liveProgram?.fallbackImage ?? now.fallbackImage;

    return LayoutBuilder(
      builder: (context, c) {
        final art = (c.maxWidth - 64).clamp(120.0, c.maxHeight * 0.42);
        return Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
          child: Column(
            children: [
              // La portada ocupa el espacio libre y se encoge si falta sitio
              // (pantallas bajas, letra grande, títulos largos...).
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: art, maxHeight: art),
                      child: Artwork(url: artUrl, fallbackAsset: artFallback, radius: 28),
                    ),
                  ),
                ),
              ),
              if (now.isLive) ...[
                _LiveLabel(text: now.title),
                const SizedBox(height: 10),
                Text(
                  player.liveTrack ?? now.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall,
                ),
              ] else ...[
                Text(
                  now.subtitle.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Text(
                  now.title,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall,
                ),
              ],
              if (player.error != null) ...[
                const SizedBox(height: 8),
                Text(player.error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 24),
              if (!now.isLive) const _SeekBar(),
              const SizedBox(height: 12),
              _Controls(isLive: now.isLive),
              const SizedBox(height: 16),
              _BottomActions(isLive: now.isLive),
            ],
          ),
        );
      },
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar();
  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerService>();
    final theme = Theme.of(context);
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        final total = player.duration ?? player.current?.episode?.duration ?? Duration.zero;
        final pos = snap.data ?? Duration.zero;
        final max = total.inMilliseconds.toDouble().clamp(1.0, double.infinity);
        final value = (_dragValue ?? pos.inMilliseconds.toDouble()).clamp(0.0, max);
        final shown = Duration(milliseconds: value.round());
        final style = theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 6),
              child: Slider(
                value: value,
                max: max,
                onChanged: (v) => setState(() => _dragValue = v),
                onChangeEnd: (v) {
                  player.seek(Duration(milliseconds: v.round()));
                  setState(() => _dragValue = null);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDuration(shown), style: style),
                  Text(total == Duration.zero ? '--:--' : '-${formatDuration(total - shown)}', style: style),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// «● EUSKADIGITAL EN DIRECTO»: una sola etiqueta para el directo.
class _LiveLabel extends StatelessWidget {
  const _LiveLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.isLive});
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final scheme = Theme.of(context).colorScheme;
    final play = SizedBox.square(
      dimension: 84,
      child: FilledButton(
        style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
        onPressed: player.togglePlay,
        child: player.buffering
            ? SizedBox.square(dimension: 32, child: CircularProgressIndicator(strokeWidth: 3, color: scheme.onPrimary))
            : Icon(player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 48),
      ),
    );
    if (isLive) return play;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          iconSize: 36,
          tooltip: 'Retroceder 15 segundos',
          onPressed: () => player.skip(const Duration(seconds: -15)),
          icon: const Icon(Icons.replay_rounded),
        ),
        play,
        IconButton(
          iconSize: 36,
          tooltip: 'Avanzar 30 segundos',
          onPressed: () => player.skip(const Duration(seconds: 30)),
          icon: const Icon(Icons.forward_30_rounded),
        ),
      ],
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.isLive});
  final bool isLive;

  static const _speeds = [0.8, 1.0, 1.2, 1.5, 1.75, 2.0];

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final episode = player.current?.episode;
    final sleepActive = player.sleepAt != null || player.sleepAtEnd;
    String speedLabel(double s) =>
        '${s.toStringAsFixed(s == s.roundToDouble() ? 0 : 2).replaceAll(RegExp(r'0$'), '').replaceAll('.', ',')}×';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (!isLive)
          PopupMenuButton<double>(
            tooltip: 'Velocidad',
            initialValue: player.speed,
            onSelected: player.setSpeed,
            itemBuilder: (_) => [for (final s in _speeds) PopupMenuItem(value: s, child: Text(speedLabel(s)))],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(speedLabel(player.speed), style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
        if (isLive && context.read<AppConfig>().live.hasQualityChoice)
          PopupMenuButton<LiveQuality>(
            tooltip: player.liveQuality == LiveQuality.high ? 'Calidad: alta' : 'Calidad: baja',
            initialValue: player.liveQuality,
            onSelected: player.setLiveQuality,
            icon: Icon(
              player.liveQuality == LiveQuality.high
                  ? Icons.signal_cellular_alt_rounded
                  : Icons.signal_cellular_alt_1_bar_rounded,
            ),
            itemBuilder: (_) => [
              for (final (q, label) in [(LiveQuality.high, 'Alta'), (LiveQuality.low, 'Baja')])
                CheckedPopupMenuItem(value: q, checked: player.liveQuality == q, child: Text(label)),
            ],
          ),
        PopupMenuButton<int>(
          tooltip: 'Temporizador',
          icon: Icon(
            sleepActive ? Icons.bedtime_rounded : Icons.bedtime_outlined,
            color: sleepActive ? Theme.of(context).colorScheme.primary : null,
          ),
          onSelected: (m) {
            if (m == 0) {
              player.cancelSleepTimer();
            } else if (m == -1) {
              player.setSleepAtEnd();
            } else {
              player.setSleepTimer(Duration(minutes: m));
            }
          },
          itemBuilder: (_) => [
            if (sleepActive) const PopupMenuItem(value: 0, child: Text('Desactivar temporizador')),
            for (final m in [15, 30, 45, 60]) PopupMenuItem(value: m, child: Text('Parar en $m minutos')),
            if (!isLive) const PopupMenuItem(value: -1, child: Text('Al acabar el episodio')),
          ],
        ),
        if (episode != null)
          IconButton(
            tooltip: 'Compartir',
            onPressed: () => EpisodeActions.share(context, episode, programTitle: player.current?.subtitle),
            icon: const Icon(Icons.ios_share_rounded),
          ),
      ],
    );
  }
}
