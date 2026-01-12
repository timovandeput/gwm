import 'dart:io';

import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gwt/src/services/worktree_service.dart';
import 'package:gwt/src/models/exit_codes.dart';
import 'package:gwt/src/infrastructure/git_client.dart';
import 'package:gwt/src/utils/path_utils.dart';

// Mock classes
class MockGitClient extends Mock implements GitClient {}

void main() {
  group('WorktreeService', () {
    late WorktreeService worktreeService;
    late MockGitClient mockGitClient;
    late Directory tempDir;

    setUp(() {
      mockGitClient = MockGitClient();
      worktreeService = WorktreeService(mockGitClient);
      tempDir = Directory.systemTemp.createTempSync('gwt_worktree_test_');

      // Register fallback values for mocks
      registerFallbackValue('');

      // Set up default stubs to prevent null returns
      when(() => mockGitClient.createWorktree(any(), any())).thenAnswer((
        invocation,
      ) async {
        final path = invocation.positionalArguments[0] as String;
        // Simulate creating the directory
        Directory(path).createSync(recursive: true);
        return path;
      });
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
        final repoName = PathUtils.basename(tempDir.path);
        final parentDir = PathUtils.dirname(tempDir.path);
        final expectedPath = PathUtils.join([
          parentDir,
          'worktrees',
          '${repoName}_feature_test',
        ]);

        when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);
        when(
          () => mockGitClient.branchExists(branch),
        ).thenAnswer((_) async => true);
        when(
          () => mockGitClient.getRepoRoot(),
        ).thenAnswer((_) async => '${tempDir.path}/repo');
        when(
          () => mockGitClient.createWorktree(expectedPath, branch),
        ).thenAnswer((_) async {
          // Simulate creating the directory
          Directory(expectedPath).createSync(recursive: true);
          return expectedPath;
        });

        // Act
        final result = await worktreeService.addWorktree(
          branch,
          createBranch: true,
        );

        // Assert
        expect(result, ExitCode.success);
        verifyNever(
          () => mockGitClient.createBranch(branch),
        ); // Branch exists, so shouldn't create
        verify(
          () => mockGitClient.createWorktree(expectedPath, branch),
        ).called(1);
      });

      test(
        'returns worktreeExists when worktree directory already exists',
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
          final result = await worktreeService.addWorktree(branch);

          // Assert
          expect(result, ExitCode.worktreeExists);
          verifyNever(() => mockGitClient.createWorktree(any(), any()));
        },
      );

      test('returns generalError when running from a worktree', () async {
        // Arrange
        const branch = 'feature/test';

        when(() => mockGitClient.isWorktree()).thenAnswer((_) async => true);

        // Act
        final result = await worktreeService.addWorktree(branch);

        // Assert
        expect(result, ExitCode.generalError);
        verifyNever(() => mockGitClient.branchExists(any()));
        verifyNever(() => mockGitClient.createWorktree(any(), any()));
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
          () => mockGitClient.createWorktree(any(), any()),
        ).thenThrow(Exception('Git command failed'));

        // Act
        final result = await worktreeService.addWorktree(branch);

        // Assert
        expect(result, ExitCode.gitFailed);
      });

      test('sanitizes branch names with slashes for filesystem', () async {
        // Arrange
        const branch = 'feature/nested/branch';
        final repoName = PathUtils.basename(tempDir.path);
        final parentDir = PathUtils.dirname(tempDir.path);
        final expectedPath = PathUtils.join([
          parentDir,
          'worktrees',
          '${repoName}_feature_nested_branch',
        ]);

        when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);
        when(
          () => mockGitClient.branchExists(branch),
        ).thenAnswer((_) async => true);
        when(
          () => mockGitClient.getRepoRoot(),
        ).thenAnswer((_) async => tempDir.path);
        when(
          () => mockGitClient.createWorktree(expectedPath, branch),
        ).thenAnswer((_) async {
          // Simulate creating the directory
          Directory(expectedPath).createSync(recursive: true);
          return expectedPath;
        });

        // Act
        final result = await worktreeService.addWorktree(branch);

        // Assert
        expect(result, ExitCode.success);
        verify(
          () => mockGitClient.createWorktree(expectedPath, branch),
        ).called(1);
      });
    });
  });
}
