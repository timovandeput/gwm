import 'dart:io';

import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';
import '../infrastructure/git_client.dart';
import '../infrastructure/git_client_impl.dart';
import '../infrastructure/process_wrapper_impl.dart';
import '../services/config_service.dart';
import '../cli_utils.dart';

/// Command for cleaning up the current Git worktree.
///
/// Usage: gwm clean [options]
class CleanCommand extends BaseCommand {
  final GitClient _gitClient;
  final ConfigService _configService;

  CleanCommand({
    GitClient? gitClient,
    ConfigService? configService,
    super.skipEvalCheck = false,
  }) : _gitClient = gitClient ?? GitClientImpl(ProcessWrapperImpl()),
       _configService = configService ?? ConfigService();

  @override
  ArgParser get parser {
    return ArgParser()
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Force removal without confirmation prompts.',
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
      // Validate we're in a Git repository
      final isWorktree = await _gitClient.isWorktree();
      if (!isWorktree) {
        printSafe('Error: gwm clean can only be run from within a worktree.');
        printSafe('Use "gwm switch ." to go to the main repository.');
        return ExitCode.invalidArguments;
      }

      final currentPath = Directory.current.path;
      final repoRoot = await _gitClient.getRepoRoot();

      // Check for uncommitted changes
      final hasChanges = await _gitClient.hasUncommittedChanges(currentPath);
      if (hasChanges && !force) {
        printSafe('Uncommitted changes detected in worktree at: $currentPath');
        stdout.write('Continue with removal? (y/N): ');
        final response = stdin.readLineSync()?.toLowerCase().trim();
        if (response != 'y' && response != 'yes') {
          printSafe('Operation cancelled.');
          return ExitCode.success;
        }
      }

      // Load configuration for hooks
      final config = await _configService.loadConfig(repoRoot: repoRoot);

      // Execute pre_clean hooks (placeholder - hooks not yet implemented)
      if (config.hooks.preClean != null) {
        printSafe('Executing pre-clean hooks...');
        // TODO: Implement hook execution service
        // await _hookService.executeHooks(config.hooks.preClean!, environment);
      }

      // Get main repo path for navigation after cleanup
      final mainRepoPath = await _gitClient.getMainRepoPath();

      // Remove the worktree using Git
      printSafe('Removing worktree: $currentPath');
      await _gitClient.removeWorktree(currentPath);

      // Execute post_clean hooks (placeholder - hooks not yet implemented)
      if (config.hooks.postClean != null) {
        printSafe('Executing post-clean hooks...');
        // TODO: Implement hook execution service
        // await _hookService.executeHooks(config.hooks.postClean!, environment);
      }

      // Change to main repository directory
      // Note: In production, this would change the working directory
      // Directory.current = mainRepoPath;
      printSafe('Would return to main repository: $mainRepoPath');
      printSafe('Worktree successfully removed.');

      return ExitCode.success;
    } catch (e) {
      printSafe('Error: Failed to remove worktree: $e');
      return ExitCode.gitFailed;
    }
  }
}
