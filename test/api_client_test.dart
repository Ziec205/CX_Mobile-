import 'dart:convert';

import 'package:cham_xanh/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TokenPair pair(String a, {Duration ttl = const Duration(minutes: 15)}) => TokenPair(a, 'refresh-$a', DateTime.now().toUtc().add(ttl));

  test('gặp 401 thì làm mới token rồi gọi lại', () async {
    final calls = <String>[];
    final client = MockClient((req) async {
      calls.add('${req.method} ${req.url.path} ${req.headers['Authorization'] ?? ''}');
      if (req.url.path == '/api/auth/refresh') {
        return http.Response(jsonEncode({'accessToken': 'new', 'accessTokenExpiresAt': DateTime.now().toUtc().add(const Duration(minutes: 15)).toIso8601String(), 'refreshToken': 'r2'}), 200);
      }
      if (req.headers['Authorization'] == 'Bearer old') return http.Response('', 401);
      return http.Response(jsonEncode({'id': 'u1', 'displayName': 'An'}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final store = MemoryTokenStore()..value = pair('old');
    final api = ApiClient(client: client, store: store, baseUrl: 'https://api.test/');
    await api.load();
    final me = await api.get('me') as Map<String, dynamic>;
    expect(me['displayName'], 'An');
    expect(calls, ['GET /api/me Bearer old', 'POST /api/auth/refresh ', 'GET /api/me Bearer new']);
    expect(store.value!.accessToken, 'new');
  });

  test('refresh hỏng thì xóa phiên và báo hết hạn', () async {
    var expired = false;
    final client = MockClient((req) async => req.url.path == '/api/auth/refresh' ? http.Response('', 401) : http.Response('', 401));
    final store = MemoryTokenStore()..value = pair('old');
    final api = ApiClient(client: client, store: store, baseUrl: 'https://api.test')..onSessionExpired = () => expired = true;
    await api.load();
    await expectLater(api.get('me'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
    expect(expired, isTrue);
    expect(store.value, isNull);
  });

  test('lỗi nghiệp vụ trả về code và message tiếng Việt', () async {
    final client = MockClient((req) async => http.Response(utf8.decode(utf8.encode(jsonEncode({'code': 'PLAN_LIMIT', 'message': 'Gói Miễn phí lưu tối đa 3 cây.'}))), 409,
        headers: {'content-type': 'application/json; charset=utf-8'}));
    final api = ApiClient(client: client, store: MemoryTokenStore(), baseUrl: 'https://api.test');
    try {
      await api.post('me/garden/plants', {'name': 'x'});
      fail('phải ném lỗi');
    } on ApiException catch (e) {
      expect(e.code, 'PLAN_LIMIT');
      expect(e.isPlanLimit, isTrue);
      expect(e.message, 'Gói Miễn phí lưu tối đa 3 cây.');
    }
  });

  test('mediaUrl ghép đường dẫn tương đối', () {
    final api = ApiClient(client: MockClient((_) async => http.Response('', 200)), store: MemoryTokenStore(), baseUrl: 'https://api.test');
    expect(api.mediaUrl('/media/a/card.webp'), 'https://api.test/media/a/card.webp');
    expect(api.mediaUrl('https://cdn/x.webp'), 'https://cdn/x.webp');
  });
}
