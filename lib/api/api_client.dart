import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// Lỗi từ API theo khuôn `{ code, message, details }` của BE.
class ApiException implements Exception {
  ApiException(this.code, this.message, {this.status, this.details});
  final String code;
  final String message;
  final int? status;
  final Object? details;

  bool get isUnauthorized => status == 401;
  bool get isPlanLimit => code == 'PLAN_LIMIT' || code == 'PLAN_REQUIRED';

  @override
  String toString() => message;

  static String describe(Object e) {
    if (e is ApiException) return e.message;
    if (e is TimeoutException) return 'Máy chủ phản hồi chậm, vui lòng thử lại.';
    if (e is http.ClientException) return 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.';
    return 'Có lỗi xảy ra, vui lòng thử lại.';
  }
}

class TokenPair {
  TokenPair(this.accessToken, this.refreshToken, this.expiresAt);
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  factory TokenPair.fromJson(Map<String, dynamic> j) => TokenPair(
        j['accessToken'] as String,
        j['refreshToken'] as String,
        DateTime.parse(j['accessTokenExpiresAt'] as String).toUtc(),
      );
}

/// Lưu token: dùng secure storage thật trên máy, bộ nhớ tạm khi test.
abstract class TokenStore {
  Future<TokenPair?> read();
  Future<void> write(TokenPair? t);
}

class SecureTokenStore implements TokenStore {
  static const _s = FlutterSecureStorage();

  @override
  Future<TokenPair?> read() async {
    final raw = await _s.read(key: 'tokens');
    if (raw == null) return null;
    try {
      return TokenPair.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(TokenPair? t) async {
    if (t == null) return _s.delete(key: 'tokens');
    await _s.write(
      key: 'tokens',
      value: jsonEncode({'accessToken': t.accessToken, 'refreshToken': t.refreshToken, 'accessTokenExpiresAt': t.expiresAt.toIso8601String()}),
    );
  }
}

class MemoryTokenStore implements TokenStore {
  TokenPair? value;
  @override
  Future<TokenPair?> read() async => value;
  @override
  Future<void> write(TokenPair? t) async => value = t;
}

/// Gọi API của BE (.NET) với access token; tự làm mới token khi sắp hết hạn hoặc gặp 401.
class ApiClient {
  ApiClient({http.Client? client, TokenStore? store, String? baseUrl})
      : _http = client ?? http.Client(),
        store = store ?? SecureTokenStore(),
        baseUrl = (baseUrl ?? AppConfig.apiBase).replaceAll(RegExp(r'/+$'), '');

  final http.Client _http;
  final TokenStore store;
  final String baseUrl;
  TokenPair? _tokens;
  Future<TokenPair?>? _refreshing;

  /// Gọi khi phiên hết hạn hẳn (refresh token không còn dùng được).
  void Function()? onSessionExpired;

  bool get hasSession => _tokens != null;

  Future<void> load() async => _tokens = await store.read();

  Future<void> setTokens(TokenPair? t) async {
    _tokens = t;
    await store.write(t);
  }

  /// Đường dẫn ảnh do BE trả ("/media/..") thành URL đầy đủ.
  String mediaUrl(String path) => path.startsWith('http') ? path : '$baseUrl$path';

  Uri _uri(String path, [Map<String, Object?>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && '$v'.isNotEmpty) q[k] = '$v';
    });
    return Uri.parse('$baseUrl/api/$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  Future<TokenPair?> _refresh() {
    return _refreshing ??= () async {
      try {
        final t = _tokens;
        if (t == null) return null;
        final res = await _http
            .post(_uri('auth/refresh'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'refreshToken': t.refreshToken}))
            .timeout(const Duration(seconds: 60));
        if (res.statusCode != 200) {
          if (res.statusCode == 401 || res.statusCode == 400 || res.statusCode == 403) {
            await setTokens(null);
            onSessionExpired?.call();
          }
          return null;
        }
        final pair = TokenPair.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
        await setTokens(pair);
        return pair;
      } finally {
        _refreshing = null;
      }
    }();
  }

  Future<String?> _accessToken() async {
    var t = _tokens;
    if (t == null) return null;
    if (t.expiresAt.isBefore(DateTime.now().toUtc().add(const Duration(seconds: 30)))) t = await _refresh() ?? t;
    return t.accessToken;
  }

  Future<dynamic> get(String path, {Map<String, Object?>? query}) => send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => send('POST', path, body: body);
  Future<dynamic> put(String path, [Object? body]) => send('PUT', path, body: body);
  Future<dynamic> delete(String path, {Map<String, Object?>? query}) => send('DELETE', path, query: query);

  Future<dynamic> send(String method, String path, {Object? body, Map<String, Object?>? query, bool retry = true}) async {
    final req = http.Request(method, _uri(path, query));
    req.headers['Accept'] = 'application/json';
    final token = await _accessToken();
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    // Render gói miễn phí ngủ khi vắng khách: lần gọi đầu có thể mất tới ~50 giây.
    final streamed = await _http.send(req).timeout(const Duration(seconds: 75));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 401 && retry && _tokens != null) {
      if (await _refresh() != null) return send(method, path, body: body, query: query, retry: false);
    }
    final text = utf8.decode(res.bodyBytes);
    final data = text.isEmpty ? null : _tryJson(text);
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    if (data is Map<String, dynamic>) {
      throw ApiException('${data['code'] ?? res.statusCode}', '${data['message'] ?? 'Có lỗi xảy ra (${res.statusCode})'}',
          status: res.statusCode, details: data['details']);
    }
    throw ApiException('${res.statusCode}',
        res.statusCode == 401 ? 'Phiên đăng nhập đã hết, vui lòng đăng nhập lại.' : res.statusCode >= 500 ? 'Máy chủ đang bận, thử lại sau ít phút.' : 'Có lỗi xảy ra (${res.statusCode})',
        status: res.statusCode);
  }

  /// Tải ảnh lên BE (chỉ dùng cho ảnh bài cộng đồng; ảnh cây không tải lên). Trả id media.
  Future<String> upload(String filePath, {String kind = 'CommunityPhoto'}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/media'));
    final token = await _accessToken();
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.fields['kind'] = kind;
    req.files.add(await http.MultipartFile.fromPath('file', filePath));
    final res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 90)));
    final data = _tryJson(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300 && data is Map) return data['id'] as String;
    throw ApiException(data is Map ? '${data['code']}' : '${res.statusCode}', data is Map ? '${data['message']}' : 'Tải ảnh thất bại', status: res.statusCode);
  }

  static Object? _tryJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return s;
    }
  }
}
