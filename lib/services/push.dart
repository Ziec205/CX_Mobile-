import 'dart:io';

import '../api/api_client.dart';

/// Chỗ gắn thông báo đẩy (chưa dùng Firebase).
///
/// Khi thêm FCM: tạo lớp `FcmPushProvider implements PushProvider` (firebase_messaging),
/// trả token ở [getToken], gọi [PushService.register] sau khi đăng nhập. BE đã có
/// `POST /api/me/notifications/devices { token, platform }` và `DELETE ...?token=`.
abstract class PushProvider {
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
}

class NoPushProvider implements PushProvider {
  @override
  Future<String?> getToken() async => null;
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
}

class PushService {
  PushService(this.api, [PushProvider? provider]) : provider = provider ?? NoPushProvider();
  final ApiClient api;
  final PushProvider provider;
  String? _token;

  Future<void> register() async {
    final token = await provider.getToken();
    if (token == null) return;
    _token = token;
    await api.post('me/notifications/devices', {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'});
    provider.onTokenRefresh.listen((t) async {
      _token = t;
      await api.post('me/notifications/devices', {'token': t, 'platform': Platform.isIOS ? 'ios' : 'android'});
    });
  }

  Future<void> unregister() async {
    final t = _token;
    if (t == null) return;
    try {
      await api.delete('me/notifications/devices', query: {'token': t});
    } catch (_) {}
  }
}
