/// Cấu hình build: đổi bằng --dart-define, ví dụ
/// `flutter run --dart-define=API_BASE=http://10.0.2.2:5080`.
class AppConfig {
  static const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://cx-be.onrender.com');
  static const webBase = String.fromEnvironment('WEB_BASE', defaultValue: 'https://cx-fe-web.vercel.app');

  /// Tên thư mục trong máy và album ảnh chứa ảnh cây.
  static const photoAlbum = 'Chạm Xanh';
}
