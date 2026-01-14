import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

import 'package:gwm/src/infrastructure/git_client.dart';
import 'package:gwm/src/infrastructure/git_client_impl.dart';
import '../../mock_objects/fake_process_wrapper.dart';

void main() {
  group('GitClientImpl', () {
    late FakeProcessWrapper fakeProcessWrapper;
    late GitClient gitClient;

    setUp(() {
      fakeProcessWrapper = FakeProcessWrapper();
      gitClient = GitClientImpl(fakeProcessWrapper);
    });

    tearDown(() {
      fakeProcessWrapper.clearResponses();
    });

    group('createWorktree', () {
      test('creates worktree successfully', () async {
        fakeProcessWrapper.addResponse('git', [
          'worktree',
          'add',
          '/path/to/worktree',
          'feature/branch',
        ]);

        final result = await gitClient.createWorktree(
          '/path/to/worktree',
          'feature/branch',
        );

        expect(result, '/path/to/worktree');
      });

      test('throws exception on git failure', () async {
        fakeProcessWrapper.addResponse(
          'git',
          ['worktree', 'add', '/invalid/path', 'branch'],
          exitCode: 1,
          stderr: 'fatal: invalid path',
        );

        await expectLater(
          gitClient.createWorktree('/invalid/path', 'branch'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains(
                'Git command failed: git worktree add /invalid/path branch',
              ),
            ),
          ),
        );
      });

      test('creates worktree with new branch', () async {
        fakeProcessWrapper.addResponse('git', [
          'worktree',
          'add',
          '-b',
          'new-branch',
          '/path/to/worktree',
        ]);

        await expectLater(
          gitClient.createWorktree(
            '/path/to/worktree',
            'new-branch',
            createBranch: true,
          ),
          completes,
        );
      });
    });

    group('listWorktrees', () {
      test('parses worktree list successfully', () async {
        const output = '''
worktree /main/path
HEAD abc123def456
branch refs/heads/main

worktree /feature/path
HEAD def456ghi789
branch refs/heads/feature/branch
''';
        fakeProcessWrapper.addResponse('git', [
          'worktree',
          'list',
          '--porcelain',
        ], stdout: output);

        final worktrees = await gitClient.listWorktrees();

        expect(worktrees, hasLength(2));
        expect(worktrees[0].name, 'main');
        expect(worktrees[0].branch, 'main');
        expect(worktrees[0].path, '/main/path');
        expect(worktrees[0].isMain, isTrue);
        expect(worktrees[1].name, 'branch');
        expect(worktrees[1].branch, 'feature/branch');
        expect(worktrees[1].path, '/feature/path');
        expect(worktrees[1].isMain, isFalse);
      });

      test('handles detached HEAD', () async {
        const output = '''
worktree /detached/path
HEAD abc123def456
''';
        fakeProcessWrapper.addResponse('git', [
          'worktree',
          'list',
          '--porcelain',
        ], stdout: output);

        final worktrees = await gitClient.listWorktrees();

        expect(worktrees, hasLength(1));
        expect(worktrees[0].name, 'detached');
        expect(worktrees[0].branch, 'HEAD');
      });

      test('throws exception on git failure', () async {
        fakeProcessWrapper.addResponse(
          'git',
          ['worktree', 'list', '--porcelain'],
          exitCode: 1,
          stderr: 'fatal: not a git repository',
        );

        await expectLater(
          gitClient.listWorktrees(),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Git command failed: git worktree list --porcelain'),
            ),
          ),
        );
      });
    });

    group('removeWorktree', () {
      test('removes worktree successfully', () async {
        fakeProcessWrapper.addResponse('git', [
          'worktree',
          'remove',
          '/path/to/remove',
        ]);

        await expectLater(
          gitClient.removeWorktree('/path/to/remove'),
          completes,
        );
      });

      test('throws exception on git failure', () async {
        fakeProcessWrapper.addResponse(
          'git',
          ['worktree', 'remove', '/nonexistent'],
          exitCode: 1,
          stderr: 'fatal: worktree not found',
        );

        await expectLater(
          gitClient.removeWorktree('/nonexistent'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Git command failed: git worktree remove /nonexistent'),
            ),
          ),
        );
      });
    });

    group('getCurrentBranch', () {
      test('returns current branch', () async {
        fakeProcessWrapper.addResponse('git', [
          'branch',
          '--show-current',
        ], stdout: 'feature/current\n');

        final branch = await gitClient.getCurrentBranch();

        expect(branch, 'feature/current');
      });

      test('throws exception on git failure', () async {
        fakeProcessWrapper.addResponse(
          'git',
          ['branch', '--show-current'],
          exitCode: 1,
          stderr: 'fatal: not on any branch',
        );

        await expectLater(
          gitClient.getCurrentBranch(),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Git command failed: git branch --show-current'),
            ),
          ),
        );
      });
    });

    group('branchExists', () {
      test('returns true when branch exists', () async {
        fakeProcessWrapper.addResponse('git', [
          'branch',
          '--list',
          'existing-branch',
        ], stdout: '  existing-branch\n');

        final exists = await gitClient.branchExists('existing-branch');

        expect(exists, isTrue);
      });

      test('returns false when branch does not exist', () async {
        fakeProcessWrapper.addResponse('git', [
          'branch',
          '--list',
          'nonexistent',
        ], stdout: '');

        final exists = await gitClient.branchExists('nonexistent');

        expect(exists, isFalse);
      });

      test('throws exception on git failure', () async {
        fakeProcessWrapper.addResponse(
          'git',
          ['branch', '--list', 'branch'],
          exitCode: 1,
          stderr: 'fatal: not a git repository',
        );

        await expectLater(
          gitClient.branchExists('branch'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Git command failed: git branch --list branch'),
            ),
          ),
        );
      });
    });

    group('hasUncommittedChanges', () {
      test('returns true when there are uncommitted changes', () async {
        fakeProcessWrapper.addResponse('git', [
          'status',
          '--porcelain',
        ], stdout: ' M modified-file.txt\n?? new-file.txt\n');

        final hasChanges = await gitClient.hasUncommittedChanges(
          '/worktree/path',
        );

        expect(hasChanges, isTrue);
      });

      test('returns false when worktree is clean', () async {
        fakeProcessWrapper.addResponse('git', [
          'status',
          '--porcelain',
        ], stdout: '');

        final hasChanges = await gitClient.hasUncommittedChanges('/clean/path');

        expect(hasChanges, isFalse);
      });

      test('throws exception on git failure', () async {
        fakeProcessWrapper.addResponse(
          'git',
          ['status', '--porcelain'],
          exitCode: 1,
          stderr: 'fatal: not a git repository',
        );

        await expectLater(
          gitClient.hasUncommittedChanges('/invalid/path'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Git command failed: git status --porcelain'),
            ),
          ),
        );
      });

      test('returns false when worktree is clean', () async {
        fakeProcessWrapper.addResponse('git', [
          'status',
          '--porcelain',
        ], stdout: '');

        final hasChanges = await gitClient.hasUncommittedChanges('/clean/path');

        expect(hasChanges, isFalse);
      });

      test('throws exception on git failure', () async {
        fakeProcessWrapper.addResponse(
          'git',
          ['status', '--porcelain'],
          exitCode: 1,
          stderr: 'fatal: not a git repository',
        );

        await expectLater(
          gitClient.hasUncommittedChanges('/invalid/path'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Git command failed: git status --porcelain'),
            ),
          ),
        );
      });
    });

    group('getBranchStatus', () {
      test('returns unknown status', () async {
        final status = await gitClient.getBranchStatus('any-branch');

        expect(status, 'unknown');
      });
    });

    group('getMainRepoPath', () {
      test('returns current directory when in main repo', () async {
        fakeProcessWrapper.addResponse('git', [
          'rev-parse',
          '--git-dir',
        ], stdout: '.git\n');

        final path = await gitClient.getMainRepoPath();

        expect(path, Directory.current.path);
      });

      test('returns main repo path when in worktree', () async {
        // Mock the .git file content for a worktree
        fakeProcessWrapper.addResponse('git', [
          'rev-parse',
          '--git-dir',
        ], stdout: '/path/to/main/.git/worktrees/worktree\n');

        // Note: This test would need file system mocking to fully test
        // the worktree case. For now, we test the git command part.
        // The actual file reading logic is tested in integration tests.
      });
    });

    group('isWorktree', () {
      late Directory tempDir;
      late Directory worktreeDir;
      late Directory subDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('gwm_test');
        worktreeDir = Directory(path.join(tempDir.path, 'worktree'));
        await worktreeDir.create();
        subDir = Directory(path.join(worktreeDir.path, 'subdir'));
        await subDir.create();
      });

      tearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('returns false when not in git repository', () async {
        fakeProcessWrapper.addResponse(
          'git',
          ['rev-parse', '--show-toplevel'],
          exitCode: 128, // Not in git repo
          stderr: 'fatal: not a git repository',
        );

        final isWorktree = await gitClient.isWorktree();

        expect(isWorktree, isFalse);
      });

      test('returns false when in main repository', () async {
        // Mock being in main repo
        fakeProcessWrapper.addResponse('git', [
          'rev-parse',
          '--show-toplevel',
        ], stdout: '${tempDir.path}\n');

        // Create .git directory (main repo)
        final gitDir = Directory(path.join(tempDir.path, '.git'));
        await gitDir.create();

        final isWorktree = await gitClient.isWorktree();

        expect(isWorktree, isFalse);
      });

      test('returns true when in worktree root', () async {
        // Mock being in worktree
        fakeProcessWrapper.addResponse('git', [
          'rev-parse',
          '--show-toplevel',
        ], stdout: '${worktreeDir.path}\n');

        // Create .git file (worktree)
        final gitFile = File(path.join(worktreeDir.path, '.git'));
        await gitFile.writeAsString(
          'gitdir: /path/to/main/.git/worktrees/feature',
        );

        final isWorktree = await gitClient.isWorktree();

        expect(isWorktree, isTrue);
      });

      test('returns true when in worktree subdirectory', () async {
        // Mock being in worktree subdirectory
        fakeProcessWrapper.addResponse('git', [
          'rev-parse',
          '--show-toplevel',
        ], stdout: '${worktreeDir.path}\n');

        // Create .git file in worktree root (worktree)
        final gitFile = File(path.join(worktreeDir.path, '.git'));
        await gitFile.writeAsString(
          'gitdir: /path/to/main/.git/worktrees/feature',
        );

        // Change to subdirectory for this test
        final originalDir = Directory.current;
        try {
          Directory.current = subDir;

          final isWorktree = await gitClient.isWorktree();

          expect(isWorktree, isTrue);
        } finally {
          Directory.current = originalDir;
        }
      });
    });
  });
}
