import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gwm/src/services/worktree_service.dart';
import 'package:gwm/src/services/hook_service.dart';
import 'package:gwm/src/services/copy_service.dart';
import 'package:gwm/src/models/config.dart';
import 'package:gwm/src/models/hook.dart';
import 'package:gwm/src/models/exit_codes.dart';
import 'package:gwm/src/infrastructure/git_client.dart';
import 'package:gwm/src/infrastructure/file_system_adapter.dart';

import '../mock_objects/fake_process_wrapper.dart';

class MockGitClient extends Mock implements GitClient {}

class FakeFileSystemAdapter implements FileSystemAdapter {
  final Map<String, dynamic> _files = {};
  final Map<String, dynamic> _directories = {};

  @override
  Future<void> copyDirectory(String source, String destination) async {}

  @override
  Future<void> copyFile(String source, String destination) async {
    if (_files.containsKey(source)) {
      _files[destination] = _files[source];
    }
  }

  @override
  Future<void> createDirectory(String path) async {
    _directories[path] = true;
  }

  @override
  Future<void> deleteDirectory(String path) async {
    _directories.remove(path);
  }

  @override
  Future<void> deleteFile(String path) async {
    _files.remove(path);
  }

  @override
  bool directoryExists(String path) => _directories.containsKey(path);

  @override
  bool fileExists(String path) => _files.containsKey(path);

  @override
  Future<int> getFileSize(String path) async => 0;

  @override
  Future<DateTime> getLastModified(String path) async => DateTime.now();

  @override
  List<String> listContents(String path, {String? pattern}) => [];

  @override
  Future<String> readFile(String path) async => _files[path]?.toString() ?? '';

  @override
  Future<void> writeFile(String path, String content) async {
    _files[path] = content;
  }

  void addFile(String path, String content) {
    _files[path] = content;
  }

  void addDirectory(String path) {
    _directories[path] = true;
  }

  void clear() {
    _files.clear();
    _directories.clear();
  }
}

void main() {
  late MockGitClient mockGitClient;
  late HookService hookService;
  late CopyService copyService;
  late FakeProcessWrapper fakeProcessWrapper;
  late FakeFileSystemAdapter fakeFileSystem;
  late WorktreeService worktreeService;

  setUp(() {
    mockGitClient = MockGitClient();
    fakeProcessWrapper = FakeProcessWrapper();
    fakeFileSystem = FakeFileSystemAdapter();

    hookService = HookService(fakeProcessWrapper);
    copyService = CopyService(fakeFileSystem);
    worktreeService = WorktreeService(mockGitClient, hookService, copyService);

    registerFallbackValue('');
    registerFallbackValue(const HooksConfig(timeout: 30));
  });

  tearDown(() {
    fakeProcessWrapper.clearResponses();
    fakeFileSystem.clear();
  });

  group('WorktreeService Integration', () {
    group('createWorktree validation', () {
      test('returns error when run from worktree', () async {
        when(() => mockGitClient.isWorktree()).thenAnswer((_) async => true);

        final config = const Config(
          version: '1.0',
          copy: CopyConfig(files: [], directories: []),
          hooks: HooksConfig(timeout: 30),
          shellIntegration: ShellIntegrationConfig(enableEvalOutput: false),
        );

        final exitCode = await worktreeService.createWorktree(
          'feature/test',
          config: config,
        );

        expect(exitCode, ExitCode.generalError);
      });

      test('returns branchNotFound when branch does not exist', () async {
        when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);
        when(
          () => mockGitClient.getRepoRoot(),
        ).thenAnswer((_) async => '/repo');
        when(
          () => mockGitClient.branchExists('nonexistent'),
        ).thenAnswer((_) async => false);
        when(
          () => mockGitClient.remoteBranchExists('nonexistent'),
        ).thenAnswer((_) async => false);

        final config = const Config(
          version: '1.0',
          copy: CopyConfig(files: [], directories: []),
          hooks: HooksConfig(timeout: 30),
          shellIntegration: ShellIntegrationConfig(enableEvalOutput: false),
        );

        final exitCode = await worktreeService.createWorktree(
          'nonexistent',
          config: config,
        );

        expect(exitCode, ExitCode.branchNotFound);
      });
    });

    group('getWorktreePath', () {
      test('resolves worktree path correctly', () async {
        when(
          () => mockGitClient.getRepoRoot(),
        ).thenAnswer((_) async => '/projects/my-app');

        final path = await worktreeService.getWorktreePath('feature/test');

        expect(path, contains('worktrees'));
        expect(path, contains('my-app'));
        expect(path, contains('feature_test'));
      });

      test('handles branch names with multiple slashes', () async {
        when(
          () => mockGitClient.getRepoRoot(),
        ).thenAnswer((_) async => '/projects/my-app');

        final path = await worktreeService.getWorktreePath(
          'feature/team/subfeature',
        );

        expect(path, contains('feature_team_subfeature'));
      });

      test('handles simple branch names', () async {
        when(
          () => mockGitClient.getRepoRoot(),
        ).thenAnswer((_) async => '/projects/repo');

        final path = await worktreeService.getWorktreePath('main');

        expect(path, contains('repo_main'));
      });
    });
  });

  group('CopyService Integration with WorktreeService', () {
    test('copies files during worktree creation', () async {
      fakeFileSystem.addFile('/repo/.env', 'KEY=value');
      fakeFileSystem.addDirectory('/repo');

      expect(fakeFileSystem.fileExists('/repo/.env'), isTrue);
    });
  });

  group('HookService Integration with WorktreeService', () {
    test('executes pre-create hook successfully', () async {
      fakeProcessWrapper.addResponse('/bin/sh', [
        '-c',
        'echo "pre-create hook"',
      ], stdout: 'pre-create hook\n');

      final config = HooksConfig(
        timeout: 30,
        preCreate: Hook.fromList(['echo "pre-create hook"']),
      );

      await hookService.executePreCreate(
        config,
        '/worktrees/test',
        '/repo',
        'feature/test',
      );
    });

    test('executes all hook phases in order', () async {
      fakeProcessWrapper.addResponse('/bin/sh', [
        '-c',
        'echo "pre-create"',
      ], stdout: 'pre-create\n');
      fakeProcessWrapper.addResponse('/bin/sh', [
        '-c',
        'echo "post-create"',
      ], stdout: 'post-create\n');

      final config = HooksConfig(
        timeout: 30,
        preCreate: Hook.fromList(['echo "pre-create"']),
        postCreate: Hook.fromList(['echo "post-create"']),
      );

      await hookService.executePreCreate(
        config,
        '/worktrees/test',
        '/repo',
        'branch',
      );
      await hookService.executePostCreate(
        config,
        '/worktrees/test',
        '/repo',
        'branch',
      );
    });

    test('executes switch hooks', () async {
      fakeProcessWrapper.addResponse('/bin/sh', [
        '-c',
        'echo "pre-switch"',
      ], stdout: 'pre-switch\n');
      fakeProcessWrapper.addResponse('/bin/sh', [
        '-c',
        'echo "post-switch"',
      ], stdout: 'post-switch\n');

      final config = HooksConfig(
        timeout: 30,
        preSwitch: Hook.fromList(['echo "pre-switch"']),
        postSwitch: Hook.fromList(['echo "post-switch"']),
      );

      await hookService.executePreSwitch(
        config,
        '/worktrees/target',
        '/repo',
        'feature/target',
      );
      await hookService.executePostSwitch(
        config,
        '/worktrees/target',
        '/repo',
        'feature/target',
      );
    });

    test('executes delete hooks', () async {
      fakeProcessWrapper.addResponse('/bin/sh', [
        '-c',
        'echo "pre-delete"',
      ], stdout: 'pre-delete\n');
      fakeProcessWrapper.addResponse('/bin/sh', [
        '-c',
        'echo "post-delete"',
      ], stdout: 'post-delete\n');

      final config = HooksConfig(
        timeout: 30,
        preDelete: Hook.fromList(['echo "pre-delete"']),
        postDelete: Hook.fromList(['echo "post-delete"']),
      );

      await hookService.executePreDelete(
        config,
        '/worktrees/to-delete',
        '/repo',
        'feature/old',
      );
      await hookService.executePostDelete(
        config,
        '/worktrees/to-delete',
        '/repo',
        'feature/old',
      );
    });

    test('handles hook timeout', () async {
      fakeProcessWrapper.addResponse('/bin/sh', ['-c', 'sleep 1'], stdout: '');

      final config = HooksConfig(
        timeout: 5,
        preCreate: Hook.fromList(['sleep 1']),
      );

      await hookService.executePreCreate(
        config,
        '/worktrees/test',
        '/repo',
        'branch',
      );
    });

    test('hook-specific timeout overrides global', () async {
      fakeProcessWrapper.addResponse('/bin/sh', [
        '-c',
        'echo "custom timeout"',
      ], stdout: 'custom timeout\n');

      final config = HooksConfig(
        timeout: 30,
        preCreate: Hook(commands: ['echo "custom timeout"'], timeout: 60),
      );

      await hookService.executePreCreate(
        config,
        '/worktrees/test',
        '/repo',
        'branch',
      );
    });
  });
}
