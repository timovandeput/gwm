import 'dart:io';

import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';
import '../infrastructure/git_client.dart';
import '../infrastructure/git_client_impl.dart';
import '../infrastructure/process_wrapper_impl.dart';
import '../services/config_service.dart';
import '../services/shell_integration.dart';
import '../models/config.dart';
import '../utils/eval_validator.dart';
import '../exceptions.dart';
import '../cli_utils.dart';

/// Command for cleaning up the current Git worktree.
///
/// Usage: gwm clean [options]
class CleanCommand extends BaseCommand {
  final GitClient _gitClient;
  final ConfigService _configService;
  final ShellIntegration _shellIntegration;

  CleanCommand({
    GitClient? gitClient,
    ConfigService? configService,
    ShellIntegration? shellIntegration,
    Config? config,
    super.skipEvalCheck = false,
  }) : _gitClient = gitClient ?? GitClientImpl(ProcessWrapperImpl()),
       _configService = configService ?? ConfigService(),
       _shellIntegration =
           shellIntegration ??
           ShellIntegration(
             config?.shellIntegration ??
                 ShellIntegrationConfig(enableEvalOutput: true),
           );

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

      // Execute pre_clean hooks (placeholder - hooks not yet implemented)
      if (config.hooks.preClean != null) {
        printSafe('Executing pre-clean hooks...');
        // TODO: Implement hook execution service
        // await _hookService.executeHooks(config.hooks.preClean!, environment);
      }

      // Get main repo path for navigation after cleanup
      final mainRepoPath = await _gitClient.getMainRepoPath();

      // Remove the worktree using Git
      printSafe('Removing worktree: $repoRoot');
      await _gitClient.removeWorktree(repoRoot);

      // Execute post_clean hooks (placeholder - hooks not yet implemented)
      if (config.hooks.postClean != null) {
        printSafe('Executing post-clean hooks...');
        // TODO: Implement hook execution service
        // await _hookService.executeHooks(config.hooks.postClean!, environment);
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
