import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'account_screen.dart';
import 'community_screen.dart';
import 'explore_screen.dart';
import 'garden_screen.dart';
import 'reminders_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  static final tab = ValueNotifier(0);
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const _pages = [GardenScreen(), RemindersScreen(), CommunityScreen(), ExploreScreen(), AccountScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Lần đầu vào app: xin quyền thông báo để nhắc tưới kêu được.
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().notifications.requestPermissions(exact: false));
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
          destinations: const [
            NavigationDestination(icon: Icon(Icons.yard_outlined), selectedIcon: Icon(Icons.yard_rounded), label: 'Vườn'),
            NavigationDestination(icon: Icon(Icons.water_drop_outlined), selectedIcon: Icon(Icons.water_drop_rounded), label: 'Nhắc tưới'),
            NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum_rounded), label: 'Cộng đồng'),
            NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore_rounded), label: 'Khám phá'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Tài khoản'),
          ],
        ),
      ),
    );
  }
}
