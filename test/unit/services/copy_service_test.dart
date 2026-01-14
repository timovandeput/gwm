import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gwm/src/services/copy_service.dart';
import 'package:gwm/src/models/config.dart';
import 'package:gwm/src/infrastructure/file_system_adapter.dart';

// Mock classes
class MockFileSystemAdapter extends Mock implements FileSystemAdapter {}

void main() {
  group('CopyService', () {
    late CopyService copyService;
    late MockFileSystemAdapter mockFileSystem;

    setUp(() {
      mockFileSystem = MockFileSystemAdapter();
      copyService = CopyService(mockFileSystem);
    });

    group('copyFiles', () {
      test('copies files matching glob patterns', () async {
        final config = CopyConfig(
          files: ['*.env', 'config/*.json'],
          directories: [],
        );

        when(
          () => mockFileSystem.listContents('/source', pattern: '*.env'),
        ).thenReturn(['.env', '.env.local']);
        when(() => mockFileSystem.fileExists('/source/.env')).thenReturn(true);
        when(
          () => mockFileSystem.fileExists('/source/.env.local'),
        ).thenReturn(true);
        when(
          () =>
              mockFileSystem.listContents('/source', pattern: 'config/*.json'),
        ).thenReturn(['config/app.json']);
        when(
          () => mockFileSystem.fileExists('/source/config/app.json'),
        ).thenReturn(true);

        when(
          () => mockFileSystem.copyFile(any(), any()),
        ).thenAnswer((_) async {});

        await copyService.copyFiles(config, '/source', '/dest');

        verify(
          () => mockFileSystem.copyFile('/source/.env', '/dest/.env'),
        ).called(1);
        verify(
          () =>
              mockFileSystem.copyFile('/source/.env.local', '/dest/.env.local'),
        ).called(1);
        verify(
          () => mockFileSystem.copyFile(
            '/source/config/app.json',
            '/dest/config/app.json',
          ),
        ).called(1);
      });

      test('copies directories recursively', () async {
        final config = CopyConfig(
          files: [],
          directories: ['node_modules', 'build'],
        );

        when(
          () => mockFileSystem.directoryExists('/source/node_modules'),
        ).thenReturn(true);
        when(
          () => mockFileSystem.directoryExists('/source/build'),
        ).thenReturn(true);

        when(
          () => mockFileSystem.copyDirectory(any(), any()),
        ).thenAnswer((_) async {});

        await copyService.copyFiles(config, '/source', '/dest');

        verify(
          () => mockFileSystem.copyDirectory(
            '/source/node_modules',
            '/dest/node_modules',
          ),
        ).called(1);
        verify(
          () => mockFileSystem.copyDirectory('/source/build', '/dest/build'),
        ).called(1);
      });

      test('handles missing source files gracefully', () async {
        final config = CopyConfig(files: ['missing.env'], directories: []);

        when(
          () => mockFileSystem.fileExists('/source/missing.env'),
        ).thenReturn(false);

        await copyService.copyFiles(config, '/source', '/dest');

        verifyNever(() => mockFileSystem.copyFile(any(), any()));
      });

      test('handles missing source directories gracefully', () async {
        final config = CopyConfig(files: [], directories: ['missing_dir']);

        when(
          () => mockFileSystem.directoryExists('/source/missing_dir'),
        ).thenReturn(false);

        await copyService.copyFiles(config, '/source', '/dest');

        verifyNever(() => mockFileSystem.copyDirectory(any(), any()));
      });

      test('handles copy failures gracefully', () async {
        final config = CopyConfig(files: ['failing.env'], directories: []);

        when(
          () => mockFileSystem.fileExists('/source/failing.env'),
        ).thenReturn(true);
        when(
          () => mockFileSystem.copyFile(
            '/source/failing.env',
            '/dest/failing.env',
          ),
        ).thenThrow(Exception('Copy failed'));

        await copyService.copyFiles(config, '/source', '/dest');

        // Should not throw, just log error
      });
    });

    group('pattern handling', () {
      test('handles direct file paths without wildcards', () async {
        final config = CopyConfig(files: ['exact.env'], directories: []);

        when(
          () => mockFileSystem.fileExists('/source/exact.env'),
        ).thenReturn(true);
        when(
          () => mockFileSystem.copyFile(any(), any()),
        ).thenAnswer((_) async {});

        await copyService.copyFiles(config, '/source', '/dest');

        verify(
          () => mockFileSystem.copyFile('/source/exact.env', '/dest/exact.env'),
        ).called(1);
        verifyNever(
          () => mockFileSystem.listContents(
            any(),
            pattern: any(named: 'pattern'),
          ),
        );
      });

      test('handles direct directory paths without wildcards', () async {
        final config = CopyConfig(files: [], directories: ['exact_dir']);

        when(
          () => mockFileSystem.directoryExists('/source/exact_dir'),
        ).thenReturn(true);
        when(
          () => mockFileSystem.copyDirectory(any(), any()),
        ).thenAnswer((_) async {});

        await copyService.copyFiles(config, '/source', '/dest');

        verify(
          () => mockFileSystem.copyDirectory(
            '/source/exact_dir',
            '/dest/exact_dir',
          ),
        ).called(1);
        verifyNever(
          () => mockFileSystem.listContents(
            any(),
            pattern: any(named: 'pattern'),
          ),
        );
      });
    });
  });
}
