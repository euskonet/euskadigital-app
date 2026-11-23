import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../services/twitch_live_service.dart';
import '../screens/twitch_screen.dart';

/// Tarjeta de Inicio que solo aparece mientras el canal de Twitch está en
/// directo, con la vista previa de la emisión.
class TwitchCard extends StatelessWidget {
  const TwitchCard({super.key});

  static const twitchPurple = Color(0xFF9146FF);

  @override
  Widget build(BuildContext context) {
    final twitch = context.read<AppConfig>().twitch;
    final live = context.watch<TwitchLiveService?>();
    final visible = twitch != null && live != null && live.isLive;
    final theme = Theme.of(context);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Card(
                color: twitchPurple,
                child: InkWell(
                  onTap: () => TwitchScreen.open(context, twitch),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 128,
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: live.previewUrl == null
                                  ? const ColoredBox(
                                      color: Color(0xFF6E33CC),
                                      child: Icon(Icons.live_tv_rounded, color: Colors.white),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: live.previewUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (_, _) => const ColoredBox(color: Color(0xFF6E33CC)),
                                      errorWidget: (_, _, _) => const ColoredBox(
                                        color: Color(0xFF6E33CC),
                                        child: Icon(Icons.live_tv_rounded, color: Colors.white),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEB0400),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'EN DIRECTO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                twitch.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                              ),
                              const Text('Toca para verlo', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
