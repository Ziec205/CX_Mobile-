import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/chat_screen.dart';
import '../state/app_state.dart';

/// Nút tin nhắn có số chưa đọc, đặt ở góc phải các tab chính.
class ChatAction extends StatelessWidget {
  const ChatAction({super.key});
  @override
  Widget build(BuildContext context) {
    final unread = context.select<AppState, int>((a) => a.unreadChats);
    return IconButton(
      tooltip: 'Tin nhắn',
      icon: Badge(isLabelVisible: unread > 0, label: Text(unread > 99 ? '99+' : '$unread'), child: const Icon(Icons.chat_bubble_outline_rounded)),
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen())),
    );
  }
}
