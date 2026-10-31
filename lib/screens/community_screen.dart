import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/chat_action.dart';
import '../widgets/common.dart';

/// Cộng đồng: hỏi đáp, khoe cây, kinh nghiệm (dùng chung dữ liệu với web).
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String? _type;
  final _items = <PostSummary>[];
  int _page = 1;
  bool _loading = false, _done = false;
  Object? _error;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _more();
    });
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _items.clear();
    _page = 1;
    _done = false;
    _error = null;
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _done) return;
    setState(() => _loading = true);
    try {
      final res = await context.read<AppState>().api.get('community/posts', query: {'type': _type, 'page': _page}) as Map<String, dynamic>;
      final list = (res['items'] as List).cast<Map<String, dynamic>>().map(PostSummary.fromJson).toList();
      setState(() {
        _items.addAll(list);
        _page++;
        _done = list.length < 20;
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cộng đồng'), actions: const [ChatAction()]),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-post',
        backgroundColor: CxColors.emerald700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Đăng bài'),
        onPressed: () async {
          final id = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const NewPostScreen()));
          if (id != null && context.mounted) {
            _reload();
            Navigator.push(context, MaterialPageRoute(builder: (_) => PostScreen(postId: id)));
          }
        },
      ),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), children: [
            for (final e in {null: 'Tất cả', ...postTypeLabel}.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: _type == e.key,
                  showCheckmark: false,
                  labelStyle: TextStyle(color: _type == e.key ? Colors.white : CxColors.stone700, fontWeight: FontWeight.w600),
                  onSelected: (_) {
                    setState(() => _type = e.key);
                    _reload();
                  },
                ),
              ),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: _items.isEmpty && _error != null
                ? ListView(children: [ErrorState(error: _error, onRetry: _reload)])
                : _items.isEmpty && !_loading
                    ? ListView(children: const [EmptyState(icon: Icons.forum_outlined, title: 'Chưa có bài viết', message: 'Hãy là người đầu tiên đặt câu hỏi!')])
                    : ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: _items.length + (_loading ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => i >= _items.length
                            ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                            : _PostCard(post: _items[i]),
                      ),
          ),
        ),
      ]),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});
  final PostSummary post;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final api = context.read<AppState>().api;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostScreen(postId: post.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Pill(postTypeLabel[post.type] ?? post.type, bg: post.type == 'Showcase' ? CxColors.wood100 : CxColors.emerald50, fg: post.type == 'Showcase' ? CxColors.wood800 : CxColors.emerald800),
                  if (post.answered) ...[const SizedBox(width: 6), const Pill('Đã giải đáp', icon: Icons.check_rounded)],
                ]),
                const SizedBox(height: 8),
                Text(post.title, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(post.excerpt, style: t.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text('${post.author.name} · ${timeAgo(post.createdAt)} · ♥ ${post.likes} · 💬 ${post.comments}', style: t.bodySmall),
              ]),
            ),
            if (post.thumbUrl != null) ...[const SizedBox(width: 12), PlantImage(url: api.mediaUrl(post.thumbUrl!), size: 76, radius: 14)],
          ]),
        ),
      ),
    );
  }
}

class PostScreen extends StatefulWidget {
  const PostScreen({super.key, required this.postId});
  final String postId;
  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _comment = TextEditingController();
  bool _sending = false;
  Key _key = UniqueKey();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await context.read<AppState>().api.post('community/posts/${widget.postId}/comments', {'body': text});
      _comment.clear();
      setState(() => _key = UniqueKey());
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _like(String path, bool liked) async {
    final api = context.read<AppState>().api;
    try {
      liked ? await api.delete(path) : await api.put(path);
      setState(() => _key = UniqueKey());
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Bài viết')),
      body: Column(children: [
        Expanded(
          child: LoadView<PostDetail>(
            key: _key,
            load: () async => PostDetail.fromJson(await api.get('community/posts/${widget.postId}') as Map<String, dynamic>),
            builder: (context, p, reload) => RefreshIndicator(
              onRefresh: reload,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
                Pill(postTypeLabel[p.type] ?? p.type),
                const SizedBox(height: 10),
                Text(p.title, style: t.headlineSmall),
                const SizedBox(height: 6),
                Text('${p.author.name}${p.author.expert ? ' · Chuyên gia' : ''} · ${timeAgo(p.createdAt)}', style: t.bodySmall),
                const SizedBox(height: 14),
                SelectableText(p.body, style: t.bodyLarge),
                for (final m in p.photos)
                  if (m.card != null) Padding(padding: const EdgeInsets.only(top: 12), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(api.mediaUrl(m.card!)))),
                const SizedBox(height: 8),
                Row(children: [
                  TextButton.icon(
                    onPressed: () => _like('community/posts/${p.id}/like', p.liked),
                    icon: Icon(p.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: p.liked ? CxColors.danger : null),
                    label: Text('${p.likes} thích'),
                  ),
                ]),
                const Divider(),
                Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('${p.comments.length} bình luận', style: t.titleMedium)),
                for (final c in p.comments)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.isBest ? CxColors.emerald50 : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.isBest ? CxColors.emerald200 : CxColors.stone200),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${c.author.name}${c.author.expert ? ' · Chuyên gia' : ''}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                        if (c.isBest) const Pill('Hay nhất', icon: Icons.star_rounded),
                      ]),
                      const SizedBox(height: 4),
                      Text(c.body, style: t.bodyMedium?.copyWith(color: CxColors.stone900)),
                      Row(children: [
                        Text(timeAgo(c.createdAt), style: t.bodySmall),
                        const Spacer(),
                        TextButton.icon(
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          onPressed: () => _like('community/comments/${c.id}/like', c.liked),
                          icon: Icon(c.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 18, color: c.liked ? CxColors.danger : null),
                          label: Text('${c.likes}'),
                        ),
                      ]),
                    ]),
                  ),
              ]),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: CxColors.stone200))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _comment,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 3000,
                  decoration: const InputDecoration(hintText: 'Viết bình luận…', counterText: '', isDense: true),
                ),
              ),
              IconButton(
                tooltip: 'Gửi',
                onPressed: _sending ? null : _send,
                icon: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded, color: CxColors.emerald700),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key});
  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _type = 'Question';
  final _photos = <XFile>[];
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_type == 'Showcase' && _photos.isEmpty) return showInfo(context, 'Bài khoe cây cần ít nhất 1 ảnh');
    setState(() => _busy = true);
    final api = context.read<AppState>().api;
    try {
      final ids = <String>[];
      for (final f in _photos) {
        ids.add(await api.upload(f.path));
      }
      final res = await api.post('community/posts', {'type': _type, 'title': _title.text.trim(), 'body': _body.text.trim(), 'mediaIds': ids}) as Map<String, dynamic>;
      if (mounted) Navigator.pop(context, res['id'] as String);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng bài')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          SegmentedButton<String>(
            segments: [for (final e in postTypeLabel.entries) ButtonSegment(value: e.key, label: Text(e.value))],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _title,
            maxLength: 150,
            decoration: const InputDecoration(labelText: 'Tiêu đề'),
            validator: (v) => (v ?? '').trim().length < 5 ? 'Tiêu đề ít nhất 5 ký tự' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _body,
            minLines: 6,
            maxLines: 14,
            decoration: const InputDecoration(labelText: 'Nội dung', alignLabelWithHint: true),
            validator: (v) => (v ?? '').trim().length < 10 ? 'Nội dung ít nhất 10 ký tự' : null,
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in _photos)
              Stack(children: [
                PlantImage(file: File(f.path), size: 84),
                Positioned(
                  right: 0,
                  top: 0,
                  child: InkWell(onTap: () => setState(() => _photos.remove(f)), child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white))),
                ),
              ]),
            if (_photos.length < 10)
              OutlinedButton.icon(
                onPressed: () async {
                  final list = await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 2000, limit: 10 - _photos.length);
                  setState(() => _photos.addAll(list));
                },
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Thêm ảnh'),
              ),
          ]),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Đăng'),
          ),
        ]),
      ),
    );
  }
}
