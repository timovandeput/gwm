import 'dart:io';

import '../infrastructure/git_client.dart';
import '../models/exit_codes.dart';
import '../utils/path_utils.dart';
import '../cli_utils.dart';

/// Service for managing Git worktrees.
///
/// This service handles the creation, validation, and management of Git worktrees
/// with proper path resolution and error handling.
class WorktreeService {
  final GitClient _gitClient;

  WorktreeService(this._gitClient);

  /// Adds a new worktree for the specified branch.
  ///
  /// [branch] is the name of the Git branch to create the worktree for.
  /// [createBranch] if true, creates the branch if it doesn't exist.
  ///
  /// Returns the exit code indicating success or the type of failure.
  Future<ExitCode> addWorktree(
    String branch, {
    bool createBranch = false,
  }) async {
    try {
      // Validate that we're running from the main repository
      if (await _gitClient.isWorktree()) {
        printSafe('Error: Must run from main Git repository, not a worktree');
        return ExitCode.generalError;
      }

      // Check if branch exists (unless createBranch is true)
      if (!createBranch && !await _gitClient.branchExists(branch)) {
        printSafe('Error: Branch "$branch" does not exist');
        return ExitCode.branchNotFound;
      }

      // Determine worktree path
      final worktreePath = await _resolveWorktreePath(branch);
      final worktreeDir = Directory(worktreePath);

      // Check if worktree already exists
      if (await worktreeDir.exists()) {
        printSafe(
          'Warning: Worktree already exists at $worktreePath, switching to it',
        );
        return ExitCode.worktreeExistsButSwitched;
      }

      // If createBranch is true and branch doesn't exist, create it along with worktree
      // If createBranch is false, assume branch exists
      final shouldCreateBranch =
          createBranch && !await _gitClient.branchExists(branch);

      // Ensure parent directory exists
      final parentDir = worktreeDir.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      // Create the worktree
      final actualPath = await _gitClient.createWorktree(
        worktreePath,
        branch,
        createBranch: shouldCreateBranch,
      );

      // Verify the worktree was created successfully
      if (!await Directory(actualPath).exists()) {
        stderr.writeln('Error: Failed to create worktree at $actualPath');
        return ExitCode.gitFailed;
      }

      printSafe(
        'Successfully created worktree for branch "$branch" at $actualPath',
      );
      return ExitCode.success;
    } catch (e) {
      printSafe('Error: Failed to create worktree: $e');
      return ExitCode.gitFailed;
    }
  }

  /// Resolves the path where the worktree should be created.
  ///
  /// The path follows the pattern: `<parent-dir>/worktrees/<repo-name>_<branch-name>/`
  ///
  /// [branch] is the name of the branch for which to create the worktree.
  Future<String> _resolveWorktreePath(String branch) async {
    final repoRoot = await _gitClient.getRepoRoot();
    final repoName = PathUtils.basename(repoRoot);

    // Sanitize branch name for filesystem (replace / with _)
    final sanitizedBranch = branch.replaceAll('/', '_');

    // Get parent directory (directory containing the repo)
    final parentDir = PathUtils.dirname(repoRoot);

    // Construct worktree path
    final worktreePath = PathUtils.join([
      parentDir,
      'worktrees',
      '${repoName}_$sanitizedBranch',
    ]);

    return PathUtils.normalize(worktreePath);
  }

  /// Gets the path for a worktree with the given branch name.
  ///
  /// [branch] is the name of the branch.
  /// Returns the resolved worktree path.
  Future<String> getWorktreePath(String branch) async {
    return await _resolveWorktreePath(branch);
  }
}
