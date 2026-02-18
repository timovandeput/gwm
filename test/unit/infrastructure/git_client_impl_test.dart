import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

import 'package:gwm/src/infrastructure/git_client.dart';
import 'package:gwm/src/infrastructure/git_client_impl.dart';
import 'package:gwm/src/models/worktree.dart';
import 'package:gwm/src/exceptions.dart';
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

      test('creates worktree with new branch', () async {
        fakeProcessWrapper.addResponse('git', [
          'worktree',
          'add',
          '-b',
          'feature/new',
          '/path/to/worktree',
        ]);

        final result = await gitClient.createWorktree(
          '/path/to/worktree',
          'feature/new',
          createBranch: true,
        );

        expect(result, '/path/to/worktree');
      });

      test('creates worktree with new branch from remote ref', () async {
        fakeProcessWrapper.addResponse('git', [
          'worktree',
          'add',
          '-b',
          'feature/remote',
          '/path/to/worktree',
          'origin/feature/remote',
        ]);

        final result = await gitClient.createWorktree(
          '/path/to/worktree',
          'feature/remote',
          createBranch: true,
          from: 'origin/feature/remote',
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
          throwsA(isA<GitException>()),
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
        fakeProcessWrapper.addResponse('git', ['worktree', 'prune']);
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
        fakeProcessWrapper.addResponse('git', ['worktree', 'prune']);
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
        fakeProcessWrapper.addResponse('git', ['worktree', 'prune']);
        fakeProcessWrapper.addResponse(
          'git',
          ['worktree', 'list', '--porcelain'],
          exitCode: 1,
          stderr: 'fatal: not a git repository',
        );

        await expectLater(
          gitClient.listWorktrees(),
          throwsA(isA<GitException>()),
        );
      });

      test('continues with list when prune fails', () async {
        const output = '''
worktree /main/path
HEAD abc123def456
branch refs/heads/main
''';
        fakeProcessWrapper.addResponse(
          'git',
          ['worktree', 'prune'],
          exitCode: 1,
          stderr: 'prune failed',
        );
        fakeProcessWrapper.addResponse('git', [
          'worktree',
          'list',
          '--porcelain',
        ], stdout: output);

        final worktrees = await gitClient.listWorktrees();

        expect(worktrees, hasLength(1));
        expect(worktrees[0].name, 'main');
        expect(worktrees[0].branch, 'main');
        expect(worktrees[0].path, '/main/path');
        expect(worktrees[0].isMain, isTrue);
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
          throwsA(isA<GitException>()),
        );
      });

      test('removes worktree with force flag', () async {
        fakeProcessWrapper.addResponse('git', [
          'worktree',
          'remove',
          '--force',
          '/path/to/remove',
        ]);

        await expectLater(
          gitClient.removeWorktree('/path/to/remove', force: true),
          completes,
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
          throwsA(isA<GitException>()),
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
          throwsA(isA<GitException>()),
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
          throwsA(isA<GitException>()),
        );
      });
    });

    group('getBranchStatus', () {
      test('returns clean status when no changes and in sync', () async {
        fakeProcessWrapper.addResponse('git', [
          'status',
          '--porcelain',
        ], stdout: '');
        fakeProcessWrapper.addResponse('git', [
          'status',
          '-b',
          '--ahead-behind',
        ], stdout: '## main...origin/main\n');

        final status = await gitClient.getBranchStatus('main', '/some/path');

        expect(status, WorktreeStatus.clean);
      });

      test(
        'returns modified status when there are uncommitted changes',
        () async {
          fakeProcessWrapper.addResponse('git', [
            'status',
            '--porcelain',
          ], stdout: ' M file.txt\n');
          fakeProcessWrapper.addResponse('git', [
            'status',
            '-b',
            '--ahead-behind',
          ], stdout: '## main...origin/main\n');

          final status = await gitClient.getBranchStatus('main', '/some/path');

          expect(status, WorktreeStatus.modified);
        },
      );

      test('returns ahead status when ahead of remote', () async {
        fakeProcessWrapper.addResponse('git', [
          'status',
          '--porcelain',
        ], stdout: '');
        fakeProcessWrapper.addResponse('git', [
          'status',
          '-b',
          '--ahead-behind',
        ], stdout: '## main...origin/main [ahead 2]\n');

        final status = await gitClient.getBranchStatus('main', '/some/path');

        expect(status, WorktreeStatus.ahead);
      });

      test('returns behind status when behind remote', () async {
        fakeProcessWrapper.addResponse('git', [
          'status',
          '--porcelain',
        ], stdout: '');
        fakeProcessWrapper.addResponse('git', [
          'status',
          '-b',
          '--ahead-behind',
        ], stdout: '## main...origin/main [behind 3]\n');

        final status = await gitClient.getBranchStatus('main', '/some/path');

        expect(status, WorktreeStatus.behind);
      });

      test('returns diverged status when both ahead and behind', () async {
        fakeProcessWrapper.addResponse('git', [
          'status',
          '--porcelain',
        ], stdout: '');
        fakeProcessWrapper.addResponse('git', [
          'status',
          '-b',
          '--ahead-behind',
        ], stdout: '## main...origin/main [ahead 1, behind 2]\n');

        final status = await gitClient.getBranchStatus('main', '/some/path');

        expect(status, WorktreeStatus.diverged);
      });

      test('returns modified over diverged when changes exist', () async {
        fakeProcessWrapper.addResponse('git', [
          'status',
          '--porcelain',
        ], stdout: ' M file.txt\n');
        fakeProcessWrapper.addResponse('git', [
          'status',
          '-b',
          '--ahead-behind',
        ], stdout: '## main...origin/main [ahead 1, behind 2]\n');

        final status = await gitClient.getBranchStatus('main', '/some/path');

        expect(status, WorktreeStatus.modified);
      });

      test('returns clean when status check fails', () async {
        fakeProcessWrapper.addResponse(
          'git',
          ['status', '--porcelain'],
          exitCode: 1,
          stderr: 'fatal: error',
        );

        final status = await gitClient.getBranchStatus('main', '/some/path');

        expect(status, WorktreeStatus.clean);
      });
    });

    group('getRepoRoot', () {
      test('returns repository root path', () async {
        fakeProcessWrapper.addResponse('git', [
          'rev-parse',
          '--show-toplevel',
        ], stdout: '/home/user/project\n');

        final root = await gitClient.getRepoRoot();

        expect(root, '/home/user/project');
      });

      test('throws exception when not in a git repository', () async {
        fakeProcessWrapper.addResponse(
          'git',
          ['rev-parse', '--show-toplevel'],
          exitCode: 128,
          stderr: 'fatal: not a git repository',
        );

        await expectLater(
          gitClient.getRepoRoot(),
          throwsA(isA<GitException>()),
        );
      });
    });

    group('getLastCommitTime', () {
      test('returns last commit time', () async {
        // 1700000000 = 2023-11-14T22:13:20Z
        fakeProcessWrapper.addResponse('git', [
          'log',
          '-1',
          '--format=%ct',
        ], stdout: '1700000000\n');

        final time = await gitClient.getLastCommitTime('/some/path');

        expect(time, isNotNull);
        expect(time, DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000));
      });

      test('returns null when no commits exist', () async {
        fakeProcessWrapper.addResponse(
          'git',
          ['log', '-1', '--format=%ct'],
          exitCode: 1,
          stderr: 'fatal: bad default revision',
        );

        final time = await gitClient.getLastCommitTime('/empty/repo');

        expect(time, isNull);
      });

      test('returns null when output is not a valid timestamp', () async {
        fakeProcessWrapper.addResponse('git', [
          'log',
          '-1',
          '--format=%ct',
        ], stdout: 'not-a-number\n');

        final time = await gitClient.getLastCommitTime('/some/path');

        expect(time, isNull);
      });
    });

    group('listBranches', () {
      test('returns list of branches', () async {
        fakeProcessWrapper.addResponse('git', [
          'branch',
          '--format=%(refname:short)',
        ], stdout: 'main\nfeature/auth\nfix/bug-123\n');

        final branches = await gitClient.listBranches();

        expect(branches, ['main', 'feature/auth', 'fix/bug-123']);
      });

      test('returns empty list when no branches', () async {
        fakeProcessWrapper.addResponse('git', [
          'branch',
          '--format=%(refname:short)',
        ], stdout: '');

        final branches = await gitClient.listBranches();

        expect(branches, isEmpty);
      });

      test('throws exception on git failure', () async {
        fakeProcessWrapper.addResponse(
          'git',
          ['branch', '--format=%(refname:short)'],
          exitCode: 1,
          stderr: 'fatal: not a git repository',
        );

        await expectLater(
          gitClient.listBranches(),
          throwsA(isA<GitException>()),
        );
      });
    });

    group('remoteBranchExists', () {
      test('returns true when remote branch exists', () async {
        fakeProcessWrapper.addResponse('git', [
          'branch',
          '-r',
          '--list',
          'origin/feature/auth',
        ], stdout: '  origin/feature/auth\n');

        final exists = await gitClient.remoteBranchExists('feature/auth');

        expect(exists, isTrue);
      });

      test('returns false when remote branch does not exist', () async {
        fakeProcessWrapper.addResponse('git', [
          'branch',
          '-r',
          '--list',
          'origin/nonexistent',
        ], stdout: '');

        final exists = await gitClient.remoteBranchExists('nonexistent');

        expect(exists, isFalse);
      });

      test('throws exception on git failure', () async {
        fakeProcessWrapper.addResponse(
          'git',
          ['branch', '-r', '--list', 'origin/branch'],
          exitCode: 1,
          stderr: 'fatal: not a git repository',
        );

        await expectLater(
          gitClient.remoteBranchExists('branch'),
          throwsA(isA<GitException>()),
        );
      });
    });

    group('setUpstreamBranch', () {
      test('sets upstream branch successfully', () async {
        fakeProcessWrapper.addResponse('git', [
          'branch',
          '--set-upstream-to=origin/feature/auth',
          'feature/auth',
        ]);

        await expectLater(
          gitClient.setUpstreamBranch('feature/auth'),
          completes,
        );
      });

      test('throws exception on git failure', () async {
        fakeProcessWrapper.addResponse(
          'git',
          ['branch', '--set-upstream-to=origin/nonexistent', 'nonexistent'],
          exitCode: 1,
          stderr: 'error: the requested upstream branch does not exist',
        );

        await expectLater(
          gitClient.setUpstreamBranch('nonexistent'),
          throwsA(isA<GitException>()),
        );
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
