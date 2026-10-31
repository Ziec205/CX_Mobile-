# Chạm Xanh Mobile

App Flutter (Android + iOS) cho Chạm Xanh, dùng chung tài khoản và dữ liệu với web.

- BE (.NET): https://github.com/Ziec205/CX_BE
- Web (Next.js): https://github.com/Ziec205/CX_FE
- Kế hoạch: [PLAN.md](PLAN.md)
- **Hướng dẫn sử dụng (PDF, ảnh chụp từ máy ảo Android, mũi tên đỏ chỉ từng nút):** [docs/Huong-dan-app-Cham-Xanh.pdf](docs/Huong-dan-app-Cham-Xanh.pdf)

## Tính năng

| Tab | Nội dung |
| --- | --- |
| **Vườn** | Hồ sơ vườn: thêm/sửa/xóa cây (đồng bộ với web). Ảnh cây **chỉ lưu trên máy** trong thư mục `Chạm Xanh/<tên cây>` của app và album **Chạm Xanh** trong Ảnh/Thư viện; máy chủ chỉ giữ dữ liệu cây. |
| **Nhắc tưới** | Lịch 7 ngày tới. Báo thức trên máy (`flutter_local_notifications`): ưu tiên cao, chuông kiểu báo thức kêu lặp, hai nút **Đã tưới** / **Nhắc lại 10 phút**. Lịch được dựng lại từ `careReminders` của BE mỗi lần mở app, quay lại app hoặc sửa lời nhắc. Cách tính lặp lại giống hệt BE (`ReminderSchedule`). |
| **Cộng đồng** | Hỏi đáp, khoe cây, kinh nghiệm: đọc, thích, bình luận, đăng bài. |
| **Khám phá** | Bài viết từ `/api/explore`. |
| **Tài khoản** | Nâng cấp gói, tin nhắn, email nhận nhắc, bật/tắt báo thức, đăng xuất. |
| Tin nhắn | Chat realtime qua SignalR (`/hubs/chat`, token từ `POST /api/auth/hub-token`, sự kiện `message`/`notification`). |
| Nâng cấp gói | BE tạo đơn PayOS, app hiện **mã VietQR** ngay trong app (lưu được vào Ảnh để quét bằng app ngân hàng) và tự kiểm tra trạng thái mỗi 3 giây. |

Đăng nhập/đăng ký bằng tên đăng nhập + mật khẩu (tài khoản thành viên).

## Chạy

```bash
flutter pub get
flutter run                                    # API mặc định https://chamxanh-api.onrender.com
flutter run --dart-define=API_BASE=http://10.0.2.2:5080   # BE chạy trên máy (Android emulator)
```

Biến build: `API_BASE` (địa chỉ BE), `WEB_BASE` (địa chỉ web, dùng làm nơi quay về của PayOS).

Lần gọi đầu có thể mất ~50 giây khi Render (gói miễn phí) đang ngủ; app chờ tới 75 giây.

## Kiểm tra

```bash
flutter analyze
flutter test
```

Kiểm thử đầu-cuối trên máy ảo Android với BE thật + tạo PDF hướng dẫn có mũi tên đỏ: xem [tool/e2e/README.md](tool/e2e/README.md) (workflow `e2e-android.yml`).

GitHub Actions (`.github/workflows/build.yml`): analyze + test → APK Android (artifact `cham-xanh-android-apk`) và bản iOS chưa ký trên macOS (artifact `cham-xanh-ios-unsigned`). Chạy tay được với `API_BASE` khác (Actions → Build → Run workflow).

## Cấu trúc

```
lib/
  api/            ApiClient (token, tự làm mới khi 401), models
  services/       notifications (báo thức), reminder_schedule (giống BE), photo_store (ảnh trên máy), realtime (SignalR), push (chỗ gắn FCM)
  state/          AppState: phiên đăng nhập, vườn, chat
  screens/        các màn hình
  widgets/        thành phần dùng chung
  theme.dart      màu từ web globals.css (emerald/stone/wood/water), font Be Vietnam Pro + Bricolage Grotesque (đóng gói, OFL)
```

## Thông báo đẩy (chưa có Firebase)

`lib/services/push.dart` có `PushProvider` (hiện là `NoPushProvider`). Khi thêm FCM: tạo provider dùng `firebase_messaging`, thêm `google-services.json` / `GoogleService-Info.plist` (không commit), BE đã có `POST /api/me/notifications/devices`.

## Ghi chú nền tảng

- Android: cần quyền thông báo (Android 13+) và "Báo thức & lời nhắc" (Android 12+) để kêu đúng giờ; app tự xin khi vào lần đầu. Thiếu quyền hẹn giờ chính xác thì vẫn nhắc nhưng có thể trễ vài phút.
- iOS: giữ tối đa 64 thông báo chờ, app đặt 56 lần nhắc gần nhất (21 ngày) và đặt lại mỗi lần mở app. Âm thanh dùng chuông thông báo mặc định (iOS không cho app thường phát chuông báo thức hệ thống).
- Bản release Android tạm ký bằng khóa debug; cần tạo khóa ký riêng trước khi lên Play Store.
