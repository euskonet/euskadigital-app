import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../services/feed_repository.dart';
import '../widgets/artwork.dart';
import '../widgets/brand_header.dart';
import 'podcast_screen.dart';

/// Rejilla de programas agrupados.
class ProgramsScreen extends StatelessWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    final feeds = context.watch<FeedRepository>();
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => feeds.refreshAll(force: true),
        child: CustomScrollView(
          slivers: [
            const BrandSliverAppBar('Programas'),
            for (final group in config.programGroups) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                sliver: SliverToBoxAdapter(child: Text(group.title, style: theme.textTheme.titleLarge)),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: group.programs.length,
                  itemBuilder: (context, i) => _ProgramCard(program: group.programs[i]),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program});
  final ProgramConfig program;

  @override
  Widget build(BuildContext context) {
    final feeds = context.watch<FeedRepository>();
    final state = feeds.state(program.id);
    final theme = Theme.of(context);
    final count = state.items.where((e) => e.hasAudio).length;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PodcastScreen(program: program))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // La portada ocupa el espacio que dejan los textos: con títulos
          // de dos líneas o letra grande se reduce en vez de desbordarse.
          Flexible(
            child: Artwork(
              url: state.channel?.imageUrl,
              fallbackAsset: program.fallbackImage,
              radius: 20,
              heroTag: 'program-${program.id}',
            ),
          ),
          const SizedBox(height: 8),
          Text(program.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
          Text(
            state.feed == null ? (state.loading ? 'Cargando…' : 'Sin conexión') : '$count episodios',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
