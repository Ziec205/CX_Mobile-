import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'upgrade_screen.dart';

/// Thêm/sửa cây. Chỉ gửi dữ liệu cây lên BE; ảnh thêm ở màn hình chi tiết và lưu trên máy.
class PlantFormScreen extends StatefulWidget {
  const PlantFormScreen({super.key, this.plant});
  final MyPlant? plant;
  @override
  State<PlantFormScreen> createState() => _PlantFormScreenState();
}

class _PlantFormScreenState extends State<PlantFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.plant?.name ?? '');
  late final _location = TextEditingController(text: widget.plant?.location ?? '');
  late final _note = TextEditingController(text: widget.plant?.note ?? '');
  late Species? _species = widget.plant?.speciesId == null ? null : Species(widget.plant!.speciesId!, widget.plant!.speciesName ?? widget.plant!.speciesId!);
  late DateTime? _acquired = widget.plant?.acquiredAt;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final app = context.read<AppState>();
    final body = {
      'name': _name.text.trim(),
      'speciesId': _species?.id,
      'location': _location.text.trim().isEmpty ? null : _location.text.trim(),
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      'acquiredAt': _acquired == null ? null : DateTime.utc(_acquired!.year, _acquired!.month, _acquired!.day).toIso8601String(),
    };
    try {
      if (widget.plant == null) {
        await app.api.post('me/garden/plants', body);
      } else {
        await app.api.put('me/garden/plants/${widget.plant!.id}', body);
      }
      await app.syncGarden();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isPlanLimit) {
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Vườn đã đủ cây'),
            content: Text(e.message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Để sau')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xem gói')),
            ],
          ),
        );
        if (go == true && mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const UpgradeScreen()));
      } else {
        showError(context, e);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickSpecies() async {
    final s = await showModalBottomSheet<Species>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const _SpeciesSearch(),
    );
    if (s != null) {
      setState(() => _species = s);
      if (_name.text.trim().isEmpty) _name.text = s.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.plant == null ? 'Thêm cây' : 'Sửa cây')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(
            controller: _name,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Tên gọi *', hintText: 'Vd: Trầu bà góc phòng khách'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Nhập tên cây' : null,
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickSpecies,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Loài (không bắt buộc)',
                suffixIcon: _species == null ? const Icon(Icons.search_rounded) : IconButton(tooltip: 'Bỏ chọn', icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _species = null)),
              ),
              child: Text(_species?.name ?? 'Chọn loài để có ảnh minh họa và gợi ý chăm', style: TextStyle(color: _species == null ? CxColors.stone500 : CxColors.stone900)),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Vị trí đặt', hintText: 'Ban công, sân thượng…')),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _acquired ?? DateTime.now(), firstDate: DateTime(1990), lastDate: DateTime.now());
              if (d != null) setState(() => _acquired = d);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Ngày bắt đầu trồng', suffixIcon: Icon(Icons.event_rounded)),
              child: Text(_acquired == null ? 'Chưa chọn' : vnDate(_acquired!)),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(controller: _note, maxLines: 4, maxLength: 2000, decoration: const InputDecoration(labelText: 'Ghi chú')),
          const SizedBox(height: 8),
          const Text('Ảnh cây thêm ở trang chi tiết cây, lưu ngay trên điện thoại (không tải lên máy chủ).', style: TextStyle(color: CxColors.stone500, fontSize: 13)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Lưu'),
          ),
        ]),
      ),
    );
  }
}

class _SpeciesSearch extends StatefulWidget {
  const _SpeciesSearch();
  @override
  State<_SpeciesSearch> createState() => _SpeciesSearchState();
}

class _SpeciesSearchState extends State<_SpeciesSearch> {
  List<Species> _items = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final list = (await context.read<AppState>().api.get('species', query: {'q': q, 'limit': 30}) as List).cast<Map<String, dynamic>>();
      if (mounted) setState(() => _items = list.map(Species.fromJson).toList());
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Tìm loài: trầu bà, lưỡi hổ…', prefixIcon: Icon(Icons.search_rounded)),
            onChanged: (q) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
            },
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView.builder(
            itemCount: _items.length,
            itemBuilder: (context, i) {
              final s = _items[i];
              return ListTile(
                leading: const Icon(Icons.local_florist_outlined, color: CxColors.emerald600),
                title: Text(s.name),
                subtitle: s.scientificName == null ? null : Text(s.scientificName!, style: const TextStyle(fontStyle: FontStyle.italic)),
                onTap: () => Navigator.pop(context, s),
              );
            },
          ),
        ),
      ]),
    );
  }
}
