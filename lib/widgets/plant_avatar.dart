import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Ảnh đại diện cây: ảnh mới nhất chụp trên máy → ảnh minh họa loài → biểu tượng lá.
class PlantAvatar extends StatefulWidget {
  const PlantAvatar({super.key, required this.plant, this.size = 64, this.radius = 18});
  final MyPlant plant;
  final double size;
  final double radius;
  @override
  State<PlantAvatar> createState() => _PlantAvatarState();
}

class _PlantAvatarState extends State<PlantAvatar> {
  File? _cover;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PlantAvatar old) {
    super.didUpdateWidget(old);
    if (old.plant.id != widget.plant.id) _load();
  }

  Future<void> _load() async {
    try {
      final files = await context.read<AppState>().photos.list(widget.plant.id, widget.plant.name);
      if (mounted) setState(() => _cover = files.isEmpty ? null : files.first);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final url = widget.plant.speciesImageUrl == null ? null : api.mediaUrl(widget.plant.speciesImageUrl!);
    return PlantImage(file: _cover, url: url, size: widget.size, radius: widget.radius);
  }
}
