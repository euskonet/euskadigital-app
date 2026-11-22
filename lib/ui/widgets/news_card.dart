import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/episode.dart';
import '../../services/feed_parser.dart';
import '../format.dart';
import '../screens/article_screen.dart';

/// Tarjeta de noticia. En modo compacto, imagen pequeña a la izquierda.
class NewsCard extends StatelessWidget {
  const NewsCard({super.key, required this.item, this.compact = false});
  final Episode item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final excerpt = FeedParser.stripHtml(item.description ?? '').replaceAll('\n', ' ');
    void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArticleScreen(item: item)));

    final image = item.imageUrl == null
        ? null
        : CachedNetworkImage(
            imageUrl: item.imageUrl!,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(color: scheme.surfaceContainerHighest),
            errorWidget: (_, _, _) => Container(
              color: scheme.surfaceContainerHighest,
              child: Icon(Icons.newspaper_rounded, color: scheme.onSurfaceVariant),
            ),
          );

    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formatDate(item.pubDate), style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary)),
        const SizedBox(height: 4),
        Text(item.title,
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium),
        if (!compact && excerpt.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(excerpt,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ],
    );

    return Card(
      child: InkWell(
        onTap: open,
        child: compact
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (image != null) ...[
                      ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox.square(dimension: 80, child: image)),
                      const SizedBox(width: 14),
                    ],
                    Expanded(child: texts),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (item.imageUrl != null)
                    // Imagen entera, con su proporción original (sin recortar).
                    CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      placeholder: (_, _) => AspectRatio(
                        aspectRatio: 1,
                        child: Container(color: scheme.surfaceContainerHighest),
                      ),
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  Padding(padding: const EdgeInsets.all(16), child: texts),
                ],
              ),
      ),
    );
  }
}
