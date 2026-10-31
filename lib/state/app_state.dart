import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../services/notifications.dart';
import '../services/photo_store.dart';
import '../services/push.dart';
import '../services/realtime.dart';

enum SessionStatus { loading, signedOut, signedIn }

/// Trạng thái chung: phiên đăng nhập, vườn (đồng bộ với BE), kết nối chat.
class AppState extends ChangeNotifier {
  AppState({ApiClient? api, CareNotifications? notifications, PhotoStore? photos})
      : api = api ?? ApiClient(),
        notifications = notifications ?? CareNotifications.instance,
        photos = photos ?? PhotoStore() {
    realtime = Realtime(this.api);
    push = PushService(this.api);
    this.api.onSessionExpired = () {
      _signedOut();
    };
  }

  final ApiClient api;
  final CareNotifications notifications;
  final PhotoStore photos;
  late final Realtime realtime;
  late final PushService push;

  SessionStatus status = SessionStatus.loading;
  Me? me;
  List<MyPlant>? plants;
  String? gardenError;
  DateTime? lastSync;
  bool remindersOnPhone = true;
  int unreadChats = 0;
  StreamSubscription<ChatMessage>? _msgSub;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    remindersOnPhone = prefs.getBool('care.onPhone') ?? true;
    await api.load();
    if (!api.hasSession) return _signedOut();
    try {
      me = Me.fromJson(await api.get('me') as Map<String, dynamic>);
      await _signedIn();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return _signedOut();
      // Lỗi máy chủ: vẫn vào app, các màn hình tự tải lại khi có mạng.
      await _signedIn();
    } catch (_) {
      await _signedIn(); // mất mạng: dùng phiên đã lưu
    }
  }

  Future<void> login(String username, String password) async {
    final res = await api.post('auth/login', {'username': username.trim(), 'password': password}) as Map<String, dynamic>;
    await _accept(res);
  }

  Future<void> register(String username, String password, String confirm) async {
    final res = await api.post('auth/register', {'username': username.trim(), 'password': password, 'confirmPassword': confirm}) as Map<String, dynamic>;
    await _accept(res);
  }

  Future<void> _accept(Map<String, dynamic> res) async {
    await api.setTokens(TokenPair.fromJson(res['tokens'] as Map<String, dynamic>));
    me = Me.fromJson(res['user'] as Map<String, dynamic>);
    await _signedIn();
  }

  Future<void> _signedIn() async {
    status = SessionStatus.signedIn;
    notifyListeners();
    unawaited(syncGarden());
    unawaited(refreshUnread());
    unawaited(_startRealtime());
    unawaited(push.register().catchError((_) {}));
  }

  Future<void> _startRealtime() async {
    await realtime.start();
    _msgSub ??= realtime.messages.listen((m) {
      if (m.senderId != me?.id) {
        unreadChats++;
        notifyListeners();
      }
    });
  }

  Future<void> refreshMe() async {
    me = Me.fromJson(await api.get('me') as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> logout() async {
    final t = await api.store.read();
    await push.unregister();
    if (t != null) {
      try {
        await api.post('auth/logout', {'refreshToken': t.refreshToken});
      } catch (_) {}
    }
    await notifications.sync(const [], enabled: false);
    await _signedOut();
  }

  Future<void> _signedOut() async {
    await api.setTokens(null);
    await _msgSub?.cancel();
    _msgSub = null;
    await realtime.stop();
    me = null;
    plants = null;
    unreadChats = 0;
    status = SessionStatus.signedOut;
    notifyListeners();
  }

  /// Tải vườn từ BE và đặt lại toàn bộ lịch nhắc trên máy. Gọi khi mở app, quay lại app, sau mỗi thay đổi.
  Future<void> syncGarden() async {
    if (me == null) {
      try {
        me = Me.fromJson(await api.get('me') as Map<String, dynamic>);
      } catch (_) {}
    }
    try {
      final list = (await api.get('me/garden/plants') as List).cast<Map<String, dynamic>>().map(MyPlant.fromJson).toList();
      plants = list;
      gardenError = null;
      lastSync = DateTime.now();
      notifyListeners();
      await notifications.sync(list, enabled: remindersOnPhone);
    } catch (e) {
      gardenError = ApiException.describe(e);
      notifyListeners();
    }
  }

  Future<void> setRemindersOnPhone(bool on) async {
    remindersOnPhone = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('care.onPhone', on);
    notifyListeners();
    if (on) await notifications.requestPermissions();
    await notifications.sync(plants ?? const [], enabled: on);
  }

  Future<void> refreshUnread() async {
    try {
      final list = (await api.get('conversations') as List).cast<Map<String, dynamic>>();
      unreadChats = list.fold(0, (s, c) => s + ((c['unread'] as num?)?.toInt() ?? 0));
      notifyListeners();
    } catch (_) {}
  }

  void clearUnread(int n) {
    unreadChats = (unreadChats - n).clamp(0, 1 << 30);
    notifyListeners();
  }
}
