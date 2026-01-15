import 'dart:async';

import '../models/worktree.dart';

/// Interface for Git operations.
///
/// This abstraction allows for different implementations in production code
/// (using actual Git CLI) and test code (using mock implementations).
abstract class GitClient {
  /// Creates a new worktree at the specified path for the given branch.
  Future<String> createWorktree(
    String path,
    String branch, {
    bool createBranch = false,
  });

  /// Lists all worktrees in the repository.
  Future<List<Worktree>> listWorktrees();

  /// Removes the worktree at the specified path.
  /// [force] - If true, forces removal even if the worktree contains modified files.
  Future<void> removeWorktree(String path, {bool force = false});

  /// Gets the name of the currently checked out branch.
  Future<String> getCurrentBranch();

  /// Checks if a branch with the given name exists.
  Future<bool> branchExists(String branch);

  /// Checks if there are uncommitted changes in the worktree at the given path.
  Future<bool> hasUncommittedChanges(String path);

  /// Gets the status of a branch (e.g., ahead, behind, modified).
  Future<WorktreeStatus> getBranchStatus(String branch, String path);

  /// Gets the last commit time for the current branch in the worktree.
  Future<DateTime?> getLastCommitTime(String path);

  /// Gets the root directory of the Git repository.
  Future<String> getRepoRoot();

  /// Checks if the current directory is a Git worktree (not the main repository).
  Future<bool> isWorktree();

  /// Gets the path to the main Git repository (common .git directory).
  Future<String> getMainRepoPath();
}
