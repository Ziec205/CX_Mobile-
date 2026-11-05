import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../services/reminder_schedule.dart';
import '../state/app_state.dart';
import 'account_screen.dart';
import '../theme.dart';
import '../widgets/care_actions.dart';
import '../widgets/common.dart';
import '../widgets/plant_avatar.dart';
import 'community_screen.dart';
import 'explore_screen.dart';
import 'plant_detail_screen.dart';
import 'plant_form_screen.dart';
import 'reminders_screen.dart';

/// Trang chủ "Hôm nay": trả lời ngay câu hỏi "hôm nay tôi cần làm gì cho vườn?".
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final now = DateTime.now();
    final tasks = app.today;
    final t = Theme.of(context).textTheme;
    final name = app.me?.displayName ?? '';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: app.syncGarden,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 12, 8, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [CxColors.emerald700, CxColors.emerald900], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_dateLabel(now), style: t.bodyMedium?.copyWith(color: CxColors.emerald100)),
                    const SizedBox(height: 4),
                    Text('${greetingFor(now)}${name.isEmpty ? '' : ',\n$name'} ${greetingEmoji(now)}',
                        style: t.headlineMedium?.copyWith(color: Colors.white, height: 1.15)),
                  ]),
                ),
                const AccountAction(),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: _ProgressCard(tasks: tasks, streak: app.streak, hasPlants: (app.plants ?? const []).isNotEmpty),
            ),
          ),
          if (app.plants == null)
            const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())))
          else ...[
            if (app.plants!.isEmpty)
              SliverToBoxAdapter(child: _FirstPlantCard())
            else if (tasks.isEmpty)
              const SliverToBoxAdapter(child: _RestDayCard())
            else ...[
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('Việc hôm nay', style: t.titleLarge))),
              SliverList.separated(
                itemCount: tasks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TaskCard(task: tasks[i])),
              ),
            ],
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 10), child: Text('Lối tắt', style: t.titleLarge))),
            const SliverToBoxAdapter(child: _Shortcuts()),
            const SliverToBoxAdapter(child: _TipOfDay()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ]),
      ),
    );
  }

  static String _dateLabel(DateTime d) {
    final s = DateFormat("EEEE, d 'tháng' M", 'vi').format(d);
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.tasks, required this.streak, required this.hasPlants});
  final List<TodayTask> tasks;
  final int streak;
  final bool hasPlants;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final done = tasks.where((x) => x.done).length;
    final total = tasks.length;
    final allDone = total > 0 && done == total;
    final title = !hasPlants
        ? 'Vườn đang chờ cây đầu tiên'
        : total == 0
            ? 'Hôm nay không có việc nào'
            : allDone
                ? 'Đã chăm xong cả vườn!'
                : 'Còn ${total - done} việc cho vườn';
    final sub = !hasPlants
        ? 'Thêm một cây để Chạm Xanh nhắc bạn đúng giờ.'
        : total == 0
            ? 'Vườn được nghỉ ngơi. Bạn cũng thư giãn nhé 😌'
            : allDone
                ? 'Tuyệt vời, cây nào cũng được chăm chu đáo 🌿'
                : 'Bấm “Đã tưới” khi bạn làm xong từng việc.';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: softShadow),
      child: Row(children: [
        SizedBox(
          width: 68,
          height: 68,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: total == 0 ? (hasPlants ? 1 : 0) : done / total,
                strokeWidth: 7,
                strokeCap: StrokeCap.round,
                backgroundColor: CxColors.water50,
                color: allDone || (hasPlants && total == 0) ? CxColors.emerald500 : CxColors.water500,
              ),
            ),
            Text(total == 0 ? (hasPlants ? '✓' : '0') : '$done/$total', style: t.titleMedium),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleMedium),
            const SizedBox(height: 2),
            Text(sub, style: t.bodyMedium),
            if (streak >= 1) ...[
              const SizedBox(height: 8),
              Pill('🔥 $streak ngày chăm cây liên tiếp', bg: CxColors.wood100, fg: CxColors.wood800),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Một việc trong ngày, nút lớn "Đã tưới" bấm một chạm.
class TaskCard extends StatefulWidget {
  const TaskCard({super.key, required this.task});
  final TodayTask task;
  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final x = widget.task;
    final t = Theme.of(context).textTheme;
    final local = x.at.toLocal();
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final water = x.reminder.kind == ReminderKind.watering;
    final doneLabel = water ? 'Đã tưới' : 'Đã làm';
    return Material(
      color: x.done ? CxColors.emerald50 : Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: x.plant.id))),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: x.done ? CxColors.emerald200 : x.overdue ? CxColors.water100 : CxColors.stone100, width: x.overdue ? 2 : 1),
          ),
          child: Row(children: [
            Opacity(opacity: x.done ? 0.7 : 1, child: PlantAvatar(plant: x.plant, size: 60)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(x.plant.name, style: t.titleMedium?.copyWith(decoration: x.done ? TextDecoration.lineThrough : null), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${water ? '💧' : '🌱'} ${reminderKindLabel[x.reminder.kind]} · $time', style: t.bodyMedium),
                if (x.overdue) Text('Đến giờ rồi bạn ơi', style: t.bodySmall?.copyWith(color: CxColors.water700, fontWeight: FontWeight.w700)),
                if (x.reminder.note?.isNotEmpty == true && !x.overdue) Text(x.reminder.note!, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(width: 8),
            x.done
                ? const Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_rounded, color: CxColors.emerald600, size: 32),
                    Text('Xong', style: TextStyle(color: CxColors.emerald700, fontWeight: FontWeight.w700, fontSize: 13)),
                  ])
                : FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: CxColors.water500,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(96, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            await completeCare(context, x.plant, x.reminder);
                            if (mounted) setState(() => _busy = false);
                          },
                    child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: CxColors.stone900)) : Text(doneLabel),
                  ),
          ]),
        ),
      ),
    );
  }
}

class _FirstPlantCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: CxColors.emerald50, borderRadius: BorderRadius.circular(24), border: Border.all(color: CxColors.emerald100)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🪴', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text('Bắt đầu với cây đầu tiên', style: t.titleLarge),
          const SizedBox(height: 6),
          Text('Chỉ cần đặt tên cho cây. Ảnh chụp được giữ ngay trên điện thoại của bạn, Chạm Xanh sẽ nhắc tưới đúng giờ.', style: t.bodyMedium),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlantFormScreen())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm cây đầu tiên'),
          ),
        ]),
      ),
    );
  }
}

class _RestDayCard extends StatelessWidget {
  const _RestDayCard();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: CxColors.stone100)),
        child: Row(children: [
          const Text('😌', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 14),
          Expanded(child: Text('Hôm nay không có lịch tưới. Muốn được nhắc, hãy mở một cây và bấm “Đặt nhắc”.', style: t.bodyMedium)),
        ]),
      ),
    );
  }
}

class _Shortcuts extends StatelessWidget {
  const _Shortcuts();
  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, Color bg, Color fg, Widget Function() page) => Expanded(
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page())),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Column(children: [
                  Icon(icon, color: fg, size: 30),
                  const SizedBox(height: 8),
                  Text(label, textAlign: TextAlign.center, style: TextStyle(fontFamily: fontDisplay, fontWeight: FontWeight.w800, color: fg, fontSize: 14.5, height: 1.2)),
                ]),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        item(Icons.add_circle_outline_rounded, 'Thêm cây', CxColors.emerald50, CxColors.emerald800, () => const PlantFormScreen()),
        const SizedBox(width: 10),
        item(Icons.calendar_month_rounded, 'Lịch nhắc\n7 ngày', CxColors.water50, CxColors.water700, () => const RemindersScreen()),
        const SizedBox(width: 10),
        item(Icons.help_outline_rounded, 'Hỏi\ncộng đồng', CxColors.wood100, CxColors.wood800, () => const NewPostScreen()),
      ]),
    );
  }
}

class _TipOfDay extends StatefulWidget {
  const _TipOfDay();
  @override
  State<_TipOfDay> createState() => _TipOfDayState();
}

class _TipOfDayState extends State<_TipOfDay> {
  late final Future<dynamic> _future = context.read<AppState>().api.get('explore/today').catchError((_) => null);

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final t = Theme.of(context).textTheme;
    return FutureBuilder<dynamic>(
      future: _future,
      builder: (context, snap) {
        if (snap.data is! Map<String, dynamic>) return const SizedBox.shrink();
        final a = Article.fromJson(snap.data as Map<String, dynamic>);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ArticleScreen(slug: a.slug, title: a.title))),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  PlantImage(url: a.cover?.thumb == null ? null : api.mediaUrl(a.cover!.thumb!), size: 76),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Pill('💡 Mẹo hôm nay', bg: CxColors.wood100, fg: CxColors.wood800),
                      const SizedBox(height: 6),
                      Text(a.title, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
