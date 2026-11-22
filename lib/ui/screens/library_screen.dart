import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/episode.dart';
import '../../services/library_store.dart';
import '../widgets/common.dart';
import '../widgets/episode_tile.dart';

/// Biblioteca personal: en curso, favoritos, descargas e historial.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryStore>();
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mi biblioteca'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'En curso'),
              Tab(text: 'Favoritos'),
              Tab(text: 'Descargas'),
              Tab(text: 'Historial'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _EpisodeList(
              episodes: lib.inProgress,
              empty: const MessageView(
                icon: Icons.headphones_rounded,
                title: 'Nada a medias',
                message: 'Los episodios que empieces a escuchar aparecerán aquí.',
              ),
            ),
            _EpisodeList(
              episodes: lib.favorites,
              empty: const MessageView(
                icon: Icons.favorite_border_rounded,
                title: 'Aún no tienes favoritos',
                message: 'Pulsa el corazón en un episodio para guardarlo aquí.',
              ),
            ),
            _EpisodeList(
              episodes: lib.downloads,
              empty: const MessageView(
                icon: Icons.download_rounded,
                title: 'Sin descargas',
                message: 'Descarga episodios para escucharlos sin conexión.',
              ),
            ),
            _EpisodeList(
              episodes: lib.history,
              empty: const MessageView(
                icon: Icons.history_rounded,
                title: 'Historial vacío',
                message: 'Aquí verás lo último que has escuchado.',
              ),
              footer: lib.history.isEmpty
                  ? null
                  : Center(
                      child: TextButton.icon(
                        onPressed: lib.clearHistory,
                        icon: const Icon(Icons.delete_sweep_rounded),
                        label: const Text('Borrar historial'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeList extends StatelessWidget {
  const _EpisodeList({required this.episodes, required this.empty, this.footer});
  final List<Episode> episodes;
  final Widget empty;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) return empty;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: episodes.length + (footer == null ? 0 : 1),
      itemBuilder: (_, i) => i == episodes.length ? footer! : EpisodeTile(episode: episodes[i]),
    );
  }
}
