import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';
import '../services/worktree_service.dart';
import '../services/config_service.dart';
import '../infrastructure/git_client.dart';
import '../infrastructure/git_client_impl.dart';
import '../infrastructure/process_wrapper_impl.dart';
import '../services/shell_integration.dart';
import '../models/config.dart';
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

  AddCommand({
    WorktreeService? worktreeService,
    ConfigService? configService,
    GitClient? gitClient,
    ShellIntegration? shellIntegration,
    Config? config,
    super.skipEvalCheck = false,
  }) : _worktreeService =
           worktreeService ??
           WorktreeService(gitClient ?? GitClientImpl(ProcessWrapperImpl())),
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
        if (exitCode == ExitCode.success) {
          _shellIntegration.outputWorktreeCreated(worktreePath);
        } else {
          // Worktree already exists, output switch message
          _shellIntegration.outputCdCommand(worktreePath);
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
