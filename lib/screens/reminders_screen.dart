import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../services/reminder_schedule.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/care_actions.dart';
import '../widgets/common.dart';
import 'plant_detail_screen.dart';

/// Lịch nhắc 7 ngày tới của cả vườn + cài đặt báo thức trên máy.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final plants = app.plants ?? const <MyPlant>[];
    final items = ReminderSchedule.plan(plants, DateTime.now(), horizon: const Duration(days: 7), maxTotal: 100);
    final t = Theme.of(context).textTheme;

    final groups = <String, List<ScheduledCare>>{};
    for (final s in items) {
      final d = s.at.toLocal();
      final now = DateTime.now();
      final days = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
      final key = days == 0 ? 'Hôm nay' : days == 1 ? 'Ngày mai' : vnDate(d);
      groups.putIfAbsent(key, () => []).add(s);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch nhắc 7 ngày')),
      body: RefreshIndicator(
        color: CxColors.water500,
        onRefresh: app.syncGarden,
        child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
          const _AlarmSettings(),
          if (app.plants == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (items.isEmpty)
            const EmptyState(
              icon: Icons.water_drop_outlined,
              color: CxColors.water500,
              title: 'Không có lịch trong 7 ngày tới',
              message: 'Vào Hồ sơ vườn, chọn một cây rồi bấm "Đặt nhắc".',
            )
          else
            for (final e in groups.entries) ...[
              SectionTitle(e.key),
              for (final s in e.value)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: s.plant.id))),
                      leading: Container(
                        width: 56,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: CxColors.water50, borderRadius: BorderRadius.circular(14)),
                        child: Text(
                          '${s.at.toLocal().hour.toString().padLeft(2, '0')}:${s.at.toLocal().minute.toString().padLeft(2, '0')}',
                          textAlign: TextAlign.center,
                          style: t.titleMedium?.copyWith(color: CxColors.water700),
                        ),
                      ),
                      title: Text(s.plant.name, style: t.titleMedium),
                      subtitle: Text([reminderKindLabel[s.reminder.kind]!, if (s.reminder.note?.isNotEmpty == true) s.reminder.note!].join(' · ')),
                      trailing: IconButton(
                        tooltip: 'Đánh dấu đã làm',
                        icon: const Icon(Icons.check_circle_outline_rounded, color: CxColors.water500),
                        onPressed: () => completeCare(context, s.plant, s.reminder),
                      ),
                    ),
                  ),
                ),
            ],
        ]),
      ),
    );
  }
}

class _AlarmSettings extends StatefulWidget {
  const _AlarmSettings();
  @override
  State<_AlarmSettings> createState() => _AlarmSettingsState();
}

class _AlarmSettingsState extends State<_AlarmSettings> {
  int? _pending;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final n = await context.read<AppState>().notifications.pendingCount();
      if (mounted) setState(() => _pending = n);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [CxColors.water500, CxColors.water700], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.alarm_on_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text('Báo thức trên điện thoại', style: t.titleMedium?.copyWith(color: Colors.white))),
          Switch(
            value: app.remindersOnPhone,
            activeThumbColor: CxColors.wood400,
            onChanged: (v) async {
              await app.setRemindersOnPhone(v);
              _refresh();
            },
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          app.remindersOnPhone
              ? 'Chuông kêu tới khi bạn bấm "Đã tưới" hoặc "Nhắc lại 10 phút". Lịch đồng bộ với web mỗi khi mở app.'
              : 'Đang tắt: chỉ nhận nhắc qua email/web.',
          style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), minimumSize: const Size(40, 40)),
            onPressed: () async {
              await app.notifications.requestPermissions();
              await app.notifications.test();
            },
            icon: const Icon(Icons.volume_up_rounded, size: 18),
            label: const Text('Thử chuông'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), minimumSize: const Size(40, 40)),
            onPressed: () async {
              await app.notifications.requestPermissions();
              await app.syncGarden();
              await _refresh();
              if (context.mounted) showInfo(context, 'Đã đồng bộ lịch nhắc với máy chủ');
            },
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text('Đồng bộ'),
          ),
          if (_pending != null) Text('$_pending lần nhắc đã hẹn', style: t.bodySmall?.copyWith(color: Colors.white70)),
        ]),
      ]),
    );
  }
}
