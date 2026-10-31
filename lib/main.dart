import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/plant_detail_screen.dart';
import 'services/notifications.dart';
import 'state/app_state.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');
  await CareNotifications.instance.init();
  final launchPlant = await launchPlantId();
  final app = AppState();
  runApp(ChangeNotifierProvider.value(value: app, child: ChamXanhApp(openPlant: launchPlant)));
  await app.bootstrap();
}

class ChamXanhApp extends StatefulWidget {
  const ChamXanhApp({super.key, this.openPlant});
  final String? openPlant;
  @override
  State<ChamXanhApp> createState() => _ChamXanhAppState();
}

class _ChamXanhAppState extends State<ChamXanhApp> {
  String? _pendingPlant;

  @override
  void initState() {
    super.initState();
    _pendingPlant = widget.openPlant;
    CareNotifications.instance.tapped.addListener(_onTap);
  }

  @override
  void dispose() {
    CareNotifications.instance.tapped.removeListener(_onTap);
    super.dispose();
  }

  void _onTap() {
    final id = CareNotifications.instance.tapped.value;
    if (id == null) return;
    CareNotifications.instance.tapped.value = null;
    _openPlant(id);
  }

  void _openPlant(String id) {
    HomeShell.tab.value = 1;
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: id)));
  }

  @override
  Widget build(BuildContext context) {
    final status = context.select<AppState, SessionStatus>((a) => a.status);
    if (status == SessionStatus.signedIn && _pendingPlant != null) {
      final id = _pendingPlant!;
      _pendingPlant = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPlant(id));
    }
    return MaterialApp(
      title: 'Chạm Xanh',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: switch (status) {
        SessionStatus.loading => const _Splash(),
        SessionStatus.signedOut => const LoginScreen(),
        SessionStatus.signedIn => const HomeShell(),
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: CxColors.emerald800,
        body: Center(child: Icon(Icons.eco_rounded, size: 72, color: CxColors.wood400)),
      );
}
