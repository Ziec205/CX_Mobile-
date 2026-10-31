import 'dart:io';

import 'package:cham_xanh/services/photo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory root;
  late List<String> gallery;
  late PhotoStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('cx_photos');
    gallery = [];
    store = PhotoStore(root: () async => root, saveToGallery: (path) async {
      gallery.add(path);
      return true;
    });
  });

  tearDown(() => root.delete(recursive: true));

  test('tên thư mục an toàn, giữ dấu tiếng Việt', () {
    expect(PhotoStore.safeName('Trầu bà / ban công: góc *trái*'), 'Trầu bà ban công góc trái');
    expect(PhotoStore.safeName('   '), 'Cây');
  });

  test('lưu ảnh vào "Chạm Xanh/<tên cây>" và album, đổi tên cây không mất ảnh', () async {
    final src = File(p.join(root.path, 'src.jpg'))..writeAsBytesSync([1, 2, 3]);
    final (file, inGallery) = await store.add('abc123', 'Sen đá', src.path);
    expect(inGallery, isTrue);
    expect(file.path, startsWith(p.join(root.path, 'Chạm Xanh', 'Sen đá')));
    expect(gallery, [file.path]);
    // Cây đổi tên trên web: vẫn tìm thấy ảnh cũ theo id.
    expect((await store.list('abc123', 'Sen đá kim cương')).map((f) => f.path), [file.path]);
    await store.removePlant('abc123', 'Sen đá kim cương');
    expect(await store.list('abc123', 'Sen đá'), isEmpty);
  });

  test('hai cây trùng tên dùng hai thư mục khác nhau', () async {
    final src = File(p.join(root.path, 'src.jpg'))..writeAsBytesSync([1]);
    final (a, _) = await store.add('id-000001', 'Lưỡi hổ', src.path);
    final (b, _) = await store.add('id-000002', 'Lưỡi hổ', src.path);
    expect(p.dirname(a.path), isNot(p.dirname(b.path)));
    expect(p.basename(p.dirname(b.path)), 'Lưỡi hổ (0002)');
  });
}
