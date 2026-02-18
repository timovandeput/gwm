import 'dart:io';

import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';
import '../services/worktree_service.dart';
import '../services/config_service.dart';
import '../services/hook_service.dart';

import '../infrastructure/git_client.dart';
import '../services/shell_integration.dart';
import '../utils/eval_validator.dart';
import '../utils/path_utils.dart' show getRepoRootOrNull;
import '../exceptions.dart';
import '../cli_utils.dart';

/// Command for creating a new Git worktree.
///
/// Usage: gwm create `<branch>` [options]
class CreateCommand extends BaseCommand {
  final WorktreeService _worktreeService;
  final ConfigService _configService;
  final ShellIntegration _shellIntegration;
  final HookService _hookService;
  final GitClient _gitClient;

  CreateCommand(
    this._worktreeService,
    this._configService,
    this._shellIntegration,
    this._hookService,
    this._gitClient, {
    super.skipEvalCheck = false,
  });

  static ArgParser buildArgParser() {
    return ArgParser()
      ..addFlag(
        'branch',
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
  ArgParser get parser => buildArgParser();

  @override
  Future<ExitCode> execute(ArgResults results) async {
    if (results.flag('help')) {
      printCommandUsage(
        'create <branch> [options]',
        'Create a new Git worktree for the specified branch.',
        parser,
      );
      return ExitCode.success;
    }

    final args = results.rest;
    if (args.isEmpty) {
      printSafe('Error: Branch name is required.');
      printSafe('Usage: gwm create <branch> [options]');
      return ExitCode.invalidArguments;
    }

    final branch = args[0];
    final createBranch = results.flag('branch');

    try {
      // Validate we're in eval wrapper
      EvalValidator.validate(skipCheck: skipEvalCheck);

      // Load configuration for hooks and other settings
      final repoRoot = await getRepoRootOrNull(_gitClient);
      final config = await _configService.loadConfig(repoRoot: repoRoot);

      // Use the worktree service to create the worktree
      final exitCode = await _worktreeService.createWorktree(
        branch,
        createBranch: createBranch,
        config: config,
      );

      // If worktree was created or already exists (and we're switching to it), navigate to it
      if (exitCode == ExitCode.success ||
          exitCode == ExitCode.worktreeExistsButSwitched) {
        final worktreePath = await _worktreeService.getWorktreePath(branch);
        final originPath =
            await getRepoRootOrNull(_gitClient) ?? Directory.current.path;

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
    } on GwmException catch (e) {
      printSafe(e.message);
      return e.exitCode;
    } catch (e) {
      printSafe('Unexpected error: Failed to create worktree: $e');
      return ExitCode.generalError;
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
