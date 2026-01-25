import 'dart:io';

import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gwm/src/services/worktree_service.dart';
import 'package:gwm/src/models/exit_codes.dart';
import 'package:gwm/src/infrastructure/git_client.dart';
import 'package:gwm/src/services/copy_service.dart';
import 'package:gwm/src/services/hook_service.dart';
import 'package:gwm/src/models/config.dart';

// Fake classes for fallbacks
class FakeCopyConfig extends Fake implements CopyConfig {}

// Mock classes
class MockGitClient extends Mock implements GitClient {}

class MockCopyService extends Mock implements CopyService {}

class MockHookService extends Mock implements HookService {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCopyConfig());
  });

  group('WorktreeService', () {
    late WorktreeService worktreeService;
    late MockGitClient mockGitClient;
    late MockCopyService mockCopyService;
    late MockHookService mockHookService;
    late Directory tempDir;

    setUp(() {
      mockGitClient = MockGitClient();
      mockCopyService = MockCopyService();
      mockHookService = MockHookService();
      worktreeService = WorktreeService(
        mockGitClient,
        mockHookService,
        mockCopyService,
      );
      tempDir = Directory.systemTemp.createTempSync('gwm_worktree_test_');

      // Register fallback values for mocks
      registerFallbackValue('');

      // Set up default stubs to prevent null returns
      // createWorktree is stubbed individually in each test
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('addWorktree', () {
      test('returns success when worktree is created successfully', () async {
        // Arrange
        const branch = 'feature/test';

        when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);
        when(
          () => mockGitClient.branchExists(branch),
        ).thenAnswer((_) async => true);
        when(
          () => mockGitClient.getRepoRoot(),
        ).thenAnswer((_) async => '${tempDir.path}/repo');
        when(
          () => mockGitClient.createWorktree(
            any(),
            branch,
            createBranch: any(named: 'createBranch'),
          ),
        ).thenAnswer((invocation) async {
          final path = invocation.positionalArguments[0] as String;
          // Simulate creating the directory
          Directory(path).createSync(recursive: true);
          return path;
        });

        // Act
        final result = await worktreeService.createWorktree(
          branch,
          createBranch: true,
        );

        // Assert
        expect(result, ExitCode.success);
        verify(
          () => mockGitClient.createWorktree(
            any(),
            branch,
            createBranch: any(named: 'createBranch'),
          ),
        ).called(1);
      });

      test(
        'returns worktreeExistsButSwitched when worktree directory already exists',
        () async {
          // Arrange
          const branch = 'existing-worktree';
          const repoPath = 'test_repo';
          const worktreePath = './worktrees/test_repo_existing-worktree';

          // Create the directory to simulate existing worktree
          Directory(worktreePath).createSync(recursive: true);

          when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);
          when(
            () => mockGitClient.branchExists(branch),
          ).thenAnswer((_) async => true);
          when(
            () => mockGitClient.getRepoRoot(),
          ).thenAnswer((_) async => repoPath);

          // Act
          final result = await worktreeService.createWorktree(branch);

          // Assert
          expect(result, ExitCode.worktreeExistsButSwitched);
          verifyNever(
            () => mockGitClient.createWorktree(
              any(),
              any(),
              createBranch: any(named: 'createBranch'),
            ),
          );
        },
      );

      test('returns generalError when running from a worktree', () async {
        // Arrange
        const branch = 'feature/test';

        when(() => mockGitClient.isWorktree()).thenAnswer((_) async => true);

        // Act
        final result = await worktreeService.createWorktree(branch);

        // Assert
        expect(result, ExitCode.generalError);
        verifyNever(() => mockGitClient.branchExists(any()));
        verifyNever(
          () => mockGitClient.createWorktree(
            any(),
            any(),
            createBranch: any(named: 'createBranch'),
          ),
        );
      });

      test('returns gitFailed when createWorktree throws exception', () async {
        // Arrange
        const branch = 'feature/test';

        when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);
        when(
          () => mockGitClient.branchExists(branch),
        ).thenAnswer((_) async => true);
        when(
          () => mockGitClient.getRepoRoot(),
        ).thenAnswer((_) async => tempDir.path);
        when(
          () => mockGitClient.createWorktree(
            any(),
            any(),
            createBranch: any(named: 'createBranch'),
          ),
        ).thenThrow(Exception('Git command failed'));

        // Act
        final result = await worktreeService.createWorktree(branch);

        // Assert
        expect(result, ExitCode.gitFailed);
      });

      test('sanitizes branch names with slashes for filesystem', () async {
        // Arrange
        const branch = 'feature/nested/branch';

        when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);
        when(
          () => mockGitClient.branchExists(branch),
        ).thenAnswer((_) async => true);
        when(
          () => mockGitClient.getRepoRoot(),
        ).thenAnswer((_) async => tempDir.path);
        when(
          () => mockGitClient.createWorktree(
            any(),
            branch,
            createBranch: any(named: 'createBranch'),
          ),
        ).thenAnswer((invocation) async {
          final path = invocation.positionalArguments[0] as String;
          // Simulate creating the directory
          Directory(path).createSync(recursive: true);
          return path;
        });

        // Act
        final result = await worktreeService.createWorktree(branch);

        // Assert
        expect(result, ExitCode.success);
        verify(
          () => mockGitClient.createWorktree(
            any(),
            branch,
            createBranch: any(named: 'createBranch'),
          ),
        ).called(1);
      });

      test('calls copyFiles when config contains copy settings', () async {
        // Arrange
        const branch = 'feature/copy';
        final config = Config(
          version: '1.0',
          copy: CopyConfig(files: ['*.md'], directories: ['docs']),
          hooks: HooksConfig(timeout: 30),
          shellIntegration: ShellIntegrationConfig(enableEvalOutput: false),
        );

        when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);
        when(
          () => mockGitClient.branchExists(branch),
        ).thenAnswer((_) async => true);
        when(
          () => mockGitClient.getRepoRoot(),
        ).thenAnswer((_) async => '${tempDir.path}/repo');
        when(
          () => mockGitClient.createWorktree(
            any(),
            branch,
            createBranch: any(named: 'createBranch'),
          ),
        ).thenAnswer((invocation) async {
          final path = invocation.positionalArguments[0] as String;
          Directory(path).createSync(recursive: true);
          return path;
        });
        when(
          () => mockCopyService.copyFiles(any(), any(), any()),
        ).thenAnswer((_) async {});

        // Act
        final result = await worktreeService.createWorktree(
          branch,
          config: config,
        );

        // Assert
        expect(result, ExitCode.success);
        verify(
          () => mockCopyService.copyFiles(
            config.copy,
            '${tempDir.path}/repo',
            any(),
          ),
        ).called(1);
      });

      test(
        'creates worktree with tracking when local branch does not exist but remote does',
        () async {
          // Arrange
          const branch = 'feature/remote-only';
          final repoPath = '${tempDir.path}/repo';
          final worktreePath =
              '${tempDir.path}/worktrees/repo_feature_remote-only';

          when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);
          when(
            () => mockGitClient.branchExists(branch),
          ).thenAnswer((_) async => false);
          when(
            () => mockGitClient.remoteBranchExists(branch),
          ).thenAnswer((_) async => true);
          when(
            () => mockGitClient.getRepoRoot(),
          ).thenAnswer((_) async => repoPath);
          when(
            () => mockGitClient.createWorktree(
              worktreePath,
              branch,
              createBranch: true,
            ),
          ).thenAnswer((_) async {
            Directory(worktreePath).createSync(recursive: true);
            return worktreePath;
          });
          when(
            () => mockGitClient.setUpstreamBranch(branch),
          ).thenAnswer((_) async {});

          // Act
          final result = await worktreeService.createWorktree(branch);

          // Assert
          expect(result, ExitCode.success);
          verify(
            () => mockGitClient.createWorktree(
              worktreePath,
              branch,
              createBranch: true,
            ),
          ).called(1);
          verify(() => mockGitClient.setUpstreamBranch(branch)).called(1);
        },
      );

      test(
        'returns branchNotFound when neither local nor remote branch exists',
        () async {
          // Arrange
          const branch = 'nonexistent-branch';

          when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);
          when(
            () => mockGitClient.branchExists(branch),
          ).thenAnswer((_) async => false);
          when(
            () => mockGitClient.remoteBranchExists(branch),
          ).thenAnswer((_) async => false);
          when(
            () => mockGitClient.getRepoRoot(),
          ).thenAnswer((_) async => '${tempDir.path}/repo');

          // Act
          final result = await worktreeService.createWorktree(branch);

          // Assert
          expect(result, ExitCode.branchNotFound);
          verifyNever(
            () => mockGitClient.createWorktree(
              any(),
              any(),
              createBranch: any(named: 'createBranch'),
            ),
          );
          verifyNever(() => mockGitClient.setUpstreamBranch(any()));
        },
      );
    });
  });
}
