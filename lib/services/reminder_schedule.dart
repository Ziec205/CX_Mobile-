import '../api/models.dart';

/// Tính các lần nhắc giống hệt BE (ReminderSchedule.cs): lặp theo lịch giờ Việt Nam (UTC+7),
/// tháng/năm tính từ mốc gốc nên 31/1 → 28/2 → 31/3 không bị trôi.
class ReminderSchedule {
  static const vnOffset = Duration(hours: 7);

  static int _daysInMonth(int y, int m) => DateTime.utc(y, m + 1, 0).day;

  static DateTime _addMonths(DateTime d, int months) {
    final total = d.year * 12 + (d.month - 1) + months;
    final y = total ~/ 12, m = total % 12 + 1;
    final day = d.day.clamp(1, _daysInMonth(y, m));
    return DateTime.utc(y, m, day, d.hour, d.minute, d.second, d.millisecond);
  }

  /// Lần thứ n (n ≥ 0) tính từ mốc, trả về UTC.
  static DateTime occurrence(DateTime anchorUtc, ReminderRepeat repeat, int interval, int n) {
    final local = anchorUtc.toUtc().add(vnOffset); // "giờ VN" biểu diễn bằng DateTime UTC
    final step = n * (interval < 1 ? 1 : interval);
    final next = switch (repeat) {
      ReminderRepeat.daily => local.add(Duration(days: step)),
      ReminderRepeat.weekly => local.add(Duration(days: 7 * step)),
      ReminderRepeat.monthly => _addMonths(local, step),
      ReminderRepeat.yearly => _addMonths(local, 12 * step),
      ReminderRepeat.none => local,
    };
    return next.subtract(vnOffset);
  }

  /// Các lần nhắc trong khoảng (from, until], tối đa [max] lần.
  static List<DateTime> upcoming(CareReminder r, DateTime from, DateTime until, {int max = 30}) {
    final result = <DateTime>[];
    if (!r.enabled) return result;
    final fromU = from.toUtc(), untilU = until.toUtc();
    if (r.repeat == ReminderRepeat.none) {
      final at = r.nextAt ?? r.anchorAt;
      if (at.isAfter(fromU) && !at.isAfter(untilU)) result.add(at);
      return result;
    }
    final days = switch (r.repeat) {
          ReminderRepeat.daily => 1.0,
          ReminderRepeat.weekly => 7.0,
          ReminderRepeat.monthly => 30.4,
          _ => 365.25,
        } *
        (r.interval < 1 ? 1 : r.interval);
    var n = fromU.isAfter(r.anchorAt) ? ((fromU.difference(r.anchorAt).inMinutes / 1440) / days).floor() - 1 : 0;
    if (n < 0) n = 0;
    while (!occurrence(r.anchorAt, r.repeat, r.interval, n).isAfter(fromU)) {
      n++;
    }
    while (result.length < max) {
      final at = occurrence(r.anchorAt, r.repeat, r.interval, n++);
      if (at.isAfter(untilU)) break;
      result.add(at);
    }
    return result;
  }

  /// Gộp lời nhắc của cả vườn, sắp theo thời gian, giới hạn tổng số (iOS chỉ giữ 64 thông báo chờ).
  static List<ScheduledCare> plan(List<MyPlant> plants, DateTime now, {Duration horizon = const Duration(days: 21), int maxTotal = 56}) {
    final all = <ScheduledCare>[];
    for (final p in plants) {
      if (p.locked) continue; // cây tạm khóa: nhắc lịch tạm dừng giống BE
      for (final r in p.reminders) {
        for (final at in upcoming(r, now, now.add(horizon))) {
          all.add(ScheduledCare(plant: p, reminder: r, at: at));
        }
      }
    }
    all.sort((a, b) => a.at.compareTo(b.at));
    return all.take(maxTotal).toList();
  }
}

/// Việc chăm cây trong ngày hôm nay (giờ máy), kèm trạng thái đã làm (đồng bộ app ↔ web qua lastDoneAt).
class TodayTask {
  TodayTask({required this.plant, required this.reminder, required this.at, required this.done});
  final MyPlant plant;
  final CareReminder reminder;
  final DateTime at; // UTC
  final bool done;
  bool get overdue => !done && at.isBefore(DateTime.now().toUtc());
}

List<TodayTask> todayTasks(List<MyPlant> plants, DateTime now) {
  final local = now.toLocal();
  final start = DateTime(local.year, local.month, local.day);
  final end = start.add(const Duration(days: 1));
  final out = <TodayTask>[];
  for (final p in plants) {
    if (p.locked) continue;
    for (final r in p.reminders) {
      // Lấy các lần trong ngày tính từ mốc (không dựa vào nextAt vì BE dời nextAt ngay khi đến giờ).
      for (final at in ReminderSchedule.upcoming(r, start.subtract(const Duration(milliseconds: 1)), end.subtract(const Duration(milliseconds: 1)), max: 4)) {
        final done = r.lastDoneAt != null && !r.lastDoneAt!.toLocal().isBefore(start);
        out.add(TodayTask(plant: p, reminder: r, at: at, done: done));
      }
    }
  }
  out.sort((a, b) => a.done == b.done ? a.at.compareTo(b.at) : (a.done ? 1 : -1));
  return out;
}

class ScheduledCare {
  ScheduledCare({required this.plant, required this.reminder, required this.at});
  final MyPlant plant;
  final CareReminder reminder;
  final DateTime at; // UTC
}
