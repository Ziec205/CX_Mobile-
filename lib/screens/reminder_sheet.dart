import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Thêm/sửa lời nhắc. Lưu lên BE (đồng bộ với web), sau đó đặt lại báo thức trên máy.
Future<bool?> showReminderSheet(BuildContext context, MyPlant plant, [CareReminder? existing]) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _ReminderSheet(plant: plant, existing: existing),
    );

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({required this.plant, this.existing});
  final MyPlant plant;
  final CareReminder? existing;
  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late ReminderKind _kind = widget.existing?.kind ?? ReminderKind.watering;
  late ReminderRepeat _repeat = widget.existing?.repeat ?? ReminderRepeat.daily;
  late int _interval = widget.existing?.interval ?? 1;
  late DateTime _at = _initialAt();
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  bool _busy = false;

  DateTime _initialAt() {
    final e = widget.existing;
    if (e != null) return (e.repeat == ReminderRepeat.none ? e.anchorAt : e.nextAt ?? e.anchorAt).toLocal();
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day, 7, 0); // mặc định 7 giờ sáng
    if (!d.isAfter(now)) d = d.add(const Duration(days: 1));
    return d;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _at, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (d != null) setState(() => _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
    if (t != null) setState(() => _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final app = context.read<AppState>();
    final body = {
      'kind': enumApi(_kind),
      'at': _at.toUtc().toIso8601String(),
      'repeat': enumApi(_repeat),
      'interval': _interval,
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      'enabled': true,
    };
    final path = widget.existing == null ? 'me/garden/plants/${widget.plant.id}/reminders' : 'me/garden/plants/${widget.plant.id}/reminders/${widget.existing!.id}';
    try {
      try {
        widget.existing == null ? await app.api.post(path, body) : await app.api.put(path, body);
      } on ApiException catch (e) {
        // Web gửi nhắc qua email nên BE cần email; hỏi một lần rồi lưu lại.
        if (e.code != 'EMAIL_REQUIRED' || !mounted || !await askEmail(context)) rethrow;
        widget.existing == null ? await app.api.post(path, body) : await app.api.put(path, body);
      }
      await app.notifications.requestPermissions();
      await app.syncGarden();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(widget.existing == null ? 'Đặt nhắc cho ${widget.plant.name}' : 'Sửa lời nhắc', style: t.titleLarge),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in ReminderKind.values)
              ChoiceChip(
                label: Text(reminderKindLabel[k]!),
                selected: _kind == k,
                selectedColor: CxColors.water500,
                labelStyle: TextStyle(color: _kind == k ? Colors.white : CxColors.stone700, fontWeight: FontWeight.w600),
                showCheckmark: false,
                onSelected: (_) => setState(() => _kind = k),
              ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.event_rounded), label: Text(vnDate(_at)))),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule_rounded),
                label: Text('${_at.hour.toString().padLeft(2, '0')}:${_at.minute.toString().padLeft(2, '0')}'),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<ReminderRepeat>(
                initialValue: _repeat,
                decoration: const InputDecoration(labelText: 'Lặp lại'),
                items: [
                  for (final r in ReminderRepeat.values)
                    DropdownMenuItem(value: r, child: Text(r == ReminderRepeat.none ? 'Không lặp' : 'Theo ${reminderRepeatUnit[r]}')),
                ],
                onChanged: (v) => setState(() => _repeat = v ?? ReminderRepeat.none),
              ),
            ),
            if (_repeat != ReminderRepeat.none) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 132,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Mỗi', contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    IconButton(visualDensity: VisualDensity.compact, onPressed: _interval > 1 ? () => setState(() => _interval--) : null, icon: const Icon(Icons.remove_rounded)),
                    Text('$_interval', style: t.titleMedium),
                    IconButton(visualDensity: VisualDensity.compact, onPressed: _interval < 365 ? () => setState(() => _interval++) : null, icon: const Icon(Icons.add_rounded)),
                  ]),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 6),
          Text(repeatText(_repeat, _interval), style: t.bodySmall),
          const SizedBox(height: 14),
          TextField(controller: _note, maxLength: 300, decoration: const InputDecoration(labelText: 'Ghi chú (vd: tưới 200ml, tưới gốc)')),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CxColors.water500),
            onPressed: _busy ? null : _save,
            child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Lưu lời nhắc'),
          ),
        ]),
      ),
    );
  }
}

/// Hỏi email (BE dùng để gửi nhắc qua email cho web). Trả true nếu đã lưu.
Future<bool> askEmail(BuildContext context) async {
  final app = context.read<AppState>();
  final c = TextEditingController(text: app.me?.email ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Email nhận nhắc lịch'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Điện thoại sẽ kêu như báo thức. Chạm Xanh cũng gửi email để bạn không lỡ khi không mang máy.'),
        const SizedBox(height: 12),
        TextField(controller: c, keyboardType: TextInputType.emailAddress, autofocus: true, decoration: const InputDecoration(labelText: 'Email')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Để sau')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
      ],
    ),
  );
  if (ok != true) return false;
  await app.api.put('me', {'email': c.text.trim()});
  await app.refreshMe();
  return true;
}
