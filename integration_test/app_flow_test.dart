// Kiểm thử đầu-cuối trên máy ảo/desktop với BE thật: đi qua mọi màn hình, chụp ảnh và ghi vị trí
// các nút để làm tài liệu hướng dẫn (mũi tên đỏ). Cần BE có dữ liệu mẫu (xem tool/e2e/seed.py).
//
// flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_flow_test.dart \
//   --dart-define=API_BASE=http://10.0.2.2:5080 --dart-define=LISTING_ID=... --dart-define=SELLER_TOKEN=...
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cham_xanh/api/api_client.dart';
import 'package:cham_xanh/api/models.dart';
import 'package:cham_xanh/main.dart';
import 'package:cham_xanh/services/notifications.dart';
import 'package:cham_xanh/services/photo_store.dart';
import 'package:cham_xanh/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:5080');
const listingId = String.fromEnvironment('LISTING_ID');
const sellerToken = String.fromEnvironment('SELLER_TOKEN');

late final IntegrationTestWidgetsFlutterBinding binding;
final _boundary = GlobalKey();
final _shots = <Map<String, dynamic>>[];

typedef Mark = (Finder, String);

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 40}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 200));
    if (f.evaluate().isNotEmpty) return;
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 150)));
  }
  final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().toSet().join(' | ');
  throw TestFailure('Không thấy $f sau $seconds giây. Đang hiện: $texts');
}

Finder nav(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

/// Cả ô tab (biểu tượng + chữ) để khung đỏ bao trọn.
Finder navTab(String label) => find.ancestor(of: nav(label), matching: find.byType(NavigationDestination));
Finder btn(String text) => find.widgetWithText(FilledButton, text);
Finder field(String label) => find.widgetWithText(TextFormField, label);

/// Chụp màn hình (đúng phần app vẽ) + vị trí các nút cần chú thích.
Future<void> shot(WidgetTester t, String name, String title, String desc, List<Mark> marks) async {
  await settle(t, 700);
  final ro = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // Ảnh đủ nét cho PDF A4 mà nhẹ khi gửi về máy chạy test.
  final dpr = min(t.view.devicePixelRatio, 2.0);
  final png = await t.runAsync(() async {
    final img = await ro.toImage(pixelRatio: dpr);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final rects = <Map<String, dynamic>>[];
  for (final (f, label) in marks) {
    if (f.evaluate().isEmpty) {
      debugPrint('[$name] không thấy nút "$label"');
      continue;
    }
    final r = t.getRect(f.first);
    rects.add({'label': label, 'x': r.left, 'y': r.top, 'w': r.width, 'h': r.height});
  }
  final size = t.view.physicalSize / t.view.devicePixelRatio;
  _shots.add({'name': name, 'title': title, 'desc': desc, 'dpr': dpr, 'w': size.width, 'h': size.height, 'marks': rects, 'png': base64Encode(png!)});
  debugPrint('Đã chụp $name (${rects.length} chú thích)');
}

/// Ảnh cây mẫu vẽ bằng Canvas (máy ảo không có ảnh thật).
Future<String> demoPhoto(WidgetTester t, String name, Color pot, int seed) async {
  return (await t.runAsync(() async {
    const w = 900.0, h = 1200.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, h), [const Color(0xFFE9F3EA), const Color(0xFFA9D2B0)]));
    final rnd = Random(seed);
    for (var i = 0; i < 14; i++) {
      final a = -pi / 2 + (rnd.nextDouble() - .5) * 2.4;
      final len = 300 + rnd.nextDouble() * 220;
      final end = Offset(w / 2 + cos(a) * len, 760 + sin(a) * len);
      c.drawLine(const Offset(w / 2, 760), end, Paint()..color = const Color(0xFF2F8249)..strokeWidth = 10);
      c.save();
      c.translate(end.dx, end.dy);
      c.rotate(a + pi / 2);
      c.drawOval(const Rect.fromLTWH(-80, -120, 160, 240), Paint()..color = i.isEven ? const Color(0xFF1F6B3A) : const Color(0xFF4F9C63));
      c.restore();
    }
    final path = Path()..moveTo(250, 760)..lineTo(650, 760)..lineTo(600, 1100)..lineTo(300, 1100)..close();
    c.drawPath(path, Paint()..color = pot);
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    final f = File('${(await getTemporaryDirectory()).path}/$name.png');
    await f.writeAsBytes(bytes);
    return f.path;
  }))!;
}

Future<void> sellerSays(String conversationId, String text) async {
  if (sellerToken.isEmpty) return;
  await http.post(Uri.parse('$apiBase/api/conversations/$conversationId/messages'),
      headers: {'Authorization': 'Bearer $sellerToken', 'Content-Type': 'application/json'}, body: jsonEncode({'type': 'Text', 'text': text}));
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Đi qua toàn bộ app với BE thật', (t) async {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      // Chạy trên desktop: giả lập màn hình điện thoại 6.4" (411×891 dp).
      t.view.physicalSize = const Size(1080, 2340);
      t.view.devicePixelRatio = 2.625;
    }
    await initializeDateFormatting('vi');
    await CareNotifications.instance.init();
    final desktop = Platform.isLinux || Platform.isMacOS || Platform.isWindows;
    final photoRoot = desktop ? await Directory.systemTemp.createTemp('cx_e2e') : null;
    final app = AppState(
      api: ApiClient(store: MemoryTokenStore(), baseUrl: apiBase),
      // Desktop không có album Ảnh: lưu vào thư mục tạm. Trên máy ảo Android dùng thư mục + album thật.
      photos: desktop ? PhotoStore(root: () async => photoRoot!, saveToGallery: (_) async => false) : null,
    );
    await t.pumpWidget(ChangeNotifierProvider.value(value: app, child: RepaintBoundary(key: _boundary, child: const ChamXanhApp())));
    await t.runAsync(app.bootstrap);
    await waitFor(t, find.text('Chào mừng trở lại'));

    // ---------- Đăng nhập / đăng ký ----------
    await shot(t, '01-dang-nhap', 'Đăng nhập', 'Dùng chung tài khoản với web Chạm Xanh (tên đăng nhập + mật khẩu).', [
      (field('Tên đăng nhập'), 'Nhập tên đăng nhập'),
      (field('Mật khẩu'), 'Nhập mật khẩu (bấm biểu tượng mắt để hiện/ẩn)'),
      (btn('Đăng nhập'), 'Đăng nhập vào app'),
      (find.text('Chưa có tài khoản? Đăng ký'), 'Chuyển sang tạo tài khoản mới'),
    ]);
    await t.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await settle(t);
    final user = 'vuon.${DateTime.now().millisecondsSinceEpoch % 1000000}';
    await t.enterText(field('Tên đăng nhập'), user);
    await t.enterText(field('Mật khẩu'), 'matkhau123');
    await t.enterText(field('Nhập lại mật khẩu'), 'matkhau123');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(t, '02-dang-ky', 'Tạo tài khoản', 'Tên đăng nhập 4–30 ký tự (chữ không dấu, số, dấu chấm, gạch dưới), mật khẩu tối thiểu 8 ký tự.', [
      (field('Tên đăng nhập'), 'Tên đăng nhập mới'),
      (field('Nhập lại mật khẩu'), 'Nhập lại mật khẩu để xác nhận'),
      (btn('Tạo tài khoản'), 'Tạo tài khoản và vào app'),
    ]);
    await t.tap(btn('Tạo tài khoản'));
    await waitFor(t, find.text('Vườn của bạn còn trống'));

    // ---------- Hồ sơ vườn ----------
    await shot(t, '03-vuon-trong', 'Hồ sơ vườn (lần đầu)', 'Màn hình chính. Thanh dưới cùng chuyển giữa 5 mục của app.', [
      (find.byType(FloatingActionButton), 'Thêm cây mới vào vườn'),
      (find.byTooltip('Tin nhắn'), 'Mở tin nhắn (số đỏ = tin chưa đọc)'),
      (navTab('Vườn'), 'Hồ sơ vườn'),
      (navTab('Nhắc tưới'), 'Lịch nhắc tưới, bón phân'),
      (navTab('Cộng đồng'), 'Hỏi đáp, khoe cây'),
      (navTab('Khám phá'), 'Bài viết về cây'),
      (navTab('Tài khoản'), 'Tài khoản, nâng cấp gói'),
    ]);
    await t.tap(find.text('Thêm cây'));
    await waitFor(t, field('Tên gọi *'));
    await t.enterText(field('Tên gọi *'), 'Trầu bà góc phòng khách');
    await t.enterText(field('Vị trí đặt'), 'Phòng khách');
    await t.tap(find.text('Chọn loài để có ảnh minh họa và gợi ý chăm'));
    await waitFor(t, find.byType(ListTile));
    await t.enterText(find.widgetWithText(TextField, 'Tìm loài: trầu bà, lưỡi hổ…'), 'trau');
    await waitFor(t, find.widgetWithText(ListTile, 'Trầu bà'));
    await shot(t, '05-chon-loai', 'Chọn loài cây', 'Gõ tên (có dấu hoặc không dấu) để tìm trong danh mục loài của Chạm Xanh.', [
      (find.widgetWithText(TextField, 'trau'), 'Ô tìm loài'),
      (find.widgetWithText(ListTile, 'Trầu bà'), 'Bấm để chọn loài'),
    ]);
    await t.tap(find.widgetWithText(ListTile, 'Trầu bà'));
    await settle(t);
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(t, '04-them-cay', 'Thêm cây', 'Chỉ dữ liệu cây được lưu lên máy chủ (đồng bộ với web). Ảnh cây thêm ở trang chi tiết và chỉ lưu trên điện thoại.', [
      (field('Tên gọi *'), 'Tên gọi của cây (bắt buộc)'),
      (find.text('Trầu bà'), 'Loài cây: chọn để có ảnh minh họa'),
      (field('Vị trí đặt'), 'Vị trí đặt cây'),
      (find.text('Chưa chọn'), 'Ngày bắt đầu trồng'),
      (btn('Lưu'), 'Lưu cây'),
    ]);
    await t.tap(btn('Lưu'));
    await waitFor(t, find.text('Trầu bà góc phòng khách'));
    // Thêm 2 cây nữa qua API để vườn có dữ liệu.
    await t.runAsync(() async {
      await app.api.post('me/garden/plants', {'name': 'Lưỡi hổ ban công', 'speciesId': 'luoi-ho', 'location': 'Ban công'});
      await app.api.post('me/garden/plants', {'name': 'Sen đá bàn làm việc', 'speciesId': 'sen-da-kim-tuyen', 'location': 'Bàn làm việc'});
    });
    final plants = app.plants!;
    final trauBa = plants.firstWhere((p) => p.name.startsWith('Trầu bà'));
    final p1 = await demoPhoto(t, 'trau-ba-1', const Color(0xFFC4704A), 1);
    final p2 = await demoPhoto(t, 'trau-ba-2', const Color(0xFF10361E), 7);
    await t.runAsync(() async {
      await app.photos.add(trauBa.id, trauBa.name, p1);
      await app.photos.add(trauBa.id, trauBa.name, p2);
      await app.syncGarden();
    });
    await waitFor(t, find.text('Sen đá bàn làm việc'));
    await settle(t, 1500);

    // ---------- Chi tiết cây, ảnh, nhắc tưới ----------
    await t.tap(find.text('Trầu bà góc phòng khách'));
    await waitFor(t, find.text('Thêm ảnh'));
    await shot(t, '07-chi-tiet-cay', 'Chi tiết cây', 'Ảnh chụp lưu trong thư mục "Chạm Xanh/<tên cây>" của app và album "Chạm Xanh" trong Ảnh, không tải lên máy chủ.', [
      (find.text('Thêm ảnh'), 'Chụp hoặc chọn ảnh cây'),
      (find.byType(Hero).first, 'Ảnh đã lưu trên máy (bấm để xem lớn/xóa)'),
      (find.byTooltip('Sửa'), 'Sửa thông tin cây'),
      (find.byTooltip('Xóa cây'), 'Xóa cây'),
      (find.text('Đặt nhắc'), 'Đặt lời nhắc chăm cây'),
    ]);
    await t.tap(find.text('Thêm ảnh'));
    await waitFor(t, find.text('Chụp ảnh'));
    await shot(t, '08-them-anh', 'Thêm ảnh cây', 'Chọn nguồn ảnh. Ảnh được chép vào thư mục của cây và album "Chạm Xanh".', [
      (find.text('Chụp ảnh'), 'Mở camera chụp ảnh mới'),
      (find.text('Chọn từ thư viện'), 'Chọn nhiều ảnh có sẵn'),
    ]);
    navigatorKey.currentState!.pop();
    await settle(t);
    await t.tap(find.text('Đặt nhắc'));
    await waitFor(t, find.text('Lưu lời nhắc'));
    await t.enterText(find.widgetWithText(TextField, 'Ghi chú (vd: tưới 200ml, tưới gốc)'), 'Tưới 200ml quanh gốc');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(t, '09-dat-nhac', 'Đặt lời nhắc', 'Đến giờ, điện thoại đổ chuông như báo thức. Lời nhắc đồng bộ với web.', [
      (find.widgetWithText(ChoiceChip, 'Tưới nước'), 'Chọn việc: tưới, bón phân, cắt tỉa…'),
      (find.byIcon(Icons.event_rounded), 'Chọn ngày bắt đầu'),
      (find.byIcon(Icons.schedule_rounded), 'Chọn giờ nhắc'),
      (find.byType(DropdownButtonFormField<ReminderRepeat>), 'Lặp lại theo ngày/tuần/tháng/năm'),
      (find.byIcon(Icons.add_rounded).last, 'Tăng/giảm chu kỳ (mỗi N ngày)'),
      (find.text('Lưu lời nhắc'), 'Lưu và hẹn chuông'),
    ]);
    await t.tap(find.text('Lưu lời nhắc'));
    await waitFor(t, find.text('Email nhận nhắc lịch'));
    await t.enterText(find.widgetWithText(TextField, 'Email'), '$user@example.com');
    await shot(t, '10-email', 'Email nhận nhắc', 'Lần đầu đặt nhắc, app hỏi email để Chạm Xanh gửi thêm nhắc qua email (giống web).', [
      (find.widgetWithText(TextField, 'Email'), 'Nhập email'),
      (find.widgetWithText(FilledButton, 'Lưu'), 'Lưu email và tiếp tục'),
    ]);
    await t.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await waitFor(t, find.textContaining('Tưới nước · Mỗi ngày'));
    await t.runAsync(() async {
      final at = DateTime.now().add(const Duration(hours: 2));
      final ho = app.plants!.firstWhere((p) => p.name.startsWith('Lưỡi hổ'));
      await app.api.post('me/garden/plants/${ho.id}/reminders', {'kind': 'Fertilizing', 'at': at.toUtc().toIso8601String(), 'repeat': 'Weekly', 'interval': 2, 'note': 'Phân tan chậm'});
      final sen = app.plants!.firstWhere((p) => p.name.startsWith('Sen đá'));
      await app.api.post('me/garden/plants/${sen.id}/reminders', {'kind': 'Watering', 'at': at.add(const Duration(days: 1, hours: 1)).toUtc().toIso8601String(), 'repeat': 'Weekly', 'interval': 1});
      await app.syncGarden();
    });
    await settle(t, 1000);
    await shot(t, '11-chi-tiet-co-nhac', 'Lời nhắc của cây', 'Bấm vào lời nhắc để sửa, giữ lâu để xóa, gạt công tắc để tạm tắt.', [
      (find.textContaining('Tưới nước · Mỗi ngày'), 'Lời nhắc và lần nhắc tới'),
      (find.byType(Switch).first, 'Bật/tắt lời nhắc'),
    ]);
    navigatorKey.currentState!.pop();
    await settle(t);
    await shot(t, '06-vuon', 'Hồ sơ vườn', 'Danh sách cây đồng bộ với web. Ảnh đại diện lấy từ ảnh chụp trên máy, chưa có thì dùng ảnh minh họa của loài.', [
      (find.text('Trầu bà góc phòng khách'), 'Bấm để xem chi tiết cây'),
      (find.textContaining('Nhắc tiếp').first, 'Lần nhắc gần nhất của cây'),
      (find.textContaining('lời nhắc'), 'Tổng số lời nhắc đang bật'),
      (find.byType(FloatingActionButton), 'Thêm cây mới'),
    ]);

    // ---------- Nhắc tưới ----------
    await t.tap(nav('Nhắc tưới'));
    await waitFor(t, find.text('Báo thức trên điện thoại'));
    await shot(t, '12-nhac-tuoi', 'Nhắc tưới', 'Lịch 7 ngày tới của cả vườn. Chuông kêu lặp tới khi bấm "Đã tưới" hoặc "Nhắc lại 10 phút" ngay trên thông báo.', [
      (find.byType(Switch).first, 'Bật/tắt báo thức trên điện thoại'),
      (find.text('Thử chuông'), 'Nghe thử chuông nhắc'),
      (find.text('Đồng bộ'), 'Tải lại lịch từ máy chủ'),
      (find.byTooltip('Đánh dấu đã làm').first, 'Đánh dấu đã tưới'),
    ]);
    if (Platform.isAndroid) {
      // CI mở thanh thông báo và chụp màn hình hệ thống khi thấy dòng này.
      await t.runAsync(() => CareNotifications.instance.test());
      // ignore: avoid_print
      print('CX_SHADE_NOW');
      await t.runAsync(() => Future.delayed(const Duration(seconds: 12)));
    }

    // ---------- Cộng đồng ----------
    await t.tap(nav('Cộng đồng'));
    await waitFor(t, find.text('Trầu bà bị vàng lá phía dưới là do đâu?'));
    await shot(t, '13-cong-dong', 'Cộng đồng', 'Hỏi đáp, khoe cây, chia sẻ kinh nghiệm cùng người chơi cây (chung với web).', [
      (find.widgetWithText(ChoiceChip, 'Hỏi đáp'), 'Lọc theo loại bài'),
      (find.text('Trầu bà bị vàng lá phía dưới là do đâu?'), 'Bấm để đọc và bình luận'),
      (find.widgetWithText(FloatingActionButton, 'Đăng bài'), 'Viết bài mới'),
    ]);
    await t.tap(find.text('Khoe chậu sen đá mới trồng lại').first);
    await waitFor(t, find.textContaining('thích'));
    await t.enterText(find.widgetWithText(TextField, 'Viết bình luận…'), 'Đẹp quá, cho mình xin cách trộn đất với!');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(t, '14-bai-viet', 'Bài viết', 'Đọc bài, thích, bình luận.', [
      (find.textContaining('thích'), 'Thích bài viết'),
      (find.widgetWithText(TextField, 'Viết bình luận…'), 'Ô viết bình luận'),
      (find.byTooltip('Gửi'), 'Gửi bình luận'),
    ]);
    await t.tap(find.byTooltip('Gửi'));
    await waitFor(t, find.text('Đẹp quá, cho mình xin cách trộn đất với!'));
    navigatorKey.currentState!.pop();
    await settle(t);
    await t.tap(find.text('Đăng bài'));
    await waitFor(t, find.text('Đăng'));
    await t.enterText(field('Tiêu đề'), 'Lưỡi hổ bị mềm lá phải làm sao?');
    await t.enterText(field('Nội dung'), 'Cây để ban công, mấy hôm nay mưa nhiều, lá mềm và hơi vàng ở gốc.');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(t, '15-dang-bai', 'Đăng bài', 'Bài "Khoe cây" cần ít nhất 1 ảnh.', [
      (find.byType(SegmentedButton<String>), 'Chọn loại bài'),
      (field('Tiêu đề'), 'Tiêu đề (5–150 ký tự)'),
      (field('Nội dung'), 'Nội dung bài'),
      (find.text('Thêm ảnh'), 'Đính kèm ảnh'),
      (btn('Đăng'), 'Đăng bài'),
    ]);
    navigatorKey.currentState!.pop();
    await settle(t);

    // ---------- Khám phá ----------
    await t.tap(nav('Khám phá'));
    await waitFor(t, find.text('Bài hôm nay'));
    await shot(t, '16-kham-pha', 'Khám phá', 'Bài viết chăm cây do Chạm Xanh biên soạn, mới nhất ở trên cùng.', [
      (find.text('Bài hôm nay'), 'Bài mới nhất'),
      (find.byType(Card).at(1), 'Các bài khác: bấm để đọc'),
    ]);
    await t.tap(find.text('Bài hôm nay').first);
    await waitFor(t, find.textContaining('#'));
    await shot(t, '17-bai-kham-pha', 'Đọc bài Khám phá', 'Kéo xuống để đọc hết bài.', [
      (find.byType(AppBar), 'Quay lại danh sách'),
    ]);
    navigatorKey.currentState!.pop();
    await settle(t);

    // ---------- Tin nhắn realtime ----------
    String? conv;
    if (listingId.isNotEmpty) {
      conv = await t.runAsync(() async {
        final c = await app.api.post('conversations', {'listingId': listingId}) as Map<String, dynamic>;
        await app.api.post('conversations/${c['id']}/messages', {'type': 'Text', 'text': 'Chào anh, cây Monstera còn không ạ?'});
        await sellerSays(c['id'] as String, 'Còn bạn nhé, chậu 30cm, 6 lá rất khỏe.');
        return c['id'] as String;
      });
      await t.tap(nav('Vườn'));
      await settle(t, 1500);
      await shot(t, '18-tin-nhan-moi', 'Có tin nhắn mới', 'Số trên biểu tượng tin nhắn cập nhật ngay khi có tin mới (realtime).', [
        (find.byTooltip('Tin nhắn'), 'Tin nhắn chưa đọc'),
      ]);
      await t.tap(find.byTooltip('Tin nhắn'));
      await waitFor(t, find.text('Monstera lá xẻ chậu 30cm'));
      await waitFor(t, find.text('Trực tuyến'), seconds: 30);
      await shot(t, '19-danh-sach-chat', 'Tin nhắn', 'Các cuộc trò chuyện mua bán cây. Chấm xanh "Trực tuyến" = đang nhận tin tức thì.', [
        (find.text('Monstera lá xẻ chậu 30cm'), 'Mở cuộc trò chuyện'),
        (find.text('Trực tuyến'), 'Trạng thái kết nối realtime'),
      ]);
      await t.tap(find.text('Monstera lá xẻ chậu 30cm'));
      await waitFor(t, find.text('Còn bạn nhé, chậu 30cm, 6 lá rất khỏe.'));
      await t.enterText(find.widgetWithText(TextField, 'Nhắn tin…'), 'Mình lấy 1 chậu, giao Cần Thơ được không anh?');
      await t.tap(find.byTooltip('Gửi'));
      await waitFor(t, find.text('Mình lấy 1 chậu, giao Cần Thơ được không anh?'));
      // Người bán trả lời từ máy khác → tin hiện ngay qua SignalR, không cần tải lại.
      await t.runAsync(() => sellerSays(conv!, 'Được bạn, mai mình giao nhé!'));
      await waitFor(t, find.text('Được bạn, mai mình giao nhé!'), seconds: 20);
      FocusManager.instance.primaryFocus?.unfocus();
      await shot(t, '20-chat', 'Trò chuyện', 'Tin nhắn của bạn màu xanh bên phải; tin người kia hiện tức thì bên trái.', [
        (find.text('Được bạn, mai mình giao nhé!'), 'Tin vừa nhận (realtime)'),
        (find.widgetWithText(TextField, 'Nhắn tin…'), 'Ô soạn tin'),
        (find.byTooltip('Gửi'), 'Gửi tin'),
      ]);
      navigatorKey.currentState!.pop();
      await settle(t);
      navigatorKey.currentState!.pop();
      await settle(t);
    }

    // ---------- Tài khoản, nâng cấp gói ----------
    await t.tap(nav('Tài khoản'));
    await waitFor(t, find.text('Nâng cấp gói'));
    await shot(t, '21-tai-khoan', 'Tài khoản', 'Quản lý gói, tin nhắn, email nhận nhắc và báo thức.', [
      (find.text('Nâng cấp gói'), 'Xem và mua gói Xanh Plus / Xanh Pro'),
      (find.text('Tin nhắn').last, 'Tin nhắn'),
      (find.text('Email nhận nhắc lịch'), 'Đổi email nhận nhắc'),
      (find.byType(SwitchListTile), 'Bật/tắt báo thức trên máy'),
      (find.text('Mở Chạm Xanh trên web'), 'Mở web: chợ cây, trợ lý AI'),
      (find.text('Đăng xuất'), 'Đăng xuất'),
    ]);
    await t.tap(find.text('Nâng cấp gói'));
    await waitFor(t, find.text('Mua Xanh Plus'));
    await shot(t, '22-goi', 'Nâng cấp gói', 'So sánh quyền lợi các gói. Thanh toán bằng mã VietQR qua PayOS.', [
      (find.byType(SegmentedButton<int>), 'Chọn trả theo tháng hoặc năm'),
      (find.text('Mua Xanh Plus'), 'Mua gói Xanh Plus'),
    ]);
    await t.tap(find.text('Mua Xanh Plus'));
    await waitFor(t, find.text('Quét mã để thanh toán'));
    await settle(t, 1000);
    final simulate = find.textContaining('Xác nhận thanh toán thử');
    await shot(t, '23-thanh-toan', 'Quét mã thanh toán', 'Mở app ngân hàng → Quét QR. App tự kiểm tra mỗi 3 giây và kích hoạt gói ngay khi tiền về.', [
      (find.byType(QrImageView), 'Mã VietQR của đơn hàng'),
      (find.text('Lưu mã QR vào Ảnh'), 'Lưu QR vào Ảnh để quét từ app ngân hàng'),
      (find.textContaining('Đang chờ tiền về'), 'Trạng thái thanh toán'),
      if (simulate.evaluate().isNotEmpty) (simulate, 'Chỉ có khi máy chủ chạy thử: giả lập đã trả tiền'),
    ]);
    if (simulate.evaluate().isNotEmpty) {
      await t.ensureVisible(simulate);
      await t.tap(simulate);
      await waitFor(t, find.text('Thanh toán thành công 🎉'), seconds: 30);
      await shot(t, '24-thanh-cong', 'Thanh toán thành công', 'Gói được kích hoạt ngay, áp dụng cho cả app và web.', [
        (find.text('Gói đã được kích hoạt'), 'Gói đã kích hoạt'),
        (btn('Xong'), 'Quay lại'),
      ]);
      await t.tap(btn('Xong'));
      await settle(t);
    } else {
      navigatorKey.currentState!.pop();
    }
    navigatorKey.currentState!.pop();
    await settle(t);
    await t.tap(find.text('Đăng xuất'));
    await waitFor(t, find.text('Đăng xuất?'));
    await shot(t, '25-dang-xuat', 'Đăng xuất', 'Lịch nhắc trên máy sẽ tắt; ảnh cây vẫn giữ trên điện thoại.', [
      (find.widgetWithText(FilledButton, 'Đăng xuất'), 'Xác nhận đăng xuất'),
      (find.text('Hủy'), 'Ở lại'),
    ]);
    await t.tap(find.text('Hủy'));
    await settle(t);

    binding.reportData = {'shots': _shots};
  });
}
