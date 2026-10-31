import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../api/models.dart';
import '../theme.dart';
import 'reminder_schedule.dart';

const _actionDone = 'done';
const _actionSnooze = 'snooze';
const _category = 'care_alarm';
const _prefsIds = 'care.scheduledIds';
const _snoozeBase = 900000;

/// Nút trên thông báo được bấm khi app đang tắt: chạy trong isolate riêng.
@pragma('vm:entry-point')
void onBackgroundNotificationAction(NotificationResponse r) async {
  DartPluginRegistrant.ensureInitialized();
  await CareNotifications.instance.init(background: true);
  await CareNotifications.instance.handleAction(r);
}

/// Nhắc tưới kiểu báo thức: thông báo ưu tiên cao, chuông kêu lặp tới khi người dùng phản hồi,
/// hai nút "Đã tưới" và "Nhắc lại 10 phút". Lịch được dựng lại từ careReminders của BE mỗi lần đồng bộ.
class CareNotifications {
  CareNotifications._();
  static final instance = CareNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _exact = false;

  /// Bấm vào thông báo (không phải nút): mở màn hình Nhắc tưới.
  final tapped = ValueNotifier<String?>(null);

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init({bool background = false}) async {
    if (_ready || kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    }
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(_category, actions: [
          DarwinNotificationAction.plain(_actionDone, 'Đã tưới'),
          DarwinNotificationAction.plain(_actionSnooze, 'Nhắc lại 10 phút'),
        ]),
      ],
    );
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('ic_stat_cham_xanh'), // lá trắng đơn sắc cho thanh trạng thái
        iOS: darwin,
        linux: const LinuxInitializationSettings(defaultActionName: 'Mở'),
      ),
      onDidReceiveNotificationResponse: background ? null : handleAction,
      onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationAction,
    );
    _exact = await _android?.canScheduleExactNotifications() ?? true;
    _ready = true;
  }

  /// Xin quyền thông báo (Android 13+, iOS). [exact]: xin thêm quyền "Báo thức & lời nhắc" (Android 12+),
  /// mở trang cài đặt nên chỉ gọi khi người dùng đang đặt nhắc/thử chuông.
  Future<bool> requestPermissions({bool exact = true}) async {
    await init();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        await _android?.requestNotificationsPermission() ??
        true;
    if (exact && _android != null && !_exact) {
      await _android!.requestExactAlarmsPermission();
      _exact = await _android!.canScheduleExactNotifications() ?? false;
    }
    return granted;
  }

  NotificationDetails _details() => NotificationDetails(
        android: AndroidNotificationDetails(
          'care_alarm_v1',
          'Nhắc tưới cây',
          icon: 'ic_stat_cham_xanh',
          channelDescription: 'Báo thức nhắc tưới, bón phân cho cây trong vườn',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          fullScreenIntent: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]),
          additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT: chuông lặp tới khi phản hồi
          visibility: NotificationVisibility.public,
          color: CxColors.water500,
          ticker: 'Đến giờ chăm cây',
          actions: const [
            AndroidNotificationAction(_actionDone, 'Đã tưới', cancelNotification: true),
            AndroidNotificationAction(_actionSnooze, 'Nhắc lại 10 phút', cancelNotification: true),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: _category,
          presentAlert: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

  /// Chỉ Android/iOS hẹn giờ được; desktop (dùng khi chạy thử) bỏ qua.
  bool get _canSchedule => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  AndroidScheduleMode get _mode => _exact ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.inexactAllowWhileIdle;

  static String titleFor(CareReminder r, MyPlant p) => switch (r.kind) {
        ReminderKind.watering => '💧 Đến giờ tưới ${p.name}',
        ReminderKind.fertilizing => '🌱 Đến giờ bón phân cho ${p.name}',
        ReminderKind.pruning => '✂️ Đến giờ cắt tỉa ${p.name}',
        ReminderKind.repotting => '🪴 Đến lúc thay chậu cho ${p.name}',
        ReminderKind.other => '🌿 Nhắc chăm ${p.name}',
      };

  /// Hủy lịch cũ, đặt lại toàn bộ theo dữ liệu mới nhất của BE.
  Future<int> sync(List<MyPlant> plants, {bool enabled = true}) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    for (final id in prefs.getStringList(_prefsIds) ?? const <String>[]) {
      await _plugin.cancel(id: int.parse(id));
    }
    if (!enabled) {
      await prefs.setStringList(_prefsIds, []);
      return 0;
    }
    final items = ReminderSchedule.plan(plants, DateTime.now());
    final ids = <String>[];
    for (var i = 0; i < items.length; i++) {
      final s = items[i];
      final id = 1000 + i;
      final payload = jsonEncode({
        'plantId': s.plant.id,
        'reminderId': s.reminder.id,
        'title': titleFor(s.reminder, s.plant),
        'body': _body(s),
      });
      if (!_canSchedule) continue;
      await _plugin.zonedSchedule(
        id: id,
        title: titleFor(s.reminder, s.plant),
        body: _body(s),
        scheduledDate: tz.TZDateTime.from(s.at, tz.local),
        notificationDetails: _details(),
        androidScheduleMode: _mode,
        payload: payload,
      );
      ids.add('$id');
    }
    await prefs.setStringList(_prefsIds, ids);
    return items.length;
  }

  static String _body(ScheduledCare s) {
    final parts = <String>[reminderKindLabel[s.reminder.kind]!];
    if (s.plant.location?.isNotEmpty == true) parts.add(s.plant.location!);
    if (s.reminder.note?.isNotEmpty == true) parts.add(s.reminder.note!);
    return parts.join(' · ');
  }

  Future<void> handleAction(NotificationResponse r) async {
    final data = r.payload == null ? null : jsonDecode(r.payload!) as Map<String, dynamic>;
    switch (r.actionId) {
      case _actionSnooze:
        await snooze(data);
      case _actionDone:
        if (data?['reminderId'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('care.done.${data!['reminderId']}', DateTime.now().toIso8601String());
        }
      default:
        tapped.value = data?['plantId'] as String?;
    }
  }

  Future<void> snooze(Map<String, dynamic>? data, {Duration after = const Duration(minutes: 10)}) async {
    await init();
    if (!_canSchedule) return;
    final id = _snoozeBase + DateTime.now().millisecondsSinceEpoch % 90000;
    await _plugin.zonedSchedule(
      id: id,
      title: (data?['title'] as String?) ?? 'Nhắc chăm cây',
      body: 'Nhắc lại · ${(data?['body'] as String?) ?? ''}',
      scheduledDate: tz.TZDateTime.now(tz.local).add(after),
      notificationDetails: _details(),
      androidScheduleMode: _mode,
      payload: data == null ? null : jsonEncode(data),
    );
  }

  /// Lần cuối người dùng bấm "Đã tưới" cho một lời nhắc (lưu trên máy).
  static Future<DateTime?> lastDone(String reminderId) async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString('care.done.$reminderId');
    return v == null ? null : DateTime.tryParse(v);
  }

  static Future<void> markDone(String reminderId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('care.done.$reminderId', DateTime.now().toIso8601String());
  }

  /// Thử chuông ngay để người dùng nghe kiểu báo thức.
  Future<void> test() async {
    await init();
    await _plugin.show(
      id: 999,
      title: '💧 Thử nhắc tưới',
      body: 'Nhắc tưới sẽ kêu như thế này. Bấm "Đã tưới" để tắt.',
      notificationDetails: _details(),
      payload: jsonEncode({'title': '💧 Thử nhắc tưới', 'body': 'Nhắc lại'}),
    );
  }

  Future<int> pendingCount() async {
    await init();
    if (!_canSchedule) return 0;
    return (await _plugin.pendingNotificationRequests()).length;
  }
}

/// Mở app từ thông báo khi app đã tắt hẳn.
Future<String?> launchPlantId() async {
  final d = await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
  if (d?.didNotificationLaunchApp != true) return null;
  final p = d!.notificationResponse?.payload;
  if (p == null) return null;
  return (jsonDecode(p) as Map<String, dynamic>)['plantId'] as String?;
}

