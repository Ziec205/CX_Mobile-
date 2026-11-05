import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/care_actions.dart';
import '../widgets/common.dart';
import 'plant_form_screen.dart';
import 'reminder_sheet.dart';

class PlantDetailScreen extends StatefulWidget {
  const PlantDetailScreen({super.key, required this.plantId});
  final String plantId;
  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  List<File> _photos = [];
  bool _adding = false;

  MyPlant? _plant(AppState app) => app.plants?.where((p) => p.id == widget.plantId).firstOrNull;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPhotos());
  }

  Future<void> _loadPhotos() async {
    final app = context.read<AppState>();
    final p = _plant(app);
    if (p == null) return;
    try {
      final list = await app.photos.list(p.id, p.name);
      if (mounted) setState(() => _photos = list);
    } catch (_) {}
  }

  Future<void> _addPhoto(ImageSource source) async {
    final app = context.read<AppState>();
    final p = _plant(app)!;
    final picked = source == ImageSource.camera
        ? [if (await ImagePicker().pickImage(source: source, imageQuality: 88, maxWidth: 2400) case final x?) x]
        : await ImagePicker().pickMultiImage(imageQuality: 88, maxWidth: 2400, limit: 10);
    if (picked.isEmpty) return;
    setState(() => _adding = true);
    var gallery = true;
    try {
      for (final x in picked) {
        final (_, inGallery) = await app.photos.add(p.id, p.name, x.path);
        gallery &= inGallery;
      }
      await _loadPhotos();
      if (mounted) {
        showInfo(context, gallery ? 'Đã lưu ${picked.length} ảnh vào máy và album "Chạm Xanh"' : 'Đã lưu ảnh trong app. Chưa có quyền lưu vào album Ảnh.');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _choosePhotoSource() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Chụp ảnh'), onTap: () {
            Navigator.pop(ctx);
            _addPhoto(ImageSource.camera);
          }),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Chọn từ thư viện'), onTap: () {
            Navigator.pop(ctx);
            _addPhoto(ImageSource.gallery);
          }),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text('Ảnh chỉ lưu trên điện thoại này (thư mục "Chạm Xanh" và album Ảnh), không tải lên máy chủ.', style: TextStyle(color: CxColors.stone500, fontSize: 13)),
          ),
        ]),
      ),
    );
  }

  Future<void> _delete(MyPlant p) async {
    var removePhotos = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('Xóa "${p.name}"?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Cây và các lời nhắc sẽ bị xóa trên cả web và app.'),
            if (_photos.isNotEmpty)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: removePhotos,
                onChanged: (v) => set(() => removePhotos = v ?? false),
                title: Text('Xóa ${_photos.length} ảnh trong app (album Ảnh vẫn giữ)'),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: CxColors.danger), onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final app = context.read<AppState>();
    try {
      await app.api.delete('me/garden/plants/${p.id}');
      if (removePhotos) await app.photos.removePlant(p.id, p.name);
      await app.syncGarden();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _toggle(MyPlant p, CareReminder r) async {
    final app = context.read<AppState>();
    try {
      await app.api.put('me/garden/plants/${p.id}/reminders/${r.id}', {
        'kind': enumApi(r.kind),
        'at': r.anchorAt.toIso8601String(),
        'repeat': enumApi(r.repeat),
        'interval': r.interval,
        'note': r.note,
        'enabled': !r.enabled,
      });
      await app.syncGarden();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _deleteReminder(MyPlant p, CareReminder r) async {
    final app = context.read<AppState>();
    try {
      await app.api.delete('me/garden/plants/${p.id}/reminders/${r.id}');
      await app.syncGarden();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = _plant(app);
    if (p == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Cây không còn trong vườn.')));
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          if (!p.locked)
            IconButton(
              tooltip: 'Sửa',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => PlantFormScreen(plant: p)));
                _loadPhotos();
              },
            ),
          IconButton(tooltip: 'Xóa cây', icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _delete(p)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await app.syncGarden();
          await _loadPhotos();
        },
        child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
          _PhotoStrip(photos: _photos, fallbackUrl: p.speciesImageUrl == null ? null : app.api.mediaUrl(p.speciesImageUrl!), adding: _adding, onAdd: _choosePhotoSource, onChanged: _loadPhotos),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: t.headlineSmall),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (p.speciesName != null) Pill(p.speciesName!, icon: Icons.local_florist_outlined),
                if (p.location?.isNotEmpty == true) Pill(p.location!, bg: CxColors.stone100, fg: CxColors.stone700, icon: Icons.place_outlined),
                if (p.acquiredAt != null) Pill('Trồng từ ${vnDate(p.acquiredAt!)}', bg: CxColors.stone100, fg: CxColors.stone700),
                if (p.locked) const Pill('Tạm khóa', bg: CxColors.wood100, fg: CxColors.wood800, icon: Icons.lock_outline_rounded),
              ]),
              if (p.note?.isNotEmpty == true) ...[const SizedBox(height: 12), Text(p.note!, style: t.bodyLarge)],
            ]),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(color: CxColors.water50, borderRadius: BorderRadius.circular(20), border: Border.all(color: CxColors.water100)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.alarm_rounded, color: CxColors.water700),
                const SizedBox(width: 8),
                Expanded(child: Text('Lời nhắc chăm cây', style: t.titleMedium?.copyWith(color: CxColors.water700))),
                if (!p.locked)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: CxColors.water700),
                    onPressed: () => showReminderSheet(context, p),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Đặt nhắc'),
                  ),
              ]),
              if (p.reminders.isEmpty)
                Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Chưa có lời nhắc. Đặt giờ tưới để điện thoại kêu như báo thức.', style: t.bodyMedium)),
              for (final r in p.reminders) _ReminderTile(plant: p, reminder: r, onToggle: () => _toggle(p, r), onDelete: () => _deleteReminder(p, r)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.plant, required this.reminder, required this.onToggle, required this.onDelete});
  final MyPlant plant;
  final CareReminder reminder;
  final VoidCallback onToggle, onDelete;

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    final t = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.only(right: 0),
      onTap: plant.locked ? null : () => showReminderSheet(context, plant, r),
      onLongPress: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Xóa lời nhắc?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
            ],
          ),
        );
        if (ok == true) onDelete();
      },
      leading: CircleAvatar(
        backgroundColor: r.enabled ? CxColors.water500 : CxColors.stone200,
        child: Icon(r.kind == ReminderKind.watering ? Icons.water_drop_rounded : Icons.spa_rounded, color: Colors.white, size: 20),
      ),
      title: Text('${reminderKindLabel[r.kind]} · ${repeatText(r.repeat, r.interval)}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text([
        r.enabled && r.nextAt != null ? 'Lần tới: ${vnDateTime(r.nextAt!)}' : 'Đang tắt',
        if (r.lastDoneAt != null) '✓ Đã làm ${timeAgo(r.lastDoneAt!.toLocal())}',
        if (r.note?.isNotEmpty == true) r.note!,
      ].join('\n')),
      isThreeLine: r.note?.isNotEmpty == true || r.lastDoneAt != null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (r.enabled && !plant.locked)
          IconButton(
            tooltip: r.kind == ReminderKind.watering ? 'Đã tưới' : 'Đã làm',
            icon: const Icon(Icons.check_circle_outline_rounded, color: CxColors.water500, size: 30),
            onPressed: () => completeCare(context, plant, r),
          ),
        Switch(value: r.enabled, activeTrackColor: CxColors.water500, onChanged: plant.locked ? null : (_) => onToggle()),
      ]),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photos, required this.fallbackUrl, required this.adding, required this.onAdd, required this.onChanged});
  final List<File> photos;
  final String? fallbackUrl;
  final bool adding;
  final VoidCallback onAdd;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (photos.isEmpty) {
      return Stack(children: [
        PlantImage(url: fallbackUrl, size: width, radius: 0),
        Positioned(
          right: 16,
          bottom: 16,
          child: FilledButton.icon(
            onPressed: adding ? null : onAdd,
            icon: adding ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_a_photo_outlined),
            label: const Text('Thêm ảnh cây'),
          ),
        ),
      ]);
    }
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        itemCount: photos.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (i == 0) {
            return InkWell(
              onTap: adding ? null : onAdd,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 120,
                decoration: BoxDecoration(color: CxColors.emerald50, borderRadius: BorderRadius.circular(18), border: Border.all(color: CxColors.emerald200)),
                child: Center(
                  child: adding
                      ? const CircularProgressIndicator()
                      : const Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add_a_photo_outlined, color: CxColors.emerald700, size: 30),
                          SizedBox(height: 6),
                          Text('Thêm ảnh', style: TextStyle(color: CxColors.emerald800, fontWeight: FontWeight.w700)),
                        ]),
                ),
              ),
            );
          }
          final f = photos[i - 1];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _PhotoViewer(file: f))).then((_) => onChanged()),
            child: Hero(tag: f.path, child: PlantImage(file: f, size: 208, radius: 18)),
          );
        },
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.file});
  final File file;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Xóa ảnh khỏi app',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                await context.read<AppState>().photos.remove(file);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
        body: Center(child: InteractiveViewer(child: Hero(tag: file.path, child: Image.file(file)))),
      );
}
