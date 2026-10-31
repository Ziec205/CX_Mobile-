import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/chat_action.dart';
import '../widgets/common.dart';

/// Khám phá: bài viết về cây do biên tập viên đăng (cùng nguồn với trang /kham-pha của web).
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('Khám phá'), actions: const [ChatAction()]),
      body: LoadView<List<Article>>(
        load: () async {
          final res = await api.get('explore', query: {'page': 1, 'pageSize': 30}) as Map<String, dynamic>;
          return (res['items'] as List).cast<Map<String, dynamic>>().map(Article.fromJson).toList();
        },
        builder: (context, items, reload) => RefreshIndicator(
          onRefresh: reload,
          child: items.isEmpty
              ? ListView(children: const [EmptyState(icon: Icons.explore_outlined, title: 'Chưa có bài khám phá')])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, i) => i == 0 ? _Hero(article: items[0]) : _ArticleRow(article: items[i]),
                ),
        ),
      ),
    );
  }
}

void _open(BuildContext context, Article a) => Navigator.push(context, MaterialPageRoute(builder: (_) => ArticleScreen(slug: a.slug, title: a.title)));

class _Hero extends StatelessWidget {
  const _Hero({required this.article});
  final Article article;
  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, article),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: article.cover?.card == null
                ? Container(color: CxColors.emerald100, child: const Icon(Icons.eco_rounded, size: 64, color: CxColors.emerald500))
                : Image.network(api.mediaUrl(article.cover!.card!), fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Pill('Bài hôm nay', bg: CxColors.wood100, fg: CxColors.wood800, icon: Icons.wb_sunny_outlined),
              const SizedBox(height: 10),
              Text(article.title, style: t.headlineSmall),
              if (article.summary != null) ...[const SizedBox(height: 6), Text(article.summary!, style: t.bodyMedium, maxLines: 3, overflow: TextOverflow.ellipsis)],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ArticleRow extends StatelessWidget {
  const _ArticleRow({required this.article});
  final Article article;
  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, article),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            PlantImage(url: article.cover?.thumb == null ? null : api.mediaUrl(article.cover!.thumb!), size: 88),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(article.title, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (article.summary != null) ...[const SizedBox(height: 4), Text(article.summary!, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)],
                if (article.publishAt != null) ...[const SizedBox(height: 6), Text(vnDate(article.publishAt!), style: t.bodySmall)],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key, required this.slug, required this.title});
  final String slug, title;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: LoadView<Map<String, dynamic>>(
        load: () async => await api.get('explore/${Uri.encodeComponent(slug)}') as Map<String, dynamic>,
        builder: (context, j, _) {
          final a = Article.fromJson(j);
          final photos = (j['photos'] as List?)?.cast<Map<String, dynamic>>().map(Media.fromJson).toList() ?? const <Media>[];
          final paragraphs = (a.body ?? '').split(RegExp(r'\n\s*\n')).where((s) => s.trim().isNotEmpty).toList();
          return ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            if (a.cover?.card != null) AspectRatio(aspectRatio: 16 / 10, child: Image.network(api.mediaUrl(a.cover!.card!), fit: BoxFit.cover)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title, style: t.headlineMedium),
                if (a.summary != null) ...[const SizedBox(height: 10), Text(a.summary!, style: t.bodyLarge?.copyWith(color: CxColors.stone600, fontWeight: FontWeight.w500))],
                const SizedBox(height: 16),
                for (var i = 0; i < paragraphs.length; i++) ...[
                  Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(paragraphs[i].trim(), style: t.bodyLarge)),
                  if (i + 1 < photos.length && photos[i + 1].card != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(api.mediaUrl(photos[i + 1].card!))),
                    ),
                ],
                if (a.tags.isNotEmpty) Wrap(spacing: 6, runSpacing: 6, children: [for (final tag in a.tags) Pill('#$tag', bg: CxColors.stone100, fg: CxColors.stone700)]),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
