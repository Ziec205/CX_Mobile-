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
import 'package:cham_xanh/screens/account_screen.dart';
import 'package:cham_xanh/screens/explore_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
/// Nút chính (gồm cả FilledButton.icon, là lớp con của FilledButton).
Finder btn(String text) => find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is FilledButton));
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

const webSync = bool.fromEnvironment('WEB_SYNC');
const webSyncFile = String.fromEnvironment('WEB_SYNC_FILE', defaultValue: '/tmp/cx_web_sync_done');

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Đi qua toàn bộ app với BE thật', (t) async {
    final desktop = Platform.isLinux || Platform.isMacOS || Platform.isWindows;
    if (desktop) {
      // Chạy trên desktop: giả lập màn hình điện thoại 6.4" (411×891 dp).
      t.view.physicalSize = const Size(1080, 2340);
      t.view.devicePixelRatio = 2.625;
    }
    await initializeDateFormatting('vi');
    SharedPreferences.setMockInitialValues({}); // như cài app lần đầu
    await CareNotifications.instance.init();
    final photoRoot = desktop ? await Directory.systemTemp.createTemp('cx_e2e') : null;
    final app = AppState(
      api: ApiClient(store: MemoryTokenStore(), baseUrl: apiBase),
      // Desktop không có album Ảnh: lưu vào thư mục tạm. Trên máy ảo Android dùng thư mục + album thật.
      photos: desktop ? PhotoStore(root: () async => photoRoot!, saveToGallery: (_) async => false) : null,
    );
    await t.pumpWidget(ChangeNotifierProvider.value(value: app, child: RepaintBoundary(key: _boundary, child: const ChamXanhApp())));
    await t.runAsync(app.bootstrap);

    // ---------- Giới thiệu lần đầu ----------
    await waitFor(t, find.text('Chăm vườn nhẹ nhàng'));
    await shot(t, '00a-gioi-thieu', 'Giới thiệu (lần đầu mở app)', 'Ba trang ngắn nói rõ app giúp gì trước khi hỏi tài khoản. Vuốt ngang hoặc bấm “Tiếp tục”.', [
      (find.text('Chăm vườn nhẹ nhàng'), 'Lợi ích chính của app'),
      (btn('Tiếp tục'), 'Sang trang tiếp'),
      (find.text('Bỏ qua'), 'Bỏ qua phần giới thiệu'),
    ]);
    await t.tap(btn('Tiếp tục'));
    await settle(t, 800);
    await t.tap(btn('Tiếp tục'));
    await waitFor(t, btn('Bắt đầu thôi'));
    await shot(t, '00b-gioi-thieu', 'Giới thiệu: cộng đồng', 'Trang cuối. Bấm “Bắt đầu thôi” để đăng nhập hoặc tạo tài khoản.', [
      (find.text('Có bạn cùng chơi cây'), 'Hỏi đáp, khoe cây, nhắn tin mua bán'),
      (btn('Bắt đầu thôi'), 'Vào đăng nhập'),
    ]);
    await t.tap(btn('Bắt đầu thôi'));
    await waitFor(t, find.widgetWithText(FilledButton, 'Đăng nhập'));

    // ---------- Đăng nhập / đăng ký ----------
    await shot(t, '01-dang-nhap', 'Đăng nhập', 'Dùng chung tài khoản với web Chạm Xanh (tên đăng nhập + mật khẩu).', [
      (field('Tên đăng nhập'), 'Nhập tên đăng nhập'),
      (field('Mật khẩu'), 'Nhập mật khẩu (bấm biểu tượng mắt để hiện/ẩn)'),
      (btn('Đăng nhập'), 'Đăng nhập vào app'),
      (find.text('Đăng ký ngay'), 'Chuyển sang tạo tài khoản mới'),
    ]);
    await t.tap(find.text('Đăng ký ngay'));
    await settle(t);
    final user = 'vuon.${DateTime.now().millisecondsSinceEpoch % 1000000}';
    const pass = 'matkhau123';
    await t.enterText(field('Tên đăng nhập'), user);
    await t.enterText(field('Mật khẩu'), pass);
    await t.enterText(field('Nhập lại mật khẩu'), pass);
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(t, '02-dang-ky', 'Tạo tài khoản', 'Tên đăng nhập 4–30 ký tự (chữ không dấu, số, dấu chấm, gạch dưới), mật khẩu tối thiểu 8 ký tự.', [
      (field('Tên đăng nhập'), 'Tên đăng nhập mới'),
      (field('Nhập lại mật khẩu'), 'Nhập lại mật khẩu để xác nhận'),
      (btn('Tạo tài khoản'), 'Tạo tài khoản và vào app'),
    ]);
    await t.tap(btn('Tạo tài khoản'));

    // ---------- Xin quyền thông báo (giải thích trước) ----------
    await waitFor(t, find.text('Để Chạm Xanh nhắc bạn tưới cây nhé?'));
    await shot(t, '03-xin-quyen', 'Cho phép nhắc tưới', 'App giải thích vì sao cần thông báo trước khi điện thoại hỏi quyền.', [
      (btn('Cho phép nhắc'), 'Đồng ý để chuông nhắc tưới kêu đúng giờ'),
      (find.text('Để sau'), 'Hỏi lại sau'),
    ]);
    await t.tap(btn('Cho phép nhắc'));
    await waitFor(t, find.text('Bắt đầu với cây đầu tiên'));
    await shot(t, '04-hom-nay-trong', 'Hôm nay (lần đầu)', 'Trang chủ cho biết hôm nay vườn cần gì. Lần đầu, app gợi ý thêm cây đầu tiên.', [
      (find.byType(AccountAction).first, 'Tài khoản, nâng cấp gói'),
      (btn('Thêm cây đầu tiên'), 'Thêm cây đầu tiên'),
      (find.text('Lối tắt'), 'Lối tắt: thêm cây, lịch nhắc, hỏi cộng đồng'),
      (navTab('Hôm nay'), 'Việc cần làm hôm nay'),
      (navTab('Vườn'), 'Tất cả cây của bạn'),
      (navTab('Cộng đồng'), 'Hỏi đáp, khoe cây'),
      (navTab('Khám phá'), 'Bài viết chăm cây'),
      (navTab('Tin nhắn'), 'Tin nhắn (số đỏ = tin chưa đọc)'),
    ]);

    // ---------- Thêm cây ----------
    await t.tap(btn('Thêm cây đầu tiên'));
    await waitFor(t, field('Tên gọi *'));
    await t.enterText(field('Tên gọi *'), 'Trầu bà góc phòng khách');
    await t.enterText(field('Vị trí đặt'), 'Phòng khách');
    await t.tap(find.text('Chọn loài'));
    await waitFor(t, find.byType(ListTile));
    await t.enterText(find.widgetWithText(TextField, 'Tìm loài: trầu bà, lưỡi hổ…'), 'trau');
    await waitFor(t, find.widgetWithText(ListTile, 'Trầu bà'));
    await shot(t, '06-chon-loai', 'Chọn loài cây', 'Gõ tên (có dấu hoặc không dấu) để tìm trong danh mục loài của Chạm Xanh.', [
      (find.widgetWithText(TextField, 'trau'), 'Ô tìm loài'),
      (find.widgetWithText(ListTile, 'Trầu bà'), 'Bấm để chọn loài'),
    ]);
    await t.tap(find.widgetWithText(ListTile, 'Trầu bà'));
    await settle(t);
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(t, '05-them-cay', 'Thêm cây', 'Chỉ cần đặt tên là đủ. Dữ liệu cây đồng bộ với web; ảnh cây chỉ lưu trên điện thoại.', [
      (field('Tên gọi *'), 'Tên gọi của cây (bắt buộc)'),
      (find.text('Trầu bà'), 'Loài cây: chọn để có ảnh minh họa'),
      (field('Vị trí đặt'), 'Vị trí đặt cây'),
      (find.text('Chưa chọn'), 'Ngày bắt đầu trồng'),
      (btn('Lưu'), 'Lưu cây'),
    ]);
    await t.tap(btn('Lưu'));
    await settle(t, 1500);
    // Thêm 1 cây nữa và lịch hôm nay qua API để trang Hôm nay có việc.
    final local = DateTime.now();
    final early = DateTime(local.year, local.month, local.day, 0, 5); // đã qua giờ → "Đến giờ rồi"
    final late = DateTime(local.year, local.month, local.day, 23, 50);
    await t.runAsync(() async {
      final ho = await app.api.post('me/garden/plants', {'name': 'Lưỡi hổ ban công', 'speciesId': 'luoi-ho', 'location': 'Ban công'}) as Map<String, dynamic>;
      await app.api.put('me', {'email': '$user@example.com'});
      await app.api.post('me/garden/plants/${ho['id']}/reminders', {'kind': 'Watering', 'at': early.toUtc().toIso8601String(), 'repeat': 'Daily', 'interval': 1, 'note': 'Tưới ít, đất khô hẳn mới tưới'});
      await app.syncGarden();
      final tb = app.plants!.firstWhere((p) => p.name.startsWith('Trầu bà'));
      await app.api.post('me/garden/plants/${tb.id}/reminders', {'kind': 'Fertilizing', 'at': late.toUtc().toIso8601String(), 'repeat': 'Weekly', 'interval': 2, 'note': 'Phân tan chậm'});
      await app.refreshMe();
    });
    final trauBa = app.plants!.firstWhere((p) => p.name.startsWith('Trầu bà'));
    final p1 = await demoPhoto(t, 'trau-ba-1', const Color(0xFFC4704A), 1);
    final p2 = await demoPhoto(t, 'trau-ba-2', const Color(0xFF10361E), 7);
    await t.runAsync(() async {
      await app.photos.add(trauBa.id, trauBa.name, p1);
      await app.photos.add(trauBa.id, trauBa.name, p2);
      await app.syncGarden();
    });

    // ---------- Vườn ----------
    await t.tap(nav('Vườn'));
    await waitFor(t, find.text('Lưỡi hổ ban công'));
    await settle(t, 1500);
    await shot(t, '07-vuon', 'Vườn của tôi', 'Mỗi cây một thẻ ảnh lớn. Nhãn màu cho biết cây nào cần chăm hôm nay.', [
      (find.text('Trầu bà góc phòng khách'), 'Bấm để xem chi tiết cây'),
      (find.text('Cần tưới hôm nay'), 'Cây cần tưới hôm nay'),
      (find.textContaining('lời nhắc'), 'Tổng số lời nhắc đang bật'),
      (find.byType(FloatingActionButton), 'Thêm cây mới'),
    ]);

    // ---------- Chi tiết cây, ảnh, đặt nhắc ----------
    await t.tap(find.text('Trầu bà góc phòng khách'));
    await waitFor(t, find.text('Thêm ảnh'));
    await shot(t, '08-chi-tiet-cay', 'Chi tiết cây', 'Ảnh chụp lưu trong thư mục “Chạm Xanh/<tên cây>” của app và album “Chạm Xanh” trong Ảnh, không tải lên máy chủ.', [
      (find.text('Thêm ảnh'), 'Chụp hoặc chọn ảnh cây'),
      (find.byType(Hero).first, 'Ảnh đã lưu trên máy (bấm để xem lớn/xóa)'),
      (find.byTooltip('Sửa'), 'Sửa thông tin cây'),
      (find.byTooltip('Xóa cây'), 'Xóa cây'),
      (find.text('Đặt nhắc'), 'Đặt lời nhắc chăm cây'),
    ]);
    await t.tap(find.text('Thêm ảnh'));
    await waitFor(t, find.text('Chụp ảnh'));
    await shot(t, '09-them-anh', 'Thêm ảnh cây', 'Chọn nguồn ảnh. Ảnh được chép vào thư mục của cây và album “Chạm Xanh”.', [
      (find.text('Chụp ảnh'), 'Mở camera chụp ảnh mới'),
      (find.text('Chọn từ thư viện'), 'Chọn nhiều ảnh có sẵn'),
    ]);
    navigatorKey.currentState!.pop();
    await settle(t);
    await t.tap(find.text('Đặt nhắc'));
    await waitFor(t, find.text('Lưu lời nhắc'));
    await t.enterText(find.widgetWithText(TextField, 'Ghi chú (vd: tưới 200ml, tưới gốc)'), 'Tưới 200ml quanh gốc');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(t, '10-dat-nhac', 'Đặt lời nhắc', 'Đến giờ, điện thoại đổ chuông như báo thức. Lời nhắc đồng bộ với web.', [
      (find.widgetWithText(ChoiceChip, 'Tưới cây'), 'Chọn việc: tưới, bón phân, cắt tỉa…'),
      (find.byIcon(Icons.event_rounded), 'Chọn ngày bắt đầu'),
      (find.byIcon(Icons.schedule_rounded), 'Chọn giờ nhắc'),
      (find.byType(DropdownButtonFormField<ReminderRepeat>), 'Lặp lại theo ngày/tuần/tháng/năm'),
      (find.byIcon(Icons.add_rounded).last, 'Tăng/giảm chu kỳ (mỗi N ngày)'),
      (find.text('Lưu lời nhắc'), 'Lưu và hẹn chuông'),
    ]);
    await t.tap(find.text('Lưu lời nhắc'));
    await waitFor(t, find.textContaining('Tưới cây · Mỗi ngày'));
    await settle(t, 800);
    await shot(t, '11-chi-tiet-co-nhac', 'Lời nhắc của cây', 'Bấm vào lời nhắc để sửa, giữ lâu để xóa, gạt công tắc để tạm tắt.', [
      (find.textContaining('Tưới cây · Mỗi ngày'), 'Lời nhắc và lần nhắc tới'),
      (find.byTooltip('Đã tưới').first, 'Bấm khi đã tưới (web cũng thấy)'),
      (find.byType(Switch).first, 'Bật/tắt lời nhắc'),
    ]);
    navigatorKey.currentState!.pop();
    await settle(t);

    // ---------- Hôm nay: bấm Đã tưới ----------
    await t.tap(nav('Hôm nay'));
    await waitFor(t, find.text('Việc hôm nay'));
    await settle(t, 1000);
    await shot(t, '12-hom-nay', 'Hôm nay', 'Danh sách việc trong ngày. Việc đã đến giờ có viền xanh nước và dòng “Đến giờ rồi bạn ơi”.', [
      (find.textContaining('Còn '), 'Tiến độ hôm nay'),
      (find.text('Đến giờ rồi bạn ơi'), 'Việc đã đến giờ'),
      (btn('Đã tưới').first, 'Bấm một chạm khi tưới xong'),
      (find.text('Lối tắt'), 'Lối tắt'),
    ]);
    await t.tap(btn('Đã tưới').first);
    await waitFor(t, find.byType(SnackBar));
    await settle(t, 600);
    await shot(t, '13-cam-on', 'Đã tưới xong', 'App cảm ơn bạn và đếm chuỗi ngày chăm cây. Bấm nhầm thì chọn “Hoàn tác”.', [
      (find.byType(SnackBar), 'Lời cảm ơn + chuỗi ngày chăm cây'),
      (find.text('Hoàn tác'), 'Hoàn tác nếu bấm nhầm'),
      (find.text('Xong').first, 'Việc đã xong'),
    ]);

    // ---------- Đồng bộ với web ----------
    if (webSync) {
      // Trình duyệt tự động đăng nhập web bằng cùng tài khoản, kiểm tra dữ liệu, bấm "Đã làm" và thêm cây.
      // ignore: avoid_print
      print('CX_WEB_SYNC $user $pass');
      final done = File(webSyncFile);
      await t.runAsync(() async {
        for (var i = 0; i < 240 && !done.existsSync(); i++) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      });
      if (!done.existsSync()) throw TestFailure('Bước kiểm tra web không xong');
    } else {
      // Không chạy web (máy ảo trên CI): mô phỏng thao tác web qua cùng API mà web dùng.
      await t.runAsync(() async {
        final tb = app.plants!.firstWhere((p) => p.name.startsWith('Trầu bà'));
        final r = tb.reminders.firstWhere((x) => x.kind == ReminderKind.fertilizing);
        await app.api.post('me/garden/plants/${tb.id}/reminders/${r.id}/done');
        await app.api.post('me/garden/plants', {'name': 'Hoa giấy cổng nhà', 'speciesId': 'hoa-giay', 'location': 'Cổng nhà'});
      });
    }
    await t.runAsync(app.syncGarden);
    await waitFor(t, find.text('Đã chăm xong cả vườn!'));
    ScaffoldMessenger.of(navigatorKey.currentContext!).hideCurrentSnackBar();
    await settle(t, 800);
    await shot(t, '14-dong-bo-web', 'Đồng bộ với web', 'Việc “Bón phân” vừa được bấm “Đã làm” trên web: app tự cập nhật khi mở lại hoặc kéo xuống để tải lại.', [
      (find.text('Đã chăm xong cả vườn!'), 'Cả vườn đã chăm xong hôm nay'),
      (find.textContaining('ngày chăm cây liên tiếp'), 'Chuỗi ngày chăm cây'),
      (find.text('Xong').last, 'Việc đã làm trên web'),
    ]);
    await t.tap(nav('Vườn'));
    await waitFor(t, find.text('Hoa giấy cổng nhà'));
    await settle(t, 1000);
    await shot(t, '15-vuon-dong-bo', 'Cây thêm từ web', 'Cây “Hoa giấy cổng nhà” được thêm trên web và hiện ngay trong app.', [
      (find.text('Hoa giấy cổng nhà'), 'Cây vừa thêm trên web'),
    ]);

    // ---------- Lịch nhắc 7 ngày ----------
    await t.tap(nav('Hôm nay'));
    await settle(t);
    await t.ensureVisible(find.text('Lịch nhắc\n7 ngày'));
    await t.tap(find.text('Lịch nhắc\n7 ngày'));
    await waitFor(t, find.text('Báo thức trên điện thoại'));
    await shot(t, '16-lich-nhac', 'Lịch nhắc 7 ngày', 'Lịch của cả vườn. Chuông kêu lặp tới khi bấm “Đã tưới” hoặc “Nhắc lại 10 phút” ngay trên thông báo.', [
      (find.byType(Switch).first, 'Bật/tắt báo thức trên điện thoại'),
      (find.text('Thử chuông'), 'Nghe thử chuông nhắc'),
      (find.text('Đồng bộ'), 'Tải lại lịch từ máy chủ'),
      (find.byTooltip('Đánh dấu đã làm').first, 'Đánh dấu đã làm'),
    ]);
    if (Platform.isAndroid) {
      // CI mở thanh thông báo và chụp màn hình hệ thống khi thấy dòng này.
      await t.runAsync(() => CareNotifications.instance.test());
      // ignore: avoid_print
      print('CX_SHADE_NOW');
      await t.runAsync(() => Future.delayed(const Duration(seconds: 12)));
    }
    navigatorKey.currentState!.pop();
    await settle(t);

    // ---------- Cộng đồng ----------
    await t.tap(nav('Cộng đồng'));
    await waitFor(t, find.text('Trầu bà bị vàng lá phía dưới là do đâu?'));
    await shot(t, '17-cong-dong', 'Cộng đồng', 'Hỏi đáp, khoe cây, chia sẻ kinh nghiệm cùng người chơi cây (chung với web).', [
      (find.widgetWithText(ChoiceChip, 'Hỏi đáp'), 'Lọc theo loại bài'),
      (find.text('Trầu bà bị vàng lá phía dưới là do đâu?'), 'Bấm để đọc và bình luận'),
      (find.widgetWithText(FloatingActionButton, 'Đăng bài'), 'Viết bài mới'),
    ]);
    await t.tap(find.text('Khoe chậu sen đá mới trồng lại').first);
    await waitFor(t, find.textContaining('thích'));
    await t.enterText(find.widgetWithText(TextField, 'Viết bình luận…'), 'Đẹp quá, cho mình xin cách trộn đất với!');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(t, '18-bai-viet', 'Bài viết', 'Đọc bài, thích, bình luận.', [
      (find.textContaining('thích'), 'Thích bài viết'),
      (find.widgetWithText(TextField, 'Viết bình luận…'), 'Ô viết bình luận'),
      (find.byTooltip('Gửi'), 'Gửi bình luận'),
    ]);
    await t.tap(find.byTooltip('Gửi'));
    await settle(t, 2000);
    // Ảnh bài cao có thể đẩy bình luận ra ngoài vùng đã dựng của danh sách.
    await t.drag(find.byType(ListView).last, const Offset(0, -900));
    await waitFor(t, find.text('Đẹp quá, cho mình xin cách trộn đất với!'));
    navigatorKey.currentState!.pop();
    await settle(t);
    await t.tap(find.text('Đăng bài'));
    await waitFor(t, find.text('Đăng'));
    await t.enterText(field('Tiêu đề'), 'Lưỡi hổ bị mềm lá phải làm sao?');
    await t.enterText(field('Nội dung'), 'Cây để ban công, mấy hôm nay mưa nhiều, lá mềm và hơi vàng ở gốc.');
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(t, '19-dang-bai', 'Đăng bài', 'Bài “Khoe cây” cần ít nhất 1 ảnh.', [
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
    await waitFor(t, find.byType(ExplorePlantCard));
    await shot(t, '20-kham-pha', 'Khám phá', 'Bài viết chăm cây do Chạm Xanh biên soạn, mới nhất ở trên cùng.', [
      (find.byType(ExplorePlantCard).first, 'Bài mới nhất: bấm để đọc'),
    ]);
    await t.tap(find.byType(ExplorePlantCard).first);
    await waitFor(t, find.textContaining('#'));
    await shot(t, '21-bai-kham-pha', 'Đọc bài Khám phá', 'Kéo xuống để đọc hết bài.', [
      (find.byType(BackButton), 'Quay lại danh sách'),
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
      await t.tap(nav('Hôm nay'));
      await settle(t, 1500);
      await shot(t, '22-tin-nhan-moi', 'Có tin nhắn mới', 'Số trên biểu tượng tin nhắn cập nhật ngay khi có tin mới (realtime).', [
        (navTab('Tin nhắn'), 'Tin nhắn chưa đọc'),
      ]);
      await t.tap(nav('Tin nhắn'));
      await waitFor(t, find.text('Monstera lá xẻ chậu 30cm'));
      await waitFor(t, find.text('Trực tuyến'), seconds: 30);
      await shot(t, '23-danh-sach-chat', 'Tin nhắn', 'Các cuộc trò chuyện mua bán cây. Chấm xanh “Trực tuyến” = đang nhận tin tức thì.', [
        (find.text('Monstera lá xẻ chậu 30cm'), 'Mở cuộc trò chuyện'),
        (find.text('Trực tuyến'), 'Trạng thái kết nối realtime'),
      ]);
      await t.tap(find.text('Monstera lá xẻ chậu 30cm'));
      await waitFor(t, find.text('Còn bạn nhé, chậu 30cm, 6 lá rất khỏe.'));
      await t.enterText(find.widgetWithText(TextField, 'Nhắn tin…'), 'Mình lấy 1 chậu, giao Cần Thơ được không anh?');
      await t.tap(find.byTooltip('Gửi'));
      await waitFor(t, find.text('Mình lấy 1 chậu, giao Cần Thơ được không anh?'));
      await t.runAsync(() => sellerSays(conv!, 'Được bạn, mai mình giao nhé!'));
      await waitFor(t, find.text('Được bạn, mai mình giao nhé!'), seconds: 20);
      FocusManager.instance.primaryFocus?.unfocus();
      await shot(t, '24-chat', 'Trò chuyện', 'Tin nhắn của bạn màu xanh bên phải; tin người kia hiện tức thì bên trái.', [
        (find.text('Được bạn, mai mình giao nhé!'), 'Tin vừa nhận (realtime)'),
        (find.widgetWithText(TextField, 'Nhắn tin…'), 'Ô soạn tin'),
        (find.byTooltip('Gửi'), 'Gửi tin'),
      ]);
      navigatorKey.currentState!.pop();
      await settle(t);
    }

    // ---------- Tài khoản, nâng cấp gói ----------
    await t.tap(find.byTooltip('Tài khoản').first);
    await waitFor(t, find.text('Nâng cấp gói'));
    await shot(t, '25-tai-khoan', 'Tài khoản', 'Quản lý gói, email nhận nhắc và báo thức.', [
      (find.text('Nâng cấp gói'), 'Xem và mua gói Xanh Plus / Xanh Pro'),
      (find.text('Email nhận nhắc lịch'), 'Đổi email nhận nhắc'),
      (find.byType(SwitchListTile), 'Bật/tắt báo thức trên máy'),
    ]);
    await t.tap(find.text('Nâng cấp gói'));
    await waitFor(t, find.text('Mua Xanh Plus'));
    await shot(t, '26-goi', 'Nâng cấp gói', 'So sánh quyền lợi các gói. Thanh toán bằng mã VietQR qua PayOS.', [
      (find.byType(SegmentedButton<int>), 'Chọn trả theo tháng hoặc năm'),
      (find.text('Mua Xanh Plus'), 'Mua gói Xanh Plus'),
    ]);
    await t.ensureVisible(find.text('Mua Xanh Plus'));
    await t.tap(find.text('Mua Xanh Plus'));
    await waitFor(t, find.text('Quét mã để thanh toán'));
    await settle(t, 1000);
    final simulate = find.textContaining('Xác nhận thanh toán thử');
    await shot(t, '27-thanh-toan', 'Quét mã thanh toán', 'Mở app ngân hàng → Quét QR. App tự kiểm tra mỗi 3 giây và kích hoạt gói ngay khi tiền về.', [
      (find.byType(QrImageView), 'Mã VietQR của đơn hàng'),
      (find.text('Lưu mã QR vào Ảnh'), 'Lưu QR vào Ảnh để quét từ app ngân hàng'),
      (find.textContaining('Đang chờ tiền về'), 'Trạng thái thanh toán'),
      if (simulate.evaluate().isNotEmpty) (simulate, 'Chỉ có khi máy chủ chạy thử: giả lập đã trả tiền'),
    ]);
    if (simulate.evaluate().isNotEmpty) {
      await t.ensureVisible(simulate);
      await t.tap(simulate);
      await waitFor(t, find.text('Thanh toán thành công 🎉'), seconds: 30);
      await shot(t, '28-thanh-cong', 'Thanh toán thành công', 'Gói được kích hoạt ngay, áp dụng cho cả app và web.', [
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
    await shot(t, '29-dang-xuat', 'Đăng xuất', 'Lịch nhắc trên máy sẽ tắt; ảnh cây vẫn giữ trên điện thoại.', [
      (find.widgetWithText(FilledButton, 'Đăng xuất'), 'Xác nhận đăng xuất'),
      (find.text('Hủy'), 'Ở lại'),
    ]);
    await t.tap(find.text('Hủy'));
    await settle(t);

    binding.reportData = {'shots': _shots, 'user': user};
  });
}
