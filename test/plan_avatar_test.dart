import 'package:cham_xanh/api/api_client.dart';
import 'package:cham_xanh/screens/account_screen.dart';
import 'package:cham_xanh/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Widget host(String? plan) => MaterialApp(home: Scaffold(body: Center(child: PlanAvatar(name: 'an', plan: plan))));

  testWidgets('nhãn avatar theo gói', (t) async {
    await t.pumpWidget(host('Plus'));
    expect(find.text('PLUS'), findsOneWidget);
    await t.pumpWidget(host('Pro'));
    expect(find.text('PRO'), findsOneWidget);
    await t.pumpWidget(host('Free'));
    expect(find.text('PLUS'), findsNothing);
    expect(find.text('PRO'), findsNothing);
    expect(find.text('A'), findsOneWidget);
    await t.pumpWidget(host(null));
    expect(find.text('A'), findsOneWidget);
  });

  test('lỗi mạng không làm hỏng và không gán gói', () async {
    final app = AppState(api: ApiClient(client: MockClient((_) async => throw http.ClientException('x')), store: MemoryTokenStore(), baseUrl: 'https://api.test'));
    await app.refreshPlan();
    expect(app.plan, isNull);
  });
}
