import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Ảnh cây chỉ nằm trên điện thoại (giống Zalo): thư mục của app `Chạm Xanh/<tên cây>`
/// và một bản trong album "Chạm Xanh" của Ảnh/Thư viện. Máy chủ chỉ giữ dữ liệu cây.
class PhotoStore {
  PhotoStore({Future<Directory> Function()? root, this.saveToGallery = _saveToGallery}) : _root = root ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _root;
  final Future<bool> Function(String path) saveToGallery;

  static Future<bool> _saveToGallery(String path) async {
    try {
      if (!await Gal.hasAccess(toAlbum: true) && !await Gal.requestAccess(toAlbum: true)) return false;
      await Gal.putImage(path, album: AppConfig.photoAlbum);
      return true;
    } catch (e) {
      debugPrint('Không lưu được vào album: $e');
      return false;
    }
  }

  /// Bỏ ký tự không hợp lệ trong tên thư mục, giữ dấu tiếng Việt.
  static String safeName(String name) {
    final s = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final cut = s.length > 60 ? s.substring(0, 60).trim() : s;
    return cut.isEmpty ? 'Cây' : cut;
  }

  /// Thư mục của một cây. Tên đặt theo tên cây lúc lưu ảnh đầu tiên và được ghi nhớ theo id,
  /// nên đổi tên cây trên web không làm mất ảnh.
  Future<Directory> plantDir(String plantId, String plantName, {bool create = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'photoDir.$plantId';
    var folder = prefs.getString(key);
    final base = Directory(p.join((await _root()).path, AppConfig.photoAlbum));
    if (folder == null) {
      folder = safeName(plantName);
      // Hai cây trùng tên: thêm đuôi id cho thư mục thứ hai.
      if (await Directory(p.join(base.path, folder)).exists()) folder = '$folder (${plantId.substring(plantId.length - 4)})';
      if (create) await prefs.setString(key, folder);
    }
    final dir = Directory(p.join(base.path, folder));
    if (create && !await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<File>> list(String plantId, String plantName) async {
    final dir = await plantDir(plantId, plantName, create: false);
    if (!await dir.exists()) return [];
    final files = await dir.list().where((e) => e is File && _isImage(e.path)).cast<File>().toList();
    files.sort((a, b) => b.path.compareTo(a.path)); // tên theo thời gian: mới nhất trước
    return files;
  }

  static bool _isImage(String path) => const {'.jpg', '.jpeg', '.png', '.heic', '.webp'}.contains(p.extension(path).toLowerCase());

  /// Chép ảnh vừa chụp/chọn vào thư mục cây, rồi lưu thêm một bản vào album Ảnh.
  Future<(File, bool)> add(String plantId, String plantName, String sourcePath) async {
    final dir = await plantDir(plantId, plantName);
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}_${now.millisecond}';
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath).toLowerCase();
    final file = await File(sourcePath).copy(p.join(dir.path, 'CX_$stamp$ext'));
    final inGallery = await saveToGallery(file.path);
    return (file, inGallery);
  }

  Future<void> remove(File f) async {
    if (await f.exists()) await f.delete();
  }

  /// Xóa cả thư mục ảnh của cây (ảnh trong album Ảnh vẫn giữ để người dùng tự quyết).
  Future<void> removePlant(String plantId, String plantName) async {
    final dir = await plantDir(plantId, plantName, create: false);
    if (await dir.exists()) await dir.delete(recursive: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('photoDir.$plantId');
  }
}
