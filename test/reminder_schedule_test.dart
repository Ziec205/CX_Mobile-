import 'package:cham_xanh/api/models.dart';
import 'package:cham_xanh/services/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

CareReminder r(DateTime anchorUtc, ReminderRepeat repeat, {int interval = 1, bool enabled = true, DateTime? nextAt}) => CareReminder(
      id: 'r1',
      plantId: 'p1',
      kind: ReminderKind.watering,
      anchorAt: anchorUtc,
      repeat: repeat,
      interval: interval,
      enabled: enabled,
      nextAt: nextAt,
    );

MyPlant plant(String id, List<CareReminder> rs, {bool locked = false}) =>
    MyPlant(id: id, name: 'Cây $id', reminders: rs, locked: locked, createdAt: DateTime(2026));

void main() {
  group('ReminderSchedule giống BE', () {
    test('tháng tính theo giờ VN từ mốc gốc: 31/1 → 28/2 → 31/3', () {
      // 07:00 ngày 31/1 giờ VN = 00:00 UTC
      final anchor = DateTime.utc(2027, 1, 31, 0, 0);
      final occ = [for (var n = 0; n < 3; n++) ReminderSchedule.occurrence(anchor, ReminderRepeat.monthly, 1, n)];
      expect(occ, [DateTime.utc(2027, 1, 31), DateTime.utc(2027, 2, 28), DateTime.utc(2027, 3, 31)]);
    });

    test('mốc 06:00 VN (23:00 UTC hôm trước) không bị lệch ngày khi lặp tháng', () {
      final anchor = DateTime.utc(2027, 1, 30, 23, 0); // 06:00 ngày 31/1 giờ VN
      expect(ReminderSchedule.occurrence(anchor, ReminderRepeat.monthly, 1, 1), DateTime.utc(2027, 2, 27, 23, 0)); // 06:00 ngày 28/2 VN
    });

    test('lặp mỗi 2 ngày, chỉ lấy các lần sau thời điểm hiện tại', () {
      final anchor = DateTime.utc(2027, 1, 1, 0);
      final list = ReminderSchedule.upcoming(r(anchor, ReminderRepeat.daily, interval: 2), DateTime.utc(2027, 1, 4, 12), DateTime.utc(2027, 1, 12));
      expect(list, [DateTime.utc(2027, 1, 5), DateTime.utc(2027, 1, 7), DateTime.utc(2027, 1, 9), DateTime.utc(2027, 1, 11)]);
    });

    test('nhắc một lần đã qua hoặc đang tắt thì không đặt', () {
      final past = r(DateTime.utc(2020, 1, 1), ReminderRepeat.none);
      expect(ReminderSchedule.upcoming(past, DateTime.utc(2027), DateTime.utc(2028)), isEmpty);
      final off = r(DateTime.utc(2027, 6, 1), ReminderRepeat.daily, enabled: false);
      expect(ReminderSchedule.upcoming(off, DateTime.utc(2027), DateTime.utc(2028)), isEmpty);
    });

    test('nhắc một lần trong tương lai', () {
      final once = r(DateTime.utc(2027, 3, 1, 1), ReminderRepeat.none);
      expect(ReminderSchedule.upcoming(once, DateTime.utc(2027, 2, 1), DateTime.utc(2027, 3, 2)), [DateTime.utc(2027, 3, 1, 1)]);
    });

    test('mốc lâu năm vẫn tính nhanh và đúng', () {
      final anchor = DateTime.utc(2015, 5, 5, 0);
      final list = ReminderSchedule.upcoming(r(anchor, ReminderRepeat.weekly), DateTime.utc(2027, 1, 1), DateTime.utc(2027, 1, 20));
      expect(list.length, 3);
      expect(list.every((d) => d.weekday == DateTime.utc(2015, 5, 5).weekday), isTrue);
    });

    test('plan gộp cả vườn, bỏ cây tạm khóa, sắp theo giờ và giới hạn tổng', () {
      final now = DateTime.utc(2027, 1, 1);
      final plants = [
        plant('a', [r(DateTime.utc(2027, 1, 1, 2), ReminderRepeat.daily)]),
        plant('b', [r(DateTime.utc(2027, 1, 1, 1), ReminderRepeat.daily)]),
        plant('c', [r(DateTime.utc(2027, 1, 1, 0, 30), ReminderRepeat.daily)], locked: true),
      ];
      final items = ReminderSchedule.plan(plants, now, horizon: const Duration(days: 30), maxTotal: 10);
      expect(items.length, 10);
      expect(items.first.plant.id, 'b');
      expect(items.any((s) => s.plant.id == 'c'), isFalse);
      for (var i = 1; i < items.length; i++) {
        expect(items[i].at.isBefore(items[i - 1].at), isFalse);
      }
    });
  });

  group('Việc hôm nay', () {
    test('lặp hằng ngày vẫn là việc hôm nay dù BE đã dời nextAt sang mai', () {
      final now = DateTime.now();
      final todayMorning = DateTime(now.year, now.month, now.day, 0, 5).toUtc();
      final r = CareReminder(
          id: 'r1', plantId: 'p1', kind: ReminderKind.watering, anchorAt: todayMorning.subtract(const Duration(days: 3)),
          repeat: ReminderRepeat.daily, interval: 1, enabled: true, nextAt: todayMorning.add(const Duration(days: 1)));
      final tasks = todayTasks([plant('p1', [r])], now);
      expect(tasks.length, 1);
      expect(tasks.single.done, isFalse);
    });

    test('đã bấm "Đã làm" hôm nay (app hoặc web) thì là xong; việc chưa xong lên trước', () {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).toUtc();
      CareReminder mk(String id, Duration at, {DateTime? done}) => CareReminder(
          id: id, plantId: 'p', kind: ReminderKind.watering, anchorAt: start.add(at), repeat: ReminderRepeat.daily,
          interval: 1, enabled: true, lastDoneAt: done);
      final tasks = todayTasks([
        plant('p', [mk('a', const Duration(minutes: 10), done: DateTime.now().toUtc()), mk('b', const Duration(hours: 23, minutes: 50))]),
      ], now);
      expect(tasks.map((x) => (x.reminder.id, x.done)), [('b', false), ('a', true)]);
    });

    test('cây tạm khóa và lời nhắc đã tắt không có việc', () {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, 12).toUtc();
      final on = CareReminder(id: 'x', plantId: 'p', kind: ReminderKind.watering, anchorAt: start, repeat: ReminderRepeat.daily, interval: 1, enabled: true);
      final off = CareReminder(id: 'y', plantId: 'q', kind: ReminderKind.watering, anchorAt: start, repeat: ReminderRepeat.daily, interval: 1, enabled: false);
      expect(todayTasks([plant('p', [on], locked: true), plant('q', [off])], now), isEmpty);
    });
  });
}
