import 'dart:async';
import 'dart:io';

import 'git_client.dart';
import 'process_wrapper.dart';
import '../models/worktree.dart';
import '../exceptions.dart';
import '../cli_utils.dart';

/// Implementation of GitClient using ProcessWrapper for Git operations.
class GitClientImpl implements GitClient {
  final ProcessWrapper _processWrapper;

  GitClientImpl(this._processWrapper);

  @override
  Future<String> createWorktree(
    String path,
    String branch, {
    bool createBranch = false,
  }) async {
    final args = ['worktree', 'add'];
    if (createBranch) {
      args.addAll(['-b', branch, path]);
    } else {
      args.addAll([path, branch]);
    }
    final result = await _processWrapper.run('git', args);
    _printOutput(result);
    if (result.exitCode != 0) {
      throw GitException('worktree', args, result.stderr as String);
    }
    return path;
  }

  @override
  Future<List<Worktree>> listWorktrees() async {
    // Prune stale worktree entries first
    final pruneResult = await _processWrapper.run('git', ['worktree', 'prune']);
    _printOutput(pruneResult);
    if (pruneResult.exitCode != 0) {
      // Prune failure is not fatal, continue with listing
    }

    final result = await _processWrapper.run('git', [
      'worktree',
      'list',
      '--porcelain',
    ]);
    _printOutput(result);
    if (result.exitCode != 0) {
      throw GitException('git', [
        'worktree',
        'list',
        '--porcelain',
      ], result.stderr as String);
    }
    return _parseWorktreeList(result.stdout as String);
  }

  @override
  Future<void> removeWorktree(String path, {bool force = false}) async {
    final args = ['worktree', 'remove'];
    if (force) {
      args.add('--force');
    }
    args.add(path);

    final result = await _processWrapper.run('git', args);
    _printOutput(result);
    if (result.exitCode != 0) {
      throw GitException('worktree', args, result.stderr as String);
    }
  }

  @override
  Future<String> getCurrentBranch() async {
    final result = await _processWrapper.run('git', [
      'branch',
      '--show-current',
    ]);
    _printOutput(result);
    if (result.exitCode != 0) {
      throw GitException('git', [
        'rev-parse',
        '--git-dir',
      ], result.stderr as String);
    }
    return (result.stdout as String).trim();
  }

  @override
  Future<bool> branchExists(String branch) async {
    final result = await _processWrapper.run('git', [
      'branch',
      '--list',
      branch,
    ]);
    _printOutput(result);
    if (result.exitCode != 0) {
      throw GitException('git', [
        'branch',
        '--list',
        branch,
      ], result.stderr as String);
    }
    return (result.stdout as String).trim().isNotEmpty;
  }

  @override
  Future<bool> hasUncommittedChanges(String path) async {
    final result = await _processWrapper.run('git', [
      'status',
      '--porcelain',
    ], workingDirectory: path);
    _printOutput(result);
    if (result.exitCode != 0) {
      throw GitException('git', [
        'status',
        '--porcelain',
      ], result.stderr as String);
    }
    return (result.stdout as String).trim().isNotEmpty;
  }

  @override
  Future<WorktreeStatus> getBranchStatus(String branch, String path) async {
    try {
      // Check if branch has uncommitted changes
      final statusResult = await _processWrapper.run('git', [
        'status',
        '--porcelain',
      ], workingDirectory: path);
      if (statusResult.exitCode != 0) {
        return WorktreeStatus.clean;
      }
      final hasChanges = (statusResult.stdout as String).trim().isNotEmpty;

      // Check relationship to remote tracking branch
      final remoteStatusResult = await _processWrapper.run('git', [
        'status',
        '-b',
        '--ahead-behind',
      ], workingDirectory: path);
      if (remoteStatusResult.exitCode != 0) {
        // No remote tracking branch
        return hasChanges ? WorktreeStatus.modified : WorktreeStatus.clean;
      }

      final statusOutput = remoteStatusResult.stdout as String;
      final aheadMatch = RegExp(r'ahead (\d+)').firstMatch(statusOutput);
      final behindMatch = RegExp(r'behind (\d+)').firstMatch(statusOutput);

      final ahead = aheadMatch != null ? int.parse(aheadMatch.group(1)!) : 0;
      final behind = behindMatch != null ? int.parse(behindMatch.group(1)!) : 0;

      if (hasChanges) {
        return WorktreeStatus.modified;
      } else if (ahead > 0 && behind > 0) {
        return WorktreeStatus.diverged;
      } else if (ahead > 0) {
        return WorktreeStatus.ahead;
      } else if (behind > 0) {
        return WorktreeStatus.behind;
      } else {
        return WorktreeStatus.clean;
      }
    } catch (e) {
      return WorktreeStatus.clean;
    }
  }

  @override
  Future<DateTime?> getLastCommitTime(String path) async {
    try {
      final result = await _processWrapper.run('git', [
        'log',
        '-1',
        '--format=%ct',
      ], workingDirectory: path);
      if (result.exitCode != 0) {
        return null;
      }
      final timestamp = int.tryParse((result.stdout as String).trim());
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String> getRepoRoot() async {
    final result = await _processWrapper.run('git', [
      'rev-parse',
      '--show-toplevel',
    ]);
    if (result.exitCode != 0) {
      throw GitException('git', [
        'rev-parse',
        '--show-toplevel',
      ], result.stderr as String);
    }
    return (result.stdout as String).trim();
  }

  @override
  Future<bool> isWorktree() async {
    try {
      // Get the worktree root directory
      final repoRoot = await getRepoRoot();
      // Check if .git in the worktree root is a file (worktree) or directory (main repo)
      final gitFile = File('$repoRoot/.git');
      if (await gitFile.exists()) {
        final stat = await gitFile.stat();
        return stat.type == FileSystemEntityType.file;
      }
      return false;
    } catch (e) {
      return false; // Not in a git repository
    }
  }

  @override
  Future<String> getMainRepoPath() async {
    final result = await _processWrapper.run('git', ['rev-parse', '--git-dir']);
    _printOutput(result);
    if (result.exitCode != 0) {
      throw GitException('git', [
        'status',
        '--porcelain',
      ], result.stderr as String);
    }
    final gitDir = (result.stdout as String).trim();
    if (gitDir.endsWith('.git')) {
      // This is the main repo
      return Directory.current.path;
    } else {
      // This is a worktree, .git file contains path to main .git
      final gitFile = File('.git');
      if (await gitFile.exists()) {
        final content = await gitFile.readAsString();
        final gitPath = content.split(': ').last.trim();
        return Directory(gitPath).parent.parent.parent.path;
      }
    }
    throw GitException('git', [
      'rev-parse',
      '--git-dir',
    ], 'Unable to determine main repository path');
  }

  @override
  Future<List<String>> listBranches() async {
    final result = await _processWrapper.run('git', [
      'branch',
      '--format=%(refname:short)',
    ]);
    _printOutput(result);
    if (result.exitCode != 0) {
      throw GitException('git', [
        'branch',
        '--format=%(refname:short)',
      ], result.stderr as String);
    }
    final output = result.stdout as String;
    return output
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  @override
  Future<bool> remoteBranchExists(String branch) async {
    final result = await _processWrapper.run('git', [
      'branch',
      '-r',
      '--list',
      'origin/$branch',
    ]);
    _printOutput(result);
    if (result.exitCode != 0) {
      throw GitException('git', [
        'branch',
        '-r',
        '--list',
        'origin/$branch',
      ], result.stderr as String);
    }
    return (result.stdout as String).trim().isNotEmpty;
  }

  @override
  Future<void> setUpstreamBranch(String branch) async {
    final result = await _processWrapper.run('git', [
      'branch',
      '--set-upstream-to=origin/$branch',
      branch,
    ]);
    _printOutput(result);
    if (result.exitCode != 0) {
      throw GitException('git', [
        'branch',
        '--set-upstream-to=origin/$branch',
        branch,
      ], result.stderr as String);
    }
  }

  void _printOutput(ProcessResult result) {
    if (result.stderr.isNotEmpty) {
      printSafe(result.stderr);
    }
  }

  Future<List<Worktree>> _parseWorktreeList(String output) async {
    final lines = output.split('\n').where((line) => line.isNotEmpty);
    final worktrees = <Worktree>[];
    String? worktreePath;
    String? branch;
    bool isMain = false;

    for (final line in lines) {
      if (line.startsWith('worktree ')) {
        // Finish previous worktree if exists
        if (worktreePath != null && branch != null) {
          final name = branch == 'HEAD' ? 'detached' : branch.split('/').last;
          final status = branch == 'HEAD'
              ? WorktreeStatus.detached
              : await getBranchStatus(branch, worktreePath);
          final lastModified = await getLastCommitTime(worktreePath);
          worktrees.add(
            Worktree(
              name: name,
              branch: branch,
              path: worktreePath,
              isMain: isMain,
              status: status,
              lastModified: lastModified,
            ),
          );
        }
        worktreePath = line.substring('worktree '.length);
        branch = null;
        isMain = worktrees.isEmpty; // First one is main
      } else if (line.startsWith('branch ')) {
        branch = line.substring('branch refs/heads/'.length);
      } else if (line.startsWith('HEAD ')) {
        branch ??= 'HEAD';
      }
    }
    // Add the last worktree
    if (worktreePath != null && branch != null) {
      final name = branch == 'HEAD' ? 'detached' : branch.split('/').last;
      final status = branch == 'HEAD'
          ? WorktreeStatus.detached
          : await getBranchStatus(branch, worktreePath);
      final lastModified = await getLastCommitTime(worktreePath);
      worktrees.add(
        Worktree(
          name: name,
          branch: branch,
          path: worktreePath,
          isMain: isMain,
          status: status,
          lastModified: lastModified,
        ),
      );
    }
    return worktrees;
  }
}
