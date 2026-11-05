import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../services/reminder_schedule.dart';
import '../state/app_state.dart';
import 'account_screen.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/plant_avatar.dart';
import 'plant_detail_screen.dart';
import 'plant_form_screen.dart';

/// Hồ sơ vườn: lưới cây có ảnh lớn và trạng thái chăm sóc hôm nay (dữ liệu từ BE, ảnh từ máy).
class GardenScreen extends StatelessWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final plants = app.plants;
    final today = app.today;
    return Scaffold(
      appBar: AppBar(title: const Text('Vườn của tôi'), actions: const [AccountAction()]),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-plant',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlantFormScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm cây'),
      ),
      body: RefreshIndicator(
        onRefresh: app.syncGarden,
        child: plants == null
            ? (app.gardenError != null
                ? ListView(children: [const SizedBox(height: 80), ErrorState(error: app.gardenError, onRetry: app.syncGarden)])
                : const Center(child: CircularProgressIndicator()))
            : plants.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 60),
                    EmptyState(
                      icon: Icons.yard_outlined,
                      title: 'Vườn của bạn còn trống',
                      message: 'Thêm cây đầu tiên để lưu ảnh trên máy và được nhắc tưới như báo thức.',
                    ),
                  ])
                : CustomScrollView(slivers: [
                    SliverToBoxAdapter(child: _Summary(plants: plants, error: app.gardenError)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      sliver: SliverGrid.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.70,
                        ),
                        itemCount: plants.length,
                        itemBuilder: (_, i) => PlantCard(plant: plants[i], today: today.where((x) => x.plant.id == plants[i].id).toList()),
                      ),
                    ),
                  ]),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.plants, this.error});
  final List<MyPlant> plants;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final reminders = plants.expand((p) => p.reminders).where((r) => r.enabled).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          Pill('${plants.length} cây', icon: Icons.eco_rounded),
          Pill('$reminders lời nhắc', bg: CxColors.water50, fg: CxColors.water700, icon: Icons.alarm_rounded),
          const Pill('Ảnh lưu trên máy', bg: CxColors.wood100, fg: CxColors.wood800, icon: Icons.phone_android_rounded),
        ]),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text('Đang hiện dữ liệu lần trước · $error', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CxColors.danger)),
        ],
      ]),
    );
  }
}

class PlantCard extends StatelessWidget {
  const PlantCard({super.key, required this.plant, this.today = const []});
  final MyPlant plant;
  final List<TodayTask> today;

  @override
  Widget build(BuildContext context) {
    final p = plant;
    final t = Theme.of(context).textTheme;
    final pending = today.where((x) => !x.done).toList();
    final next = p.reminders.where((r) => r.enabled && r.nextAt != null).map((r) => r.nextAt!).fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    final Widget status;
    if (p.locked) {
      status = const Pill('Tạm khóa', bg: CxColors.stone100, fg: CxColors.stone700, icon: Icons.lock_outline_rounded);
    } else if (pending.isNotEmpty) {
      status = Pill(pending.first.reminder.kind == ReminderKind.watering ? 'Cần tưới hôm nay' : 'Cần chăm hôm nay',
          bg: CxColors.water500, fg: Colors.white, icon: Icons.water_drop_rounded);
    } else if (today.isNotEmpty) {
      status = const Pill('Đã chăm hôm nay', icon: Icons.check_rounded);
    } else if (next != null) {
      status = Pill('Lần tới ${vnDateTime(next)}', bg: CxColors.water50, fg: CxColors.water700, icon: Icons.schedule_rounded);
    } else {
      status = const Pill('Chưa đặt nhắc', bg: CxColors.stone100, fg: CxColors.stone600);
    }
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: p.id))),
        child: Ink(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: CxColors.line), color: Colors.white),
          child: Opacity(
            opacity: p.locked ? 0.6 : 1,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, c) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: c.maxWidth,
                        height: c.maxHeight,
                        child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: PlantAvatar(plant: p, size: c.maxWidth, radius: 0)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(p.name, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (p.speciesName != null || p.location != null)
                  Text([p.speciesName, p.location].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                      style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: status),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
