import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Danh sách hội thoại, cập nhật tức thì qua SignalR.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Conversation>? _items;
  Object? _error;
  StreamSubscription<ChatMessage>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = context.read<AppState>().realtime.messages.listen((_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = (await context.read<AppState>().api.get('conversations') as List).cast<Map<String, dynamic>>().map(Conversation.fromJson).toList();
      if (mounted) {
        setState(() {
          _items = list;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin nhắn'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: app.realtime.connected,
            builder: (_, on, _) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(children: [
                Icon(Icons.circle, size: 10, color: on ? CxColors.emerald500 : CxColors.stone300),
                const SizedBox(width: 6),
                Text(on ? 'Trực tuyến' : 'Đang kết nối…', style: t.bodySmall),
              ]),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _items == null
            ? (_error != null ? ListView(children: [ErrorState(error: _error, onRetry: _load)]) : const Center(child: CircularProgressIndicator()))
            : _items!.isEmpty
                ? ListView(children: const [
                    EmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'Chưa có cuộc trò chuyện', message: 'Khi bạn nhắn với người bán/mua cây trên Chạm Xanh, tin nhắn sẽ hiện ở đây.'),
                  ])
                : ListView.separated(
                    itemCount: _items!.length,
                    separatorBuilder: (_, _) => const Divider(indent: 84),
                    itemBuilder: (context, i) {
                      final c = _items![i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: PlantImage(url: c.thumbUrl == null ? null : app.api.mediaUrl(c.thumbUrl!), size: 52, radius: 26),
                        title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium?.copyWith(fontWeight: c.unread > 0 ? FontWeight.w800 : FontWeight.w600)),
                        subtitle: Text(c.lastPreview ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          if (c.lastAt != null) Text(timeAgo(c.lastAt!), style: t.bodySmall),
                          if (c.unread > 0) ...[
                            const SizedBox(height: 4),
                            Badge(label: Text('${c.unread}'), backgroundColor: CxColors.emerald700),
                          ],
                        ]),
                        onTap: () async {
                          app.clearUnread(c.unread);
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)));
                          _load();
                        },
                      );
                    },
                  ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversation});
  final Conversation conversation;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <ChatMessage>[];
  final _text = TextEditingController();
  StreamSubscription<ChatMessage>? _sub;
  bool _loading = true, _sending = false, _hasMore = true;
  Object? _error;

  String get _id => widget.conversation.id;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _sub = app.realtime.messages.where((m) => m.conversationId == _id).listen((m) {
      final i = _messages.indexWhere((x) => x.id == m.id);
      setState(() => i >= 0 ? _messages[i] = m : _messages.insert(0, m));
      if (m.senderId != app.me?.id) _markRead();
    });
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load({bool older = false}) async {
    final api = context.read<AppState>().api;
    try {
      final before = older && _messages.isNotEmpty ? _messages.last.createdAt.toUtc().toIso8601String() : null;
      final list = (await api.get('conversations/$_id/messages', query: {'before': before, 'limit': 50}) as List)
          .cast<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();
      setState(() {
        if (!older) _messages.clear();
        _messages.addAll(list.where((m) => !_messages.any((x) => x.id == m.id)));
        _hasMore = list.length == 50;
        _loading = false;
        _error = null;
      });
      if (!older) _markRead();
    } catch (e) {
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _markRead() => context.read<AppState>().api.post('conversations/$_id/read').catchError((_) => null);

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final m = ChatMessage.fromJson(await context.read<AppState>().api.post('conversations/$_id/messages', {'type': 'Text', 'text': text}) as Map<String, dynamic>);
      _text.clear();
      setState(() {
        if (!_messages.any((x) => x.id == m.id)) _messages.insert(0, m);
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AppState>().me?.id;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.conversation.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _messages.isEmpty
                  ? ErrorState(error: _error, onRetry: _load)
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (_hasMore && n.metrics.pixels > n.metrics.maxScrollExtent - 200) {
                          _hasMore = false;
                          _load(older: true);
                        }
                        return false;
                      },
                      child: ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          final mine = m.senderId == me;
                          final system = m.type == 'System';
                          final text = m.type == 'Offer' && m.offerAmount != null ? 'Trả giá: ${vnd(m.offerAmount!)}' : m.text ?? (m.type == 'Image' ? '[Ảnh]' : m.type == 'Location' ? '[Vị trí]' : '');
                          if (system) {
                            return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(text, textAlign: TextAlign.center, style: t.bodySmall));
                          }
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: mine ? CxColors.emerald700 : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(mine ? 18 : 4),
                                  bottomRight: Radius.circular(mine ? 4 : 18),
                                ),
                                border: mine ? null : Border.all(color: CxColors.stone200),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (m.warning != null && !mine)
                                  Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('⚠️ ${m.warning}', style: t.bodySmall?.copyWith(color: CxColors.wood800))),
                                Text(text, style: t.bodyLarge?.copyWith(color: mine ? Colors.white : CxColors.stone900)),
                                const SizedBox(height: 2),
                                Text(
                                  '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: t.bodySmall?.copyWith(fontSize: 11, color: mine ? CxColors.emerald100 : CxColors.stone500),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
        ),
        if (widget.conversation.blocked)
          const Padding(padding: EdgeInsets.all(12), child: Text('Cuộc trò chuyện đã bị chặn.', style: TextStyle(color: CxColors.stone500)))
        else
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: CxColors.stone200))),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(hintText: 'Nhắn tin…', isDense: true),
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Gửi',
                  style: IconButton.styleFrom(backgroundColor: CxColors.emerald700),
                  onPressed: _sending ? null : _send,
                  icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}
