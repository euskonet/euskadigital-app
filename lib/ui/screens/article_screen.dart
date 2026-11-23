import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/episode.dart';
import '../format.dart';
import '../widgets/html_body.dart';
import '../widgets/net_image.dart';

/// Lectura de una noticia.
class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key, required this.item});
  final Episode item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Si la imagen destacada ya aparece en el cuerpo, no la repetimos.
    final showHero = item.imageUrl != null && !item.body.contains(item.imageUrl!);

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (item.link != null)
            IconButton(
              tooltip: 'Compartir',
              onPressed: () => SharePlus.instance.share(ShareParams(text: '${item.title}\n${item.link}')),
              icon: const Icon(Icons.ios_share_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(formatDate(item.pubDate).toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Text(item.title, style: theme.textTheme.headlineMedium),
          if (item.author != null) ...[
            const SizedBox(height: 8),
            Text(item.author!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 20),
          if (showHero) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: NetImage(imageUrl: item.imageUrl!, fit: BoxFit.cover),
            ),
            const SizedBox(height: 20),
          ],
          HtmlBody(item.body),
          if (item.link != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(item.link!), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Leer en euskadigital.eus'),
            ),
          ],
        ],
      ),
    );
  }
}
