import 'dart:async';

import '../models/worktree.dart';

/// Interface for Git operations.
///
/// This abstraction allows for different implementations in production code
/// (using actual Git CLI) and test code (using mock implementations).
abstract class GitClient {
  /// Creates a new worktree at the specified path for the given branch.
  ///
  /// [from] optionally specifies the commit/branch to create the new branch from.
  /// When [createBranch] is true and [from] is provided, the new branch will be
  /// created starting from [from] instead of the current HEAD.
  Future<String> createWorktree(
    String path,
    String branch, {
    bool createBranch = false,
    String? from,
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

  /// Lists all available Git branches.
  Future<List<String>> listBranches();

  /// Checks if a remote branch with the given name exists.
  Future<bool> remoteBranchExists(String branch);

  /// Sets up tracking for a local branch to a remote branch.
  Future<void> setUpstreamBranch(String branch);
}
