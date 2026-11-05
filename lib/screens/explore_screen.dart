import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_screen.dart';

/// Chip lọc theo nội dung bài; giữ cùng danh sách với web (apps/web/src/app/kham-pha/page.tsx).
const exploreChips = <String, List<String>>{
  'Dễ chăm': ['dễ', 'không hề cầu kì', 'chịu bóng'],
  'Kiểng lá': ['kiểng lá', 'lá'],
  'Phòng ngủ': ['phòng ngủ', 'phòng đọc'],
  'Phong thủy': ['may mắn', 'tài lộc', 'phong thủy'],
  'Gia vị': ['gia vị', 'ẩm thực'],
};

bool matchesChip(Article a, String chip) {
  final text = '${a.title} ${a.summary ?? ''} ${a.tags.join(' ')}'.toLowerCase();
  return (exploreChips[chip] ?? const []).any(text.contains);
}

Future<List<Article>> _loadArticles(ApiClient api) async {
  final res = await api.get('explore', query: {'page': 1, 'pageSize': 50}) as Map<String, dynamic>;
  return (res['items'] as List).cast<Map<String, dynamic>>().map(Article.fromJson).toList();
}

/// Khám phá: bài viết lấy từ `GET /api/explore`, cùng nguồn với trang /kham-pha của web.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String? _chip;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('Khám phá'), actions: const [AccountAction()]),
      body: LoadView<List<Article>>(
        load: () => _loadArticles(api),
        builder: (context, all, reload) {
          final chips = exploreChips.keys.where((c) => all.any((a) => matchesChip(a, c))).toList();
          final items = _chip == null ? all : all.where((a) => matchesChip(a, _chip!)).toList();
          final first = items.take(5).toList();
          final second = items.skip(5).take(4).toList();
          final rest = items.skip(9).toList();
          final t = Theme.of(context).textTheme;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.only(top: 4, bottom: 28), children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Chào bạn đến với\nChạm Xanh', style: t.headlineSmall),
                      const SizedBox(height: 6),
                      Text('Tìm loại cây phù hợp nhất cho không gian của bạn.', style: t.bodyMedium),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: CxColors.stone100,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => launchUrl(Uri.parse('${AppConfig.webBase}/cho-cay'), mode: LaunchMode.externalApplication),
                      child: const SizedBox(
                        width: 58,
                        height: 58,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.shopping_bag_outlined, size: 20),
                          Text('Chợ cây', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
              if (chips.isNotEmpty)
                SizedBox(
                  height: 56,
                  child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 10, 16, 8), children: [
                    for (final c in chips)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _SoftChip(label: c, on: _chip == c, onTap: () => setState(() => _chip = _chip == c ? null : c)),
                      ),
                  ]),
                ),
              if (items.isEmpty) const EmptyState(icon: Icons.explore_outlined, title: 'Chưa có bài khám phá'),
              if (first.isNotEmpty) _CardRow(items: first),
              if (second.isNotEmpty) ...[
                _Heading('Góc xanh cho bạn'),
                _CardRow(items: second),
              ],
              if (rest.isNotEmpty) ...[
                _Heading('Đọc thêm'),
                for (final a in rest) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: _ArticleRow(article: a)),
              ],
            ]),
          );
        },
      ),
    );
  }
}

void _open(BuildContext context, Article a) => Navigator.push(context, MaterialPageRoute(builder: (_) => ArticleScreen(slug: a.slug, title: a.title)));

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 12), child: Text(text, style: Theme.of(context).textTheme.headlineSmall));
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: on ? CxColors.emerald700 : CxColors.leaf,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: on ? Colors.white : CxColors.leafText)),
          ),
        ),
      );
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.items});
  final List<Article> items;
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: 128 + 76 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => ExplorePlantCard(article: items[i]),
      ),
    );
  }
}

class ExplorePlantCard extends StatelessWidget {
  const ExplorePlantCard({super.key, required this.article});
  final Article article;
  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final card = article.cover?.card;
    return SizedBox(
      width: 156,
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: CxColors.line)),
        child: InkWell(
          onTap: () => _open(context, article),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 128,
              width: double.infinity,
              child: card == null
                  ? Container(color: CxColors.emerald100, child: const Icon(Icons.eco_rounded, color: CxColors.emerald500))
                  : Image.network(api.mediaUrl(card), fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(article.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CxColors.stone900)),
                if (article.summary != null)
                  Text(article.summary!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, height: 1.3, color: CxColors.stone600)),
              ]),
            ),
          ]),
        ),
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
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: CxColors.line)),
      child: InkWell(
        onTap: () => _open(context, article),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            PlantImage(url: article.cover?.thumb == null ? null : api.mediaUrl(article.cover!.thumb!), size: 80),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CxColors.stone900)),
                if (article.summary != null) ...[
                  const SizedBox(height: 4),
                  Text(article.summary!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.35, color: CxColors.stone600)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Bài có cùng chip với bài đang đọc, thiếu thì bù bài mới; tối đa 6 bài.
List<Article> relatedArticles(Article current, List<Article> all) {
  final others = all.where((a) => a.id != current.id).toList();
  final chips = exploreChips.keys.where((c) => matchesChip(current, c)).toList();
  final same = others.where((a) => chips.any((c) => matchesChip(a, c))).toList();
  final fill = others.where((a) => !same.contains(a));
  return [...same, ...fill].take(6).toList();
}

class _ArticleData {
  _ArticleData(this.json, this.others, this.species, this.family);
  final Map<String, dynamic> json;
  final List<Article> others;
  final Map<String, dynamic>? species;
  final List<Map<String, dynamic>> family;
}

/// Chi tiết bài Khám phá theo Figma. Ô thông tin và "cùng họ" chỉ hiện khi bài gắn với một loài trong danh mục.
class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key, required this.slug, required this.title});
  final String slug, title;

  Future<_ArticleData> _load(ApiClient api) async {
    final json = await api.get('explore/${Uri.encodeComponent(slug)}') as Map<String, dynamic>;
    final others = await _loadArticles(api).catchError((_) => <Article>[]);
    Map<String, dynamic>? species;
    var family = <Map<String, dynamic>>[];
    final speciesId = json['speciesId'] as String?;
    if (speciesId != null) {
      try {
        species = await api.get('species/${Uri.encodeComponent(speciesId)}') as Map<String, dynamic>;
        final fam = species['family'] as String?;
        if (fam != null && fam.isNotEmpty) {
          final list = (await api.get('species', query: {'q': fam, 'limit': 30}) as List).cast<Map<String, dynamic>>();
          family = list.where((s) => s['family'] == fam && s['id'] != speciesId).take(8).toList();
        }
      } catch (_) {
        // Thiếu thông tin loài thì vẫn đọc được bài.
      }
    }
    return _ArticleData(json, others, species, family);
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: LoadView<_ArticleData>(
        load: () => _load(api),
        builder: (context, d, _) {
          final a = Article.fromJson(d.json);
          final photos = (d.json['photos'] as List?)?.cast<Map<String, dynamic>>().map(Media.fromJson).toList() ?? const <Media>[];
          final paragraphs = (a.body ?? '').split(RegExp(r'\n\s*\n')).where((s) => s.trim().isNotEmpty).toList();
          final related = relatedArticles(a, d.others);
          final chip = exploreChips.keys.where((c) => matchesChip(a, c)).firstOrNull;
          final cover = a.cover?.card;
          return CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 340,
              backgroundColor: CxColors.emerald800,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  tooltip: 'Chia sẻ',
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => launchUrl(Uri.parse('${AppConfig.webBase}/kham-pha/${a.slug}'), mode: LaunchMode.externalApplication),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  if (cover != null) Image.network(api.mediaUrl(cover), fit: BoxFit.cover) else Container(color: CxColors.emerald100),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.25, 0.65, 1],
                        colors: [Color(0x66000000), Color(0x00000000), Color(0x00FFFFFF), Colors.white],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (chip != null) ...[Pill(chip, bg: CxColors.leaf, fg: CxColors.leafText), const SizedBox(height: 10)],
                  Text(a.title, style: t.headlineMedium),
                  if (a.summary != null) ...[const SizedBox(height: 8), Text(a.summary!, style: t.bodyMedium)],
                  if (d.species != null) ...[const SizedBox(height: 16), _SpeciesFacts(species: d.species!)],
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
            ),
            if (related.isNotEmpty) ...[
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Text('Cây cùng cách chăm sóc', style: t.titleLarge))),
              SliverToBoxAdapter(child: _CardRow(items: related)),
            ],
            if (d.family.isNotEmpty) ...[
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 10), child: Text('Cây cùng họ ${d.species!['family']}', style: t.titleLarge))),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in d.family) Pill('${s['commonName'] ?? s['id']}', bg: CxColors.leaf, fg: CxColors.leafText),
                  ]),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ]);
        },
      ),
    );
  }
}

class _SpeciesFacts extends StatelessWidget {
  const _SpeciesFacts({required this.species});
  final Map<String, dynamic> species;

  @override
  Widget build(BuildContext context) {
    final difficulty = species['difficulty'];
    final facts = <(IconData, String, String?)>[
      (Icons.wb_sunny_outlined, 'Ánh sáng', species['light'] as String?),
      (Icons.water_drop_outlined, 'Tưới nước', species['water'] as String?),
      (Icons.spa_outlined, 'Độ khó', difficulty == null ? null : '$difficulty/5'),
      (Icons.account_tree_outlined, 'Họ', species['family'] as String?),
    ].where((f) => f.$3 != null && f.$3!.isNotEmpty).toList();
    return LayoutBuilder(
      builder: (context, box) => Wrap(spacing: 10, runSpacing: 10, children: [
        for (final (icon, label, value) in facts)
          Container(
            width: (box.maxWidth - 10) / 2,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: CxColors.stone100, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(icon, size: 20, color: CxColors.emerald700),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: CxColors.stone600)),
                  Text(value!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CxColors.stone900)),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}
