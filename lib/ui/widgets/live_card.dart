import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../services/player_service.dart';
import '../theme.dart';

/// Tarjeta destacada del directo con botón grande de reproducir.
class LiveCard extends StatelessWidget {
  const LiveCard({super.key});

  @override
  Widget build(BuildContext context) {
    final live = context.read<AppConfig>().live;
    final player = context.watch<PlayerService>();
    final active = player.isLiveActive;
    final playing = active && player.playing;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        color: brandRed,
        child: InkWell(
          onTap: () => player.playLive(),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(opacity: 0.28, child: Image.asset('assets/images/live_cover.png', fit: BoxFit.cover)),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [brandRed.withValues(alpha: 0.95), const Color(0xFF8A0000).withValues(alpha: 0.85)],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LiveBadge(pulsing: playing),
                          const SizedBox(height: 12),
                          Text(live.title, style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(
                            playing ? 'Sonando ahora' : live.subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _BigPlay(playing: playing, loading: active && player.buffering),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigPlay extends StatelessWidget {
  const _BigPlay({required this.playing, required this.loading});
  final bool playing;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: playing ? 'Pausar directo' : 'Escuchar directo',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.read<PlayerService>().playLive(),
          child: SizedBox.square(
            dimension: 72,
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(strokeWidth: 3, color: brandRed),
                  )
                : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 44, color: brandRed),
          ),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  const _LiveBadge({required this.pulsing});
  final bool pulsing;

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(covariant _LiveBadge old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    if (widget.pulsing) {
      _c.repeat(reverse: true);
    } else {
      _c.value = 1;
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
            child: const CircleAvatar(radius: 4, backgroundColor: brandRed),
          ),
          const SizedBox(width: 6),
          const Text(
            'EN DIRECTO',
            style: TextStyle(color: brandRed, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}
