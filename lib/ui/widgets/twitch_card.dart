import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../screens/twitch_screen.dart';

/// Acceso al canal de Twitch desde Inicio.
class TwitchCard extends StatelessWidget {
  const TwitchCard({super.key});

  static const twitchPurple = Color(0xFF9146FF);

  @override
  Widget build(BuildContext context) {
    final twitch = context.read<AppConfig>().twitch;
    if (twitch == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        child: InkWell(
          onTap: () => TwitchScreen.open(context, twitch),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: twitchPurple, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.live_tv_rounded, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(twitch.title, style: theme.textTheme.titleMedium),
                      if (twitch.subtitle != null)
                        Text(twitch.subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
