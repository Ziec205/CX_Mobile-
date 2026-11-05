import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'upgrade_screen.dart';

/// Thêm/sửa cây. Chỉ gửi dữ liệu cây lên BE; ảnh chọn ở đây được lưu trên máy sau khi lưu cây.
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
  final List<XFile> _picked = [];
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
      final String id;
      if (widget.plant == null) {
        final res = await app.api.post('me/garden/plants', body) as Map<String, dynamic>;
        id = res['id'] as String;
      } else {
        await app.api.put('me/garden/plants/${widget.plant!.id}', body);
        id = widget.plant!.id;
      }
      await app.syncGarden();
      // Cây đã lưu: ảnh lỗi chỉ báo riêng, không coi là lưu cây thất bại.
      final plantName = widget.plant?.name ?? _name.text.trim();
      try {
        for (final x in _picked) {
          await app.photos.add(id, plantName, x.path);
        }
      } catch (e) {
        if (mounted) showError(context, e);
      }
      if (_picked.isNotEmpty) app.photosChanged();
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

  Future<void> _pickPhotos() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Chụp ảnh'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Chọn từ thư viện'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final files = source == ImageSource.camera
        ? [if (await picker.pickImage(source: source, imageQuality: 88, maxWidth: 2400) case final x?) x]
        : await picker.pickMultiImage(imageQuality: 88, maxWidth: 2400);
    if (mounted && files.isNotEmpty) setState(() => _picked.addAll(files));
  }

  Widget _photoArea() {
    if (_picked.isEmpty) {
      return Material(
        color: CxColors.emerald50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: CxColors.emerald200)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _pickPhotos,
          child: const SizedBox(
            height: 168,
            width: double.infinity,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_a_photo_outlined, size: 34, color: CxColors.emerald700),
              SizedBox(height: 8),
              Text('Thêm ảnh cây', style: TextStyle(fontWeight: FontWeight.w700, color: CxColors.emerald800)),
              SizedBox(height: 2),
              Text('Ảnh chỉ lưu trên điện thoại của bạn', style: TextStyle(fontSize: 13, color: CxColors.stone600)),
            ]),
          ),
        ),
      );
    }
    return SizedBox(
      height: 168,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final x in _picked)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(x.path), width: 140, height: 168, fit: BoxFit.cover)),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filledTonal(tooltip: 'Bỏ ảnh', iconSize: 18, icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _picked.remove(x))),
              ),
            ]),
          ),
        Material(
          color: CxColors.emerald50,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickPhotos,
            child: const SizedBox(width: 100, child: Icon(Icons.add_a_photo_outlined, color: CxColors.emerald700)),
          ),
        ),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: CxColors.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.plant == null ? 'Thêm cây' : 'Sửa cây')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: CxColors.stone900)) : const Text('Lưu'),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 20), children: [
          _photoArea(),
          _section('Thông tin cây', [
            TextFormField(
              controller: _name,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Tên gọi *', hintText: 'Vd: Trầu bà góc phòng khách', counterText: ''),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Nhập tên cây' : null,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickSpecies,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Loài (không bắt buộc)',
                  suffixIcon: _species == null ? const Icon(Icons.search_rounded) : IconButton(tooltip: 'Bỏ chọn', icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _species = null)),
                ),
                child: Text(_species?.name ?? 'Chọn loài', style: TextStyle(color: _species == null ? CxColors.stone500 : CxColors.stone900)),
              ),
            ),
          ]),
          _section('Nơi trồng', [
            TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Vị trí đặt', hintText: 'Ban công, sân thượng…')),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _acquired ?? DateTime.now(), firstDate: DateTime(1990), lastDate: DateTime.now());
                if (d != null) setState(() => _acquired = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Ngày bắt đầu trồng', suffixIcon: Icon(Icons.event_rounded)),
                child: Text(_acquired == null ? 'Chưa chọn' : vnDate(_acquired!)),
              ),
            ),
          ]),
          _section('Ghi chú', [
            TextFormField(controller: _note, maxLines: 3, maxLength: 2000, decoration: const InputDecoration(labelText: 'Ghi chú', counterText: '')),
          ]),
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
