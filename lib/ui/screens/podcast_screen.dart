import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/episode.dart';
import '../../services/feed_parser.dart';
import '../../services/feed_repository.dart';
import '../widgets/artwork.dart';
import 'alerts_screen.dart';
import '../widgets/common.dart';
import '../widgets/episode_actions.dart';
import '../widgets/episode_tile.dart';

/// Ficha de un programa: portada, descripción y lista de episodios.
class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key, required this.program});
  final ProgramConfig program;

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  bool _newestFirst = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FeedRepository>().refresh(widget.program.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final feeds = context.watch<FeedRepository>();
    final state = feeds.state(widget.program.id);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final channel = state.channel;
    final description = FeedParser.stripHtml(channel?.description ?? '');

    final episodes = List<Episode>.of(state.items.where((e) => e.hasAudio));
    if (!_newestFirst) {
      episodes.sort((a, b) => (a.pubDate ?? DateTime(1970)).compareTo(b.pubDate ?? DateTime(1970)));
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => feeds.refresh(widget.program.id, force: true),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(widget.program.title),
              actions: [AlertBellButton(program: widget.program)],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Artwork(
                          url: channel?.imageUrl,
                          fallbackAsset: widget.program.fallbackImage,
                          size: 132,
                          radius: 20,
                          heroTag: 'program-${widget.program.id}',
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // El nombre de la configuración: los feeds de WordPress
                              // añaden « - EuskaDigital» al título del canal.
                              Text(widget.program.title, style: theme.textTheme.headlineSmall),
                              if (channel?.author != null &&
                                  !channel!.author!.toLowerCase().contains(widget.program.title.toLowerCase())) ...[
                                const SizedBox(height: 4),
                                Text(channel.author!,
                                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary)),
                              ],
                              const SizedBox(height: 12),
                              if (episodes.isNotEmpty)
                                FilledButton.icon(
                                  onPressed: () => EpisodeActions.play(context, state.items.firstWhere((e) => e.hasAudio)),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Último episodio'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          alignment: Alignment.topCenter,
                          child: Text(
                            description,
                            maxLines: _expanded ? null : 3,
                            overflow: _expanded ? null : TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (state.error != null && state.feed != null) SliverToBoxAdapter(child: InlineNotice(state.error!)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${episodes.length} episodios', style: theme.textTheme.titleMedium),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _newestFirst = !_newestFirst),
                      icon: const Icon(Icons.swap_vert_rounded),
                      label: Text(_newestFirst ? 'Más recientes' : 'Más antiguos'),
                    ),
                  ],
                ),
              ),
            ),
            if (state.feed == null && state.loading)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
            else if (state.feed == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MessageView(
                  icon: Icons.wifi_off_rounded,
                  title: 'No se ha podido cargar el programa',
                  message: state.error,
                  actionLabel: 'Reintentar',
                  onAction: () => feeds.refresh(widget.program.id, force: true),
                ),
              )
            else
              SliverList.builder(
                itemCount: episodes.length,
                itemBuilder: (_, i) => EpisodeTile(episode: episodes[i], showProgram: false),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
