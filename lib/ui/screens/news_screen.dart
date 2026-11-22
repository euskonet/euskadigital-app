import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/feed_repository.dart';
import '../widgets/common.dart';
import '../widgets/news_card.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final feeds = context.watch<FeedRepository>();
    final state = feeds.news;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => feeds.refresh(FeedRepository.newsId, force: true),
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(title: Text(feeds.config.news.title)),
            if (state.error != null && state.feed != null) SliverToBoxAdapter(child: InlineNotice(state.error!)),
            if (state.feed == null && state.loading)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
            else if (state.items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MessageView(
                  icon: Icons.newspaper_rounded,
                  title: state.feed == null ? 'No se han podido cargar las noticias' : 'No hay noticias',
                  message: state.error,
                  actionLabel: 'Reintentar',
                  onAction: () => feeds.refresh(FeedRepository.newsId, force: true),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.separated(
                  itemCount: state.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => NewsCard(item: state.items[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
