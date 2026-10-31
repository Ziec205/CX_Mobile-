import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Chạy: SHOTS_DIR=build/shots flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_flow_test.dart
/// Ghi ảnh màn hình + vị trí các nút (để vẽ mũi tên) ra SHOTS_DIR.
Future<void> main() => integrationDriver(responseDataCallback: (data) async {
      final dir = Directory(Platform.environment['SHOTS_DIR'] ?? 'build/shots')..createSync(recursive: true);
      final shots = (data?['shots'] as List?) ?? const [];
      final index = <Map<String, dynamic>>[];
      for (final s in shots.cast<Map<String, dynamic>>()) {
        File('${dir.path}/${s['name']}.png').writeAsBytesSync(base64Decode(s['png'] as String));
        index.add(Map.of(s)..remove('png'));
      }
      File('${dir.path}/shots.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(index));
      stdout.writeln('Đã lưu ${shots.length} ảnh vào ${dir.path}');
    });
