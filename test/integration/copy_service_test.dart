import 'package:test/test.dart';
import 'package:glob/glob.dart';

import 'package:gwm/src/services/copy_service.dart';
import 'package:gwm/src/models/config.dart';
import 'package:gwm/src/infrastructure/file_system_adapter.dart';

// Fake file system for testing
class FakeFileSystemAdapter implements FileSystemAdapter {
  final Map<String, dynamic> _files = {};
  final Map<String, dynamic> _directories = {};

  @override
  bool fileExists(String path) => _files.containsKey(path);

  @override
  bool directoryExists(String path) => _directories.containsKey(path);

  @override
  Future<void> createDirectory(String path) async {
    _directories[path] = true;
  }

  @override
  Future<void> copyFile(String source, String destination) async {
    if (_files.containsKey(source)) {
      _files[destination] = _files[source];
    }
  }

  @override
  Future<void> copyDirectory(String source, String destination) async {
    if (_directories.containsKey(source)) {
      _directories[destination] = _directories[source];
      // Copy all files in the directory
      final sourcePrefix = '$source/';
      final destPrefix = '$destination/';
      final filesToCopy = Map<String, dynamic>.fromEntries(
        _files.entries.where((entry) => entry.key.startsWith(sourcePrefix)),
      );
      for (final entry in filesToCopy.entries) {
        final relativePath = entry.key.substring(sourcePrefix.length);
        _files[destPrefix + relativePath] = entry.value;
      }
    }
  }

  @override
  List<String> listContents(String path, {String? pattern}) {
    final result = <String>[];
    final pathPrefix = path.endsWith('/') ? path : '$path/';

    if (pattern != null) {
      final glob = Glob(pattern);
      for (final filePath in _files.keys) {
        if (filePath.startsWith(pathPrefix)) {
          final relativePath = filePath.substring(pathPrefix.length);
          if (glob.matches(relativePath)) {
            result.add(relativePath);
          }
        }
      }
    }

    return result;
  }

  @override
  Future<String> readFile(String path) async => _files[path]?.toString() ?? '';

  @override
  Future<void> writeFile(String path, String content) async {
    _files[path] = content;
  }

  @override
  Future<void> deleteFile(String path) async {
    _files.remove(path);
  }

  @override
  Future<void> deleteDirectory(String path) async {
    _directories.remove(path);
    // Remove all files in the directory
    final prefix = '$path/';
    _files.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<DateTime> getLastModified(String path) async => DateTime.now();

  @override
  Future<int> getFileSize(String path) async =>
      _files[path]?.toString().length ?? 0;

  // Helper methods for setup
  void addFile(String path, String content) {
    _files[path] = content;
  }

  void addDirectory(String path) {
    _directories[path] = true;
  }
}

void main() {
  group('CopyService Integration', () {
    late CopyService copyService;
    late FakeFileSystemAdapter fakeFileSystem;

    setUp(() {
      fakeFileSystem = FakeFileSystemAdapter();
      copyService = CopyService(fakeFileSystem);
    });

    test('complete file copying workflow', () async {
      // Setup source files
      fakeFileSystem.addFile('/source/.env', 'KEY=value');
      fakeFileSystem.addFile('/source/.env.local', 'LOCAL_KEY=local_value');
      fakeFileSystem.addFile('/source/config/app.json', '{"name": "app"}');
      fakeFileSystem.addFile('/source/config/db.json', '{"db": "config"}');
      fakeFileSystem.addDirectory('/source/config');

      final config = CopyConfig(
        files: ['.env*', 'config/*.json'],
        directories: [],
      );

      await copyService.copyFiles(config, '/source', '/dest');

      // Verify files were copied
      expect(fakeFileSystem.fileExists('/dest/.env'), isTrue);
      expect(fakeFileSystem.fileExists('/dest/.env.local'), isTrue);
      expect(fakeFileSystem.fileExists('/dest/config/app.json'), isTrue);
      expect(fakeFileSystem.fileExists('/dest/config/db.json'), isTrue);
    });

    test('complete directory copying workflow', () async {
      // Setup source directory with files
      fakeFileSystem.addDirectory('/source/node_modules');
      fakeFileSystem.addFile(
        '/source/node_modules/package.json',
        '{"name": "pkg"}',
      );
      fakeFileSystem.addFile(
        '/source/node_modules/index.js',
        'console.log("hello");',
      );

      final config = CopyConfig(files: [], directories: ['node_modules']);

      await copyService.copyFiles(config, '/source', '/dest');

      // Verify directory and files were copied
      expect(fakeFileSystem.directoryExists('/dest/node_modules'), isTrue);
      expect(
        fakeFileSystem.fileExists('/dest/node_modules/package.json'),
        isTrue,
      );
      expect(fakeFileSystem.fileExists('/dest/node_modules/index.js'), isTrue);
    });

    test('handles missing files gracefully in integration', () async {
      final config = CopyConfig(
        files: ['missing.env', '*.env'], // One missing, one matching
        directories: [],
      );

      fakeFileSystem.addFile('/source/existing.env', 'content');

      await copyService.copyFiles(config, '/source', '/dest');

      // Should copy existing file but not fail on missing one
      expect(fakeFileSystem.fileExists('/dest/existing.env'), isTrue);
      expect(fakeFileSystem.fileExists('/dest/missing.env'), isFalse);
    });

    test('handles mixed files and directories', () async {
      // Setup files
      fakeFileSystem.addFile('/source/.env', 'content');
      // Setup directory
      fakeFileSystem.addDirectory('/source/config');
      fakeFileSystem.addFile(
        '/source/config/settings.json',
        '{"setting": true}',
      );

      final config = CopyConfig(files: ['.env'], directories: ['config']);

      await copyService.copyFiles(config, '/source', '/dest');

      // Verify both file and directory copying
      expect(fakeFileSystem.fileExists('/dest/.env'), isTrue);
      expect(fakeFileSystem.directoryExists('/dest/config'), isTrue);
      expect(fakeFileSystem.fileExists('/dest/config/settings.json'), isTrue);
    });

    test('preserves file structure when copying', () async {
      // Setup nested structure
      fakeFileSystem.addFile('/source/deep/nested/file.txt', 'content');
      fakeFileSystem.addDirectory('/source/deep');
      fakeFileSystem.addDirectory('/source/deep/nested');

      final config = CopyConfig(files: ['deep/**/*.txt'], directories: []);

      await copyService.copyFiles(config, '/source', '/dest');

      // Verify structure is preserved
      expect(fakeFileSystem.fileExists('/dest/deep/nested/file.txt'), isTrue);
    });
  });
}
