import 'dart:async';
import 'dart:io';

import 'git_client.dart';
import 'process_wrapper.dart';
import '../models/worktree.dart';
import '../cli_utils.dart';

/// Implementation of GitClient using ProcessWrapper for Git operations.
class GitClientImpl implements GitClient {
  final ProcessWrapper _processWrapper;

  GitClientImpl(this._processWrapper);

  @override
  Future<void> createBranch(String name) async {
    final result = await _processWrapper.run('git', ['branch', name]);
    _printOutput(result);
    if (result.exitCode != 0) {
      throw Exception('Git command failed: git branch $name');
    }
  }

  @override
  Future<String> createWorktree(String path, String branch) async {
    final result = await _processWrapper.run('git', [
      'worktree',
      'add',
      path,
      branch,
    ]);
    _printOutput(result);
    if (result.exitCode != 0) {
      throw Exception('Git command failed: git worktree add $path $branch');
    }
    return path;
  }

  @override
  Future<List<Worktree>> listWorktrees() async {
    final result = await _processWrapper.run('git', [
      'worktree',
      'list',
      '--porcelain',
    ]);
    _printOutput(result);
    if (result.exitCode != 0) {
      throw Exception('Git command failed: git worktree list --porcelain');
    }
    return _parseWorktreeList(result.stdout as String);
  }

  @override
  Future<void> removeWorktree(String path) async {
    final result = await _processWrapper.run('git', [
      'worktree',
      'remove',
      path,
    ]);
    _printOutput(result);
    if (result.exitCode != 0) {
      throw Exception('Git command failed: git worktree remove $path');
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
      throw Exception('Git command failed: git branch --show-current');
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
      throw Exception('Git command failed: git branch --list $branch');
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
      throw Exception('Git command failed: git status --porcelain');
    }
    return (result.stdout as String).trim().isNotEmpty;
  }

  @override
  Future<String> getBranchStatus(String branch) async {
    // TODO: Implement branch status checking
    // This might involve comparing with remote, etc.
    // For now, return 'unknown'
    return 'unknown';
  }

  @override
  Future<String> getRepoRoot() async {
    final result = await _processWrapper.run('git', [
      'rev-parse',
      '--show-toplevel',
    ]);
    _printOutput(result);
    if (result.exitCode != 0) {
      throw Exception('Git command failed: git rev-parse --show-toplevel');
    }
    return (result.stdout as String).trim();
  }

  @override
  Future<bool> isWorktree() async {
    final result = await _processWrapper.run('git', [
      'rev-parse',
      '--is-inside-work-tree',
    ]);
    _printOutput(result);
    if (result.exitCode != 0) {
      return false; // Not in a git repository
    }
    // Check if .git is a file (worktree) or directory (main repo)
    final gitDir = File('.git');
    if (await gitDir.exists()) {
      return await gitDir.stat().then(
        (stat) => stat.type == FileSystemEntityType.file,
      );
    }
    return false;
  }

  @override
  Future<String> getMainRepoPath() async {
    final result = await _processWrapper.run('git', ['rev-parse', '--git-dir']);
    _printOutput(result);
    if (result.exitCode != 0) {
      throw Exception('Git command failed: git rev-parse --git-dir');
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
        return Directory(gitPath).parent.parent.path;
      }
    }
    throw Exception('Unable to determine main repository path');
  }

  void _printOutput(ProcessResult result) {
    if (result.stdout.isNotEmpty) {
      printSafe(result.stdout);
    }
    if (result.stderr.isNotEmpty) {
      printSafe(result.stderr);
    }
  }

  List<Worktree> _parseWorktreeList(String output) {
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
          worktrees.add(
            Worktree(
              name: name,
              branch: branch,
              path: worktreePath,
              isMain: isMain,
              status: WorktreeStatus.clean, // TODO: Determine actual status
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
      worktrees.add(
        Worktree(
          name: name,
          branch: branch,
          path: worktreePath,
          isMain: isMain,
          status: WorktreeStatus.clean,
        ),
      );
    }
    return worktrees;
  }
}
