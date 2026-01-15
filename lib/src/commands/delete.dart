import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';
import '../infrastructure/git_client.dart';
import '../services/config_service.dart';
import '../services/hook_service.dart';
import '../services/shell_integration.dart';
import '../utils/eval_validator.dart';
import '../exceptions.dart';
import '../cli_utils.dart';

/// Command for deleting Git worktrees.
///
/// Usage: gwm delete [worktree-name] [options]
class DeleteCommand extends BaseCommand {
  final GitClient _gitClient;
  final ConfigService _configService;
  final HookService _hookService;
  final ShellIntegration _shellIntegration;

  DeleteCommand(
    this._gitClient,
    this._configService,
    this._hookService,
    this._shellIntegration, {
    super.skipEvalCheck = false,
  });

  @override
  ArgParser get parser {
    return ArgParser()
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Force removal when uncommitted changes exist.',
      )
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Print usage information for this command.',
      );
  }

  @override
  Future<ExitCode> execute(ArgResults results) async {
    if (results.flag('help')) {
      printCommandUsage(
        'delete [worktree-name] [options]',
        'Delete the specified worktree, or the current worktree if no name is provided.\n'
            'Can only delete worktrees from the main workspace. Cannot delete the main workspace.',
        parser,
      );
      return ExitCode.success;
    }

    final force = results.flag('force');
    final args = results.rest;
    final worktreeName = args.isNotEmpty ? args[0] : null;

    try {
      // Validate we're in eval wrapper
      EvalValidator.validate(skipCheck: skipEvalCheck);

      final isWorktree = await _gitClient.isWorktree();

      if (worktreeName != null) {
        // Deleting a named worktree - must be run from main workspace
        if (isWorktree) {
          printSafe(
            'Error: Cannot delete named worktrees from within a worktree. '
            'Run this command from the main workspace.',
          );
          return ExitCode.invalidArguments;
        }

        // Find the worktree to delete
        final worktrees = await _gitClient.listWorktrees();
        final targetWorktree = worktrees.firstWhere(
          (w) => w.name == worktreeName,
          orElse: () => throw StateError('Worktree "$worktreeName" not found'),
        );

        // Cannot delete the main workspace
        if (targetWorktree.isMain) {
          printSafe('Error: Cannot delete the main workspace.');
          return ExitCode.invalidArguments;
        }

        return await _deleteWorktree(
          targetWorktree.path,
          targetWorktree.branch,
          force,
          isCurrentWorktree: false,
        );
      } else {
        // Deleting current worktree - must be run from within a worktree
        if (!isWorktree) {
          // Check if we're in a git repository at all
          try {
            await _gitClient.getRepoRoot();
            printSafe(
              'Error: gwm delete can only be run from within a worktree when no worktree name is specified.',
            );
          } catch (e) {
            printSafe('Error: Not in a Git repository.');
          }
          return ExitCode.invalidArguments;
        }

        final repoRoot = await _gitClient.getRepoRoot();
        final branch = await _gitClient.getCurrentBranch();
        return await _deleteWorktree(
          repoRoot,
          branch,
          force,
          isCurrentWorktree: true,
        );
      }
    } on ShellWrapperMissingException catch (e) {
      printSafe(e.message);
      return e.exitCode;
    } catch (e) {
      printSafe('Error: Failed to remove worktree: $e');
      return ExitCode.gitFailed;
    }
  }

  @override
  ExitCode validate(ArgResults results) {
    final args = results.rest;
    if (args.length > 1) {
      printSafe(
        'Error: Too many arguments. Expected at most one worktree name.',
      );
      return ExitCode.invalidArguments;
    }
    return ExitCode.success;
  }

  /// Deletes a worktree at the specified path.
  ///
  /// [worktreePath] is the path to the worktree to delete.
  /// [branch] is the branch associated with the worktree.
  /// [force] if true, forces removal even if uncommitted changes exist.
  Future<ExitCode> _deleteWorktree(
    String worktreePath,
    String branch,
    bool force, {
    bool isCurrentWorktree = false,
  }) async {
    // For named worktree deletion, config should be loaded from main repo
    // For current worktree deletion, config is loaded from current repo
    final configRepoRoot = isCurrentWorktree
        ? worktreePath
        : await _gitClient.getMainRepoPath();

    // Load configuration for hooks
    final config = await _configService.loadConfig(repoRoot: configRepoRoot);

    // Check for uncommitted changes
    final hasChanges = await _gitClient.hasUncommittedChanges(worktreePath);
    if (hasChanges && !force) {
      printSafe(
        'Error: Uncommitted changes detected in worktree at: $worktreePath',
      );
      printSafe('Use --force to skip confirmation and proceed with removal.');
      return ExitCode.invalidArguments;
    }

    // Execute pre-delete hooks
    if (config.hooks.preDelete != null) {
      try {
        await _hookService.executePreDelete(
          config.hooks,
          worktreePath,
          worktreePath, // origin path is the same as worktree path for delete
          branch,
        );
      } catch (e) {
        printSafe('Error: Pre-delete hook failed: $e');
        return ExitCode.hookFailed;
      }
    }

    // Get main repo path for navigation after delete
    final mainRepoPath = await _gitClient.getMainRepoPath();

    // Remove the worktree using Git
    printSafe('Removing worktree: $worktreePath');
    await _gitClient.removeWorktree(worktreePath, force: force);

    // Execute post-delete hooks
    if (config.hooks.postDelete != null) {
      try {
        await _hookService.executePostDelete(
          config.hooks,
          worktreePath,
          mainRepoPath, // origin path
          branch,
        );
      } catch (e) {
        printSafe('Error: Post-delete hook failed: $e');
        return ExitCode.hookFailed;
      }
    }

    // Change to main repository directory (only when deleting current worktree)
    if (isCurrentWorktree) {
      _shellIntegration.outputCdCommand(mainRepoPath);
    }
    printSafe('Worktree successfully removed.');

    return ExitCode.success;
  }
}
