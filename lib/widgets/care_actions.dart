import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Bấm "Đã tưới/Đã làm": lưu lên máy chủ (web thấy ngay), cảm ơn người dùng và cho hoàn tác nếu bấm nhầm.
Future<bool> completeCare(BuildContext context, MyPlant plant, CareReminder reminder) async {
  final app = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  HapticFeedback.mediumImpact();
  try {
    await app.markDone(plant, reminder);
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
  final thanks = reminder.kind == ReminderKind.watering
      ? ['${plant.name} cảm ơn bạn 💚', 'Tưới xong rồi, ${plant.name} mát rượi 💧', 'Tuyệt vời! ${plant.name} đang cười đó 🌿']
      : ['Xong rồi! ${plant.name} cảm ơn bạn 💚', 'Bạn chăm cây thật chu đáo 🌱'];
  var text = thanks[Random().nextInt(thanks.length)];
  if (app.streak >= 2) text += ' · 🔥 ${app.streak} ngày liên tiếp';
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Hoàn tác',
        onPressed: () => app.undoDone(plant, reminder).catchError((_) {}),
      ),
    ));
  return true;
}

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 11) return 'Chào buổi sáng';
  if (h < 14) return 'Chào buổi trưa';
  if (h < 18) return 'Chào buổi chiều';
  return 'Chào buổi tối';
}

String greetingEmoji(DateTime now) => now.hour < 11 ? '🌤️' : now.hour < 18 ? '☀️' : '🌙';
