import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'chat_screen.dart';
import 'community_screen.dart';
import 'explore_screen.dart';
import 'garden_screen.dart';
import 'onboarding_screen.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  static final tab = ValueNotifier(0);
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const _pages = [TodayScreen(), GardenScreen(), ExploreScreen(), CommunityScreen(), ChatListScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Lần đầu vào app: giải thích vì sao cần thông báo rồi mới để hệ thống hỏi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!context.read<AppState>().notifPrimed) showNotificationPrimer(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quay lại app: đồng bộ vườn và đặt lại lịch nhắc (có thể đã sửa trên web).
    if (state == AppLifecycleState.resumed) {
      final app = context.read<AppState>();
      app.syncGarden();
      app.refreshUnread();
      app.realtime.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: HomeShell.tab,
      builder: (context, i, _) => Scaffold(
        body: IndexedStack(index: i, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => HomeShell.tab.value = v,
          destinations: [
            const NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny_rounded), label: 'Hôm nay'),
            const NavigationDestination(icon: Icon(Icons.yard_outlined), selectedIcon: Icon(Icons.yard_rounded), label: 'Vườn'),
            const NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore_rounded), label: 'Khám phá'),
            const NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum_rounded), label: 'Cộng đồng'),
            NavigationDestination(
              icon: Builder(builder: (context) {
                final unread = context.select<AppState, int>((a) => a.unreadChats);
                return Badge(isLabelVisible: unread > 0, label: Text(unread > 99 ? '99+' : '$unread'), child: const Icon(Icons.chat_bubble_outline_rounded));
              }),
              selectedIcon: const Icon(Icons.chat_bubble_rounded),
              label: 'Tin nhắn',
            ),
          ],
        ),
      ),
    );
  }
}
