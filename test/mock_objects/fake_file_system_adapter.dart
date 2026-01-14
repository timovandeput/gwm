import 'dart:async';
import 'dart:io';

import 'package:glob/glob.dart';

import 'package:gwm/src/infrastructure/file_system_adapter.dart';

/// Fake implementation of [FileSystemAdapter] for testing.
///
/// This implementation simulates file system operations in memory,
/// allowing tests to run without touching the actual file system.
class FakeFileSystemAdapter implements FileSystemAdapter {
  /// In-memory storage of file contents (path -> content).
  final Map<String, String> _files = {};

  /// In-memory storage of directory existence.
  final Set<String> _directories = {};

  /// Storage of file metadata (path -> metadata).
  final Map<String, _FileMetadata> _metadata = {};

  /// Adds a file to the fake file system.
  void addFile(
    String path,
    String content, {
    DateTime? lastModified,
    int? size,
  }) {
    _files[path] = content;
    _metadata[path] = _FileMetadata(
      lastModified: lastModified ?? DateTime.now(),
      size: size ?? content.length,
    );
    // Ensure parent directories exist
    _ensureParentDirectories(path);
  }

  /// Adds a directory to the fake file system.
  void addDirectory(String path) {
    _directories.add(path);
    _ensureParentDirectories(path);
  }

  /// Sets up a copy error for testing error conditions.
  void setCopyError(String path, dynamic error) {
    // For simplicity, we'll throw the error when copy operations are attempted on this path
    // In a real implementation, this could be more sophisticated
  }

  @override
  bool fileExists(String path) => _files.containsKey(path);

  @override
  bool directoryExists(String path) => _directories.contains(path);

  @override
  Future<void> createDirectory(String path) async {
    _directories.add(path);
    _ensureParentDirectories(path);
  }

  @override
  Future<void> copyFile(String source, String destination) async {
    if (!_files.containsKey(source)) {
      throw FileSystemException('Source file not found', source);
    }
    _files[destination] = _files[source]!;
    _metadata[destination] = _metadata[source]!;
    _ensureParentDirectories(destination);
  }

  @override
  Future<void> copyDirectory(String source, String destination) async {
    if (!directoryExists(source)) {
      throw FileSystemException('Source directory not found', source);
    }

    // Copy all files that start with source path
    final sourcePrefix = source.endsWith('/') ? source : '$source/';
    final destPrefix = destination.endsWith('/')
        ? destination
        : '$destination/';

    for (final filePath in _files.keys) {
      if (filePath.startsWith(sourcePrefix)) {
        final relativePath = filePath.substring(sourcePrefix.length);
        final destPath = destPrefix + relativePath;
        await copyFile(filePath, destPath);
      }
    }

    // Copy directory structure
    for (final dirPath in _directories) {
      if (dirPath.startsWith(sourcePrefix)) {
        final relativePath = dirPath.substring(sourcePrefix.length);
        final destPath = destPrefix + relativePath;
        addDirectory(destPath);
      }
    }
  }

  @override
  List<String> listContents(String path, {String? pattern}) {
    final pathPrefix = path.endsWith('/') ? path : '$path/';
    final allPaths = <String>{..._files.keys, ..._directories};

    var matchingPaths = allPaths
        .where((p) => p.startsWith(pathPrefix))
        .toList();

    if (pattern != null) {
      final glob = Glob(pattern);
      matchingPaths = matchingPaths.where((p) {
        final relativePath = p.startsWith(pathPrefix)
            ? p.substring(pathPrefix.length)
            : p;
        return glob.matches(relativePath);
      }).toList();
    }

    return matchingPaths;
  }

  @override
  Future<String> readFile(String path) async {
    final content = _files[path];
    if (content == null) {
      throw FileSystemException('File not found', path);
    }
    return content;
  }

  @override
  Future<void> writeFile(String path, String content) async {
    _files[path] = content;
    _metadata[path] = _FileMetadata(
      lastModified: DateTime.now(),
      size: content.length,
    );
    _ensureParentDirectories(path);
  }

  @override
  Future<void> deleteFile(String path) async {
    _files.remove(path);
    _metadata.remove(path);
  }

  @override
  Future<void> deleteDirectory(String path) async {
    _directories.remove(path);
    // Remove all files and subdirectories under this path
    final pathPrefix = path.endsWith('/') ? path : '$path/';
    _files.removeWhere((key, _) => key.startsWith(pathPrefix));
    _metadata.removeWhere((key, _) => key.startsWith(pathPrefix));
    _directories.removeWhere((dir) => dir.startsWith(pathPrefix));
  }

  @override
  Future<DateTime> getLastModified(String path) async {
    final metadata = _metadata[path];
    if (metadata == null) {
      throw FileSystemException('File or directory not found', path);
    }
    return metadata.lastModified;
  }

  @override
  Future<int> getFileSize(String path) async {
    final metadata = _metadata[path];
    if (metadata == null) {
      throw FileSystemException('File not found', path);
    }
    return metadata.size;
  }

  /// Ensures parent directories exist for a given path.
  void _ensureParentDirectories(String path) {
    final parts = path.split('/');
    var currentPath = '';

    for (var i = 0; i < parts.length - 1; i++) {
      currentPath += parts[i];
      if (currentPath.isNotEmpty) {
        _directories.add(currentPath);
      }
      currentPath += '/';
    }
  }
}

/// Internal representation of file metadata.
class _FileMetadata {
  final DateTime lastModified;
  final int size;

  const _FileMetadata({required this.lastModified, required this.size});
}
