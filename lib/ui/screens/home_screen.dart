import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/feed_repository.dart';
import '../../services/library_store.dart';
import '../widgets/artwork.dart';
import '../widgets/brand_header.dart';
import '../widgets/common.dart';
import '../widgets/episode_actions.dart';
import '../widgets/episode_tile.dart';
import '../widgets/live_card.dart';
import '../widgets/news_card.dart';
import '../widgets/twitch_card.dart';
import 'episode_screen.dart';
import 'videos_screen.dart';

/// Inicio: directo, continuar escuchando, últimos episodios y noticias.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  /// Cambia de pestaña (1 = Programas, 2 = Noticias...).
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final feeds = context.watch<FeedRepository>();
    final lib = context.watch<LibraryStore>();
    final latest = feeds.latestEpisodes(limit: 12);
    final news = feeds.news.items.take(3).toList();
    final inProgress = lib.inProgress.take(10).toList();
    final videos = feeds.videos.items.take(8).toList();
    final loadingFirstTime = latest.isEmpty && feeds.config.allPrograms.any((p) => feeds.state(p.id).loading);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => feeds.refreshAll(force: true),
        child: CustomScrollView(
          slivers: [
            const BrandSliverAppBar('EuskaDigital'),
            const SliverToBoxAdapter(child: LiveCard()),
            const SliverToBoxAdapter(child: TwitchCard()),
            if (inProgress.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader('Continúa escuchando')),
              SliverToBoxAdapter(child: _ContinueRow(episodes: inProgress)),
            ],
            SliverToBoxAdapter(
              child: SectionHeader('Últimos episodios', action: 'Programas', onAction: () => onOpenTab(1)),
            ),
            if (loadingFirstTime)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (latest.isEmpty)
              SliverToBoxAdapter(
                child: MessageView(
                  icon: Icons.wifi_off_rounded,
                  title: 'No hay episodios disponibles',
                  message: 'Comprueba tu conexión y vuelve a intentarlo.',
                  actionLabel: 'Reintentar',
                  onAction: () => feeds.refreshAll(force: true),
                ),
              )
            else
              SliverList.builder(
                itemCount: latest.length,
                itemBuilder: (_, i) => EpisodeTile(episode: latest[i]),
              ),
            if (videos.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  'Últimos vídeos',
                  action: 'Ver todos',
                  onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VideosScreen())),
                ),
              ),
              SliverToBoxAdapter(child: LatestVideosRow(videos: videos)),
            ],
            if (news.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader('Noticias', action: 'Ver todas', onAction: () => onOpenTab(2)),
              ),
              SliverList.builder(
                itemCount: news.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: NewsCard(item: news[i], compact: true),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _ContinueRow extends StatelessWidget {
  const _ContinueRow({required this.episodes});
  final List episodes;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    final theme = Theme.of(context);
    return SizedBox(
      height: 214,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: episodes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final e = episodes[i];
          final v = EpisodeVisuals.of(context, e);
          return SizedBox(
            width: 140,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EpisodeScreen(episode: e))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Artwork(url: v.imageUrl, fallbackAsset: v.fallbackAsset, size: 140, radius: 16),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: IconButton.filled(
                          tooltip: 'Continuar',
                          onPressed: () => EpisodeActions.play(context, e),
                          icon: const Icon(Icons.play_arrow_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: lib.fractionOf(e) ?? 0, minHeight: 4),
                  ),
                  const SizedBox(height: 6),
                  Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
