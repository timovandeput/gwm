import 'dart:io';

import 'package:glob/glob.dart';

import 'file_system_adapter.dart';

/// Production implementation of FileSystemAdapter using Dart's io library.
class FileSystemAdapterImpl implements FileSystemAdapter {
  @override
  bool fileExists(String path) {
    return File(path).existsSync();
  }

  @override
  bool directoryExists(String path) {
    return Directory(path).existsSync();
  }

  @override
  Future<void> createDirectory(String path) async {
    await Directory(path).create(recursive: true);
  }

  @override
  Future<void> copyFile(String source, String destination) async {
    await File(source).copy(destination);
  }

  @override
  Future<void> copyDirectory(String source, String destination) async {
    // Simple recursive copy
    final sourceDir = Directory(source);
    final destDir = Directory(destination);

    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    await for (final entity in sourceDir.list(recursive: true)) {
      final relativePath = entity.path.substring(source.length + 1);
      final destPath = '${destDir.path}/$relativePath';

      if (entity is File) {
        await entity.copy(destPath);
      } else if (entity is Directory) {
        await Directory(destPath).create(recursive: true);
      }
    }
  }

  @override
  List<String> listContents(String directory, {String? pattern}) {
    final dir = Directory(directory);
    if (!dir.existsSync()) return [];

    final entities = dir.listSync(recursive: true);
    final result = <String>[];

    Glob? glob;
    if (pattern != null) {
      glob = Glob(pattern);
    }

    for (final entity in entities) {
      final relativePath = entity.path.substring(directory.length + 1);
      if (pattern == null || glob!.matches(relativePath)) {
        result.add(relativePath);
      }
    }

    return result;
  }

  @override
  Future<String> readFile(String path) async {
    return await File(path).readAsString();
  }

  @override
  Future<void> writeFile(String path, String content) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  @override
  Future<void> deleteFile(String path) async {
    await File(path).delete();
  }

  @override
  Future<void> deleteDirectory(String path) async {
    await Directory(path).delete(recursive: true);
  }

  @override
  Future<DateTime> getLastModified(String path) async {
    return await File(path).lastModified();
  }

  @override
  Future<int> getFileSize(String path) async {
    return await File(path).length();
  }
}
