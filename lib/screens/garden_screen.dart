import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/chat_action.dart';
import '../widgets/common.dart';
import 'plant_detail_screen.dart';
import 'plant_form_screen.dart';

/// Hồ sơ vườn: danh sách cây (dữ liệu từ BE, ảnh từ máy).
class GardenScreen extends StatelessWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final plants = app.plants;
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ vườn'), actions: const [ChatAction()]),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-plant',
        backgroundColor: CxColors.emerald700,
        foregroundColor: Colors.white,
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
                      message: 'Thêm cây đầu tiên để lưu ảnh trên máy và đặt nhắc tưới như báo thức.',
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: plants.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      if (i == 0) return _Summary(plants: plants, error: app.gardenError);
                      return PlantCard(plant: plants[i - 1]);
                    },
                  ),
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
      padding: const EdgeInsets.only(bottom: 4),
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

class PlantCard extends StatefulWidget {
  const PlantCard({super.key, required this.plant});
  final MyPlant plant;
  @override
  State<PlantCard> createState() => _PlantCardState();
}

class _PlantCardState extends State<PlantCard> {
  File? _cover;

  @override
  void initState() {
    super.initState();
    _loadCover();
  }

  @override
  void didUpdateWidget(PlantCard old) {
    super.didUpdateWidget(old);
    if (old.plant.id != widget.plant.id) _loadCover();
  }

  Future<void> _loadCover() async {
    final files = await context.read<AppState>().photos.list(widget.plant.id, widget.plant.name);
    if (mounted) setState(() => _cover = files.isEmpty ? null : files.first);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plant;
    final t = Theme.of(context).textTheme;
    final next = p.reminders.where((r) => r.enabled && r.nextAt != null).map((r) => r.nextAt!).fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: p.id)));
          _loadCover();
        },
        child: Opacity(
          opacity: p.locked ? 0.6 : 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              PlantImage(file: _cover, url: p.speciesImageUrl, size: 84),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (p.speciesName != null || p.location != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text([p.speciesName, p.location].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                          style: t.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  const SizedBox(height: 8),
                  if (p.locked)
                    const Pill('Tạm khóa · gia hạn gói để mở', bg: CxColors.stone100, fg: CxColors.stone700, icon: Icons.lock_outline_rounded)
                  else if (next != null)
                    Pill('Nhắc tiếp: ${vnDateTime(next)}', bg: CxColors.water50, fg: CxColors.water700, icon: Icons.water_drop_rounded)
                  else
                    Text('Chưa có lời nhắc', style: t.bodySmall),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: CxColors.stone300),
            ]),
          ),
        ),
      ),
    );
  }
}
