import 'dart:io';

import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';
import '../services/worktree_service.dart';
import '../services/config_service.dart';
import '../services/hook_service.dart';

import '../infrastructure/git_client_impl.dart';
import '../infrastructure/process_wrapper_impl.dart';
import '../services/shell_integration.dart';
import '../utils/eval_validator.dart';
import '../exceptions.dart';
import '../cli_utils.dart';

/// Command for adding a new Git worktree.
///
/// Usage: gwm add `<branch>` [options]
class AddCommand extends BaseCommand {
  final WorktreeService _worktreeService;
  final ConfigService _configService;
  final ShellIntegration _shellIntegration;
  final HookService _hookService;

  AddCommand(
    this._worktreeService,
    this._configService,
    this._shellIntegration,
    this._hookService, {
    super.skipEvalCheck = false,
  });
  @override
  ArgParser get parser {
    return ArgParser()
      ..addFlag(
        'create-branch',
        abbr: 'b',
        help: 'Create the branch if it does not exist.',
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
        'add <branch> [options]',
        'Add a new Git worktree for the specified branch.',
        parser,
      );
      return ExitCode.success;
    }

    final args = results.rest;
    if (args.isEmpty) {
      printSafe('Error: Branch name is required.');
      printSafe('Usage: gwm add <branch> [options]');
      return ExitCode.invalidArguments;
    }

    final branch = args[0];
    final createBranch = results.flag('create-branch');

    try {
      // Validate we're in eval wrapper
      EvalValidator.validate(skipCheck: skipEvalCheck);

      // Load configuration for hooks and other settings
      final repoRoot = await _getRepoRoot();
      final config = await _configService.loadConfig(repoRoot: repoRoot);

      // Use the worktree service to create the worktree
      final exitCode = await _worktreeService.addWorktree(
        branch,
        createBranch: createBranch,
        config: config,
      );

      // If worktree was created or already exists (and we're switching to it), navigate to it
      if (exitCode == ExitCode.success ||
          exitCode == ExitCode.worktreeExistsButSwitched) {
        final worktreePath = await _worktreeService.getWorktreePath(branch);
        final originPath = await _getRepoRoot() ?? Directory.current.path;

        if (exitCode == ExitCode.success) {
          _shellIntegration.outputWorktreeCreated(worktreePath);
        } else {
          // Worktree already exists, execute switch hooks and output switch message
          // Execute pre-switch hooks
          if (config.hooks.preSwitch != null) {
            try {
              await _hookService.executePreSwitch(
                config.hooks,
                worktreePath,
                originPath,
                branch,
              );
            } catch (e) {
              printSafe('Error: Pre-switch hook failed: $e');
              return ExitCode.hookFailed;
            }
          }

          _shellIntegration.outputCdCommand(worktreePath);

          // Execute post-switch hooks
          if (config.hooks.postSwitch != null) {
            try {
              await _hookService.executePostSwitch(
                config.hooks,
                worktreePath,
                originPath,
                branch,
              );
            } catch (e) {
              printSafe('Error: Post-switch hook failed: $e');
              return ExitCode.hookFailed;
            }
          }

          printSafe('Switched to existing worktree: $worktreePath');
        }
      }

      return exitCode;
    } on ShellWrapperMissingException catch (e) {
      printSafe(e.message);
      return e.exitCode;
    } catch (e) {
      printSafe('Error: Failed to create worktree: $e');
      return ExitCode.gitFailed;
    }
  }

  /// Gets the repository root directory.
  ///
  /// Returns the current directory if not in a git repo (for error handling).
  Future<String?> _getRepoRoot() async {
    try {
      final gitClient = GitClientImpl(ProcessWrapperImpl());
      return await gitClient.getRepoRoot();
    } catch (e) {
      // If not in a git repo, return null - config will use global only
      return null;
    }
  }

  @override
  ExitCode validate(ArgResults results) {
    final args = results.rest;
    if (args.length > 1) {
      printSafe('Error: Too many arguments. Expected exactly one branch name.');
      return ExitCode.invalidArguments;
    }
    return ExitCode.success;
  }
}
