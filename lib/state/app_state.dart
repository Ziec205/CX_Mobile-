import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../services/notifications.dart';
import '../services/photo_store.dart';
import '../services/push.dart';
import '../services/realtime.dart';
import '../services/reminder_schedule.dart';

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
  /// Gói đang dùng (GET me/plan). null: chưa tải được, avatar hiện như thường.
  MyPlan? plan;
  List<MyPlant>? plants;
  String? gardenError;
  DateTime? lastSync;
  bool remindersOnPhone = true;
  int unreadChats = 0;
  /// Đã xem màn hình giới thiệu lần đầu.
  bool onboarded = true;
  /// Đã giải thích vì sao cần quyền thông báo (trước khi hệ thống hỏi).
  bool notifPrimed = true;
  /// Số ngày liên tiếp có chăm cây (bấm "Đã làm"), tính trên máy.
  int streak = 0;
  StreamSubscription<ChatMessage>? _msgSub;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    remindersOnPhone = prefs.getBool('care.onPhone') ?? true;
    onboarded = prefs.getBool('ui.onboarded') ?? false;
    notifPrimed = prefs.getBool('ui.notifPrimed') ?? false;
    streak = _streakFrom(prefs.getStringList('care.doneDays') ?? const []);
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

  /// Tăng mỗi khi ảnh cây trên máy đổi, để ảnh đại diện cây tải lại.
  int photoVersion = 0;
  void photosChanged() {
    photoVersion++;
    notifyListeners();
  }

  Future<void> _signedIn() async {
    status = SessionStatus.signedIn;
    notifyListeners();
    unawaited(syncGarden());
    unawaited(refreshUnread());
    unawaited(refreshPlan());
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

  Future<void> refreshPlan() async {
    try {
      final res = MyPlan.fromJson(await api.get('me/plan') as Map<String, dynamic>);
      if (status != SessionStatus.signedIn) return; // đã đăng xuất trong lúc chờ
      plan = res;
      notifyListeners();
    } catch (_) {
      // Giữ gói đã biết; chưa biết thì avatar hiện như thường.
    }
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
    await _signedOut();
  }

  Future<void> _signedOut() async {
    await api.setTokens(null);
    await notifications.sync(const [], enabled: false);
    await _msgSub?.cancel();
    _msgSub = null;
    await realtime.stop();
    me = null;
    plan = null;
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

  List<TodayTask> get today => todayTasks(plants ?? const [], DateTime.now());

  Future<void> completeOnboarding() async {
    onboarded = true;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('ui.onboarded', true);
  }

  Future<void> markNotifPrimed() async {
    notifPrimed = true;
    (await SharedPreferences.getInstance()).setBool('ui.notifPrimed', true);
  }

  void _replaceReminder(String plantId, CareReminder r) {
    plants = [
      for (final p in plants ?? const <MyPlant>[])
        p.id == plantId ? p.withReminders([for (final x in p.reminders) x.id == r.id ? r : x]) : p,
    ];
    notifyListeners();
  }

  /// Bấm "Đã tưới/Đã làm": lưu lên BE (web thấy ngay), cập nhật chuỗi ngày chăm cây.
  Future<void> markDone(MyPlant p, CareReminder r) async {
    final res = await api.post('me/garden/plants/${p.id}/reminders/${r.id}/done') as Map<String, dynamic>;
    _replaceReminder(p.id, CareReminder.fromJson(res));
    await CareNotifications.markDone(r.id);
    final prefs = await SharedPreferences.getInstance();
    final days = {...prefs.getStringList('care.doneDays') ?? const <String>[], _day(DateTime.now())}.toList()..sort();
    await prefs.setStringList('care.doneDays', days.length > 400 ? days.sublist(days.length - 400) : days);
    streak = _streakFrom(days);
    notifyListeners();
  }

  /// Hoàn tác khi bấm nhầm.
  Future<void> undoDone(MyPlant p, CareReminder r) async {
    final res = await api.delete('me/garden/plants/${p.id}/reminders/${r.id}/done') as Map<String, dynamic>;
    _replaceReminder(p.id, CareReminder.fromJson(res));
  }

  static String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static int _streakFrom(List<String> days) {
    final set = days.toSet();
    var d = DateTime.now();
    if (!set.contains(_day(d))) d = d.subtract(const Duration(days: 1)); // hôm nay chưa làm vẫn giữ chuỗi
    var n = 0;
    while (set.contains(_day(d))) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
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
