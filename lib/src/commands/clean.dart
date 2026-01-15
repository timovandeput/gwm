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

/// Command for cleaning up the current Git worktree.
///
/// Usage: gwm clean [options]
class CleanCommand extends BaseCommand {
  final GitClient _gitClient;
  final ConfigService _configService;
  final HookService _hookService;
  final ShellIntegration _shellIntegration;

  CleanCommand(
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
        'clean [options]',
        'Delete the current worktree and return to the main repository.',
        parser,
      );
      return ExitCode.success;
    }

    final force = results.flag('force');

    try {
      // Validate we're in eval wrapper
      EvalValidator.validate(skipCheck: skipEvalCheck);

      final isWorktree = await _gitClient.isWorktree();
      if (!isWorktree) {
        // Check if we're in a git repository at all
        try {
          await _gitClient.getRepoRoot();
          printSafe('Error: gwm clean can only be run from within a worktree.');
        } catch (e) {
          printSafe('Error: Not in a Git repository.');
        }
        return ExitCode.invalidArguments;
      }

      final repoRoot = await _gitClient.getRepoRoot();

      // Load configuration for hooks
      final config = await _configService.loadConfig(repoRoot: repoRoot);

      // Check for uncommitted changes
      final hasChanges = await _gitClient.hasUncommittedChanges(repoRoot);
      if (hasChanges && !force) {
        printSafe(
          'Error: Uncommitted changes detected in worktree at: $repoRoot',
        );
        printSafe('Use --force to skip confirmation and proceed with removal.');
        return ExitCode.invalidArguments;
      }

      // Get branch name for hooks
      final branch = await _gitClient.getCurrentBranch();

      // Execute pre-clean hooks
      if (config.hooks.preClean != null) {
        try {
          await _hookService.executePreClean(
            config.hooks,
            repoRoot,
            repoRoot, // origin path is the same as worktree path for clean
            branch,
          );
        } catch (e) {
          printSafe('Error: Pre-clean hook failed: $e');
          return ExitCode.hookFailed;
        }
      }

      // Get main repo path for navigation after cleanup
      final mainRepoPath = await _gitClient.getMainRepoPath();

      // Remove the worktree using Git
      printSafe('Removing worktree: $repoRoot');
      await _gitClient.removeWorktree(repoRoot, force: force);

      // Execute post-clean hooks
      if (config.hooks.postClean != null) {
        try {
          await _hookService.executePostClean(
            config.hooks,
            repoRoot,
            repoRoot, // origin path
            branch,
          );
        } catch (e) {
          printSafe('Error: Post-clean hook failed: $e');
          return ExitCode.hookFailed;
        }
      }

      // Change to main repository directory
      _shellIntegration.outputCdCommand(mainRepoPath);
      printSafe('Worktree successfully removed.');

      return ExitCode.success;
    } on ShellWrapperMissingException catch (e) {
      printSafe(e.message);
      return e.exitCode;
    } catch (e) {
      printSafe('Error: Failed to remove worktree: $e');
      return ExitCode.gitFailed;
    }
  }
}
