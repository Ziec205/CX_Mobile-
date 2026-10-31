# Kiểm thử đầu-cuối + tài liệu hướng dẫn

`integration_test/app_flow_test.dart` mở app thật, nối BE thật, đi qua mọi màn hình (đăng ký, hồ sơ vườn, ảnh cây,
nhắc tưới, cộng đồng, khám phá, chat realtime, nâng cấp gói bằng QR, đăng xuất), chụp màn hình và ghi vị trí các nút.
`build_pdf.py` vẽ khung + mũi tên đỏ đánh số vào từng nút và ghép thành PDF hướng dẫn.

**Trên máy ảo Android (GitHub Actions):** Actions → *E2E Android (máy ảo)* → Run workflow. Kết quả (ảnh + PDF) ở artifact
`e2e-android-anh-chup-va-pdf`.

**Trên máy:**

```bash
# BE chạy ở :5080 (Development, PayOS__AllowSimulator=true), MongoDB replica set
python3 tool/e2e/make_plants.py /tmp/img
python3 tool/e2e/seed.py http://localhost:5080 http://10.0.2.2:5080 /tmp/img > /tmp/seed.json   # 10.0.2.2 = máy chủ nhìn từ emulator
SHOTS_DIR=build/shots flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_flow_test.dart \
  --dart-define=API_BASE=http://10.0.2.2:5080 --dart-define=LISTING_ID=... --dart-define=SELLER_TOKEN=...
python3 tool/e2e/build_pdf.py build/shots build/Huong-dan.pdf assets/fonts ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
```

BE giới hạn 3 tài khoản mới/giờ cho mỗi IP: seed tạo 2, test tạo 1.
