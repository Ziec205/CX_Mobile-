import 'package:cham_xanh/api/api_client.dart';
import 'package:cham_xanh/screens/login_screen.dart';
import 'package:cham_xanh/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('đăng ký kiểm tra tên đăng nhập và mật khẩu nhập lại', (tester) async {
    final app = AppState(api: ApiClient(client: MockClient((_) async => http.Response('', 500)), store: MemoryTokenStore(), baseUrl: 'https://api.test'));
    await tester.pumpWidget(ChangeNotifierProvider.value(value: app, child: const MaterialApp(home: LoginScreen())));
    expect(find.text('Chào mừng trở lại'), findsOneWidget);

    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pump();
    expect(find.text('Nhập lại mật khẩu'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Tên đăng nhập'), 'An');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mật khẩu'), '12345678');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nhập lại mật khẩu'), '1234567x');
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo tài khoản'));
    await tester.pump();
    expect(find.textContaining('4–30 ký tự'), findsOneWidget);
    expect(find.text('Mật khẩu nhập lại chưa khớp'), findsOneWidget);
  });
}
