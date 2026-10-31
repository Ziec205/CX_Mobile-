import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../theme.dart';

final _vnd = NumberFormat.decimalPattern('vi');
String vnd(int v) => '${_vnd.format(v)} đ';
String vnDate(DateTime d) => DateFormat('dd/MM/yyyy', 'vi').format(d.toLocal());
String vnDateTime(DateTime d) => DateFormat('HH:mm · EEE dd/MM', 'vi').format(d.toLocal());

String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  return vnDate(d);
}

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(ApiException.describe(e)), backgroundColor: CxColors.danger));
}

void showInfo(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Khung tải dữ liệu: đang tải / lỗi (nút thử lại) / có dữ liệu.
class LoadView<T> extends StatefulWidget {
  const LoadView({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext, T data, Future<void> Function() reload) builder;

  @override
  State<LoadView<T>> createState() => _LoadViewState<T>();
}

class _LoadViewState<T> extends State<LoadView<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = _data == null);
    try {
      final d = await widget.load();
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_data == null) return ErrorState(error: _error, onRetry: _reload);
    return widget.builder(context, _data as T, _reload);
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Chưa tải được dữ liệu',
        message: error == null ? null : ApiException.describe(error!),
        action: FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action, this.color = CxColors.emerald700});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: color),
          ),
          const SizedBox(height: 16),
          Text(title, style: t.titleLarge, textAlign: TextAlign.center),
          if (message != null) ...[const SizedBox(height: 8), Text(message!, style: t.bodyMedium, textAlign: TextAlign.center)],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      ),
    );
  }
}

/// Ảnh đại diện cây: ảnh chụp trên máy → ảnh minh họa loài → biểu tượng lá.
class PlantImage extends StatelessWidget {
  const PlantImage({super.key, this.file, this.url, this.size = 64, this.radius = 16});
  final File? file;
  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      color: CxColors.emerald50,
      alignment: Alignment.center,
      child: Icon(Icons.eco_rounded, color: CxColors.emerald500, size: size * 0.45),
    );
    Widget child;
    if (file != null) {
      child = Image.file(file!, width: size, height: size, fit: BoxFit.cover, cacheWidth: (size * 3).round(), errorBuilder: (_, _, _) => fallback);
    } else if (url != null) {
      child = Image.network(url!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
    } else {
      child = fallback;
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.bg = CxColors.emerald50, this.fg = CxColors.emerald800, this.icon});
  final String text;
  final Color bg, fg;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
        child: Row(children: [Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)), ?trailing]),
      );
}
