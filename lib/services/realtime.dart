import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../api/api_client.dart';
import '../api/models.dart';

/// Kết nối SignalR tới /hubs/chat (giống web lib/realtime.ts). Token hub 2 phút, lấy mới mỗi lần (re)connect.
class Realtime {
  Realtime(this.api);
  final ApiClient api;
  HubConnection? _hub;

  final _messages = StreamController<ChatMessage>.broadcast();
  final _notifications = StreamController<Map<String, dynamic>>.broadcast();
  final connected = ValueNotifier(false);

  Stream<ChatMessage> get messages => _messages.stream;
  Stream<Map<String, dynamic>> get notifications => _notifications.stream;

  Future<void> start() async {
    if (_hub != null) return;
    final hub = HubConnectionBuilder()
        .withUrl('${api.baseUrl}/hubs/chat',
            options: HttpConnectionOptions(
              requestTimeout: 20000,
              accessTokenFactory: () async => ((await api.post('auth/hub-token')) as Map<String, dynamic>)['token'] as String,
            ))
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 20000, 30000, 30000, 30000])
        .build();
    hub.on('message', (args) {
      final m = args?.isNotEmpty == true ? args!.first : null;
      if (m is Map) _messages.add(ChatMessage.fromJson(Map<String, dynamic>.from(m)));
    });
    hub.on('notification', (args) {
      final n = args?.isNotEmpty == true ? args!.first : null;
      if (n is Map) _notifications.add(Map<String, dynamic>.from(n));
    });
    hub.onclose(({error}) => connected.value = false);
    hub.onreconnected(({connectionId}) => connected.value = true);
    hub.onreconnecting(({error}) => connected.value = false);
    _hub = hub;
    try {
      await hub.start();
      connected.value = true;
    } catch (e) {
      debugPrint('Không kết nối được chat realtime: $e');
      _hub = null;
    }
  }

  Future<void> stop() async {
    final hub = _hub;
    _hub = null;
    connected.value = false;
    if (hub != null) await hub.stop();
  }
}
