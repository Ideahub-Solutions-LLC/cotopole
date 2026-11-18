import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Stores captured photos inside the app's private documents directory.
///
/// Paths are persisted **relative** to that directory. On iOS the absolute
/// sandbox path changes on every app update/reinstall, so storing absolute
/// paths in SQLite would orphan every photo after an update.
class ImageStore {
  ImageStore(this.rootDir);

  /// The app documents directory (from path_provider).
  final String rootDir;

  static const _folder = 'captures';

  /// Copies [sourcePath] into app storage and returns its relative path.
  Future<String> importFile(String sourcePath, {required String kind}) async {
    final dir = Directory(p.join(rootDir, _folder));
    if (!dir.existsSync()) await dir.create(recursive: true);
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath).toLowerCase();
    final name = '${kind}_${const Uuid().v4()}$ext';
    final rel = p.join(_folder, name);
    await File(sourcePath).copy(p.join(rootDir, rel));
    return rel;
  }

  File? resolve(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    final f = File(p.join(rootDir, relativePath));
    return f.existsSync() ? f : null;
  }

  Future<void> delete(String? relativePath) async {
    final f = resolve(relativePath);
    if (f != null) {
      try {
        await f.delete();
      } on FileSystemException {
        // Best effort — a missing file is already the desired end state.
      }
    }
  }

  Future<int> totalBytes() async {
    final dir = Directory(p.join(rootDir, _folder));
    if (!dir.existsSync()) return 0;
    var total = 0;
    await for (final e in dir.list()) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  Future<void> deleteAll() async {
    final dir = Directory(p.join(rootDir, _folder));
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
