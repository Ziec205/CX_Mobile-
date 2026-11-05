import 'dart:io';

import 'package:cham_xanh/api/api_client.dart';
import 'package:cham_xanh/api/models.dart';
import 'package:cham_xanh/services/photo_store.dart';
import 'package:cham_xanh/state/app_state.dart';
import 'package:cham_xanh/widgets/plant_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('ảnh đại diện cây tải lại khi ảnh trên máy đổi', (t) async {
    SharedPreferences.setMockInitialValues({});
    final dir = await t.runAsync(() => Directory.systemTemp.createTemp('cx'));
    final store = PhotoStore(root: () async => dir!, saveToGallery: (_) async => true);
    final app = AppState(
      api: ApiClient(client: MockClient((_) async => http.Response('{}', 200)), store: MemoryTokenStore(), baseUrl: 'https://api.test'),
      photos: store,
    );
    final plant = MyPlant.fromJson({'id': 'p1', 'name': 'Trầu bà'});
    await t.pumpWidget(ChangeNotifierProvider<AppState>.value(value: app, child: MaterialApp(home: PlantAvatar(plant: plant))));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await t.pump();
    expect(find.byType(Image), findsNothing);

    await t.runAsync(() async {
      final src = File('${dir!.path}/src.jpg');
      await src.writeAsBytes([1, 2, 3]);
      await store.add('p1', 'Trầu bà', src.path);
    });
    await t.runAsync(() async {
      app.photosChanged();
      await t.pump();
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await t.pump();
    expect(find.byType(Image), findsOneWidget);
  });
}
