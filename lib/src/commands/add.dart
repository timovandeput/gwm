import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';
import '../services/worktree_service.dart';
import '../infrastructure/git_client.dart';
import '../infrastructure/git_client_impl.dart';
import '../infrastructure/process_wrapper_impl.dart';
import '../services/shell_integration.dart';
import '../models/config.dart';
import '../utils/eval_validator.dart';
import '../exceptions.dart';

/// Command for adding a new Git worktree.
///
/// Usage: gwt add `<branch>` [options]
class AddCommand extends BaseCommand {
  final WorktreeService _worktreeService;
  final ShellIntegration _shellIntegration;

  AddCommand({
    WorktreeService? worktreeService,
    GitClient? gitClient,
    ShellIntegration? shellIntegration,
    Config? config,
    super.skipEvalCheck = false,
  }) : _worktreeService =
           worktreeService ??
           WorktreeService(gitClient ?? GitClientImpl(ProcessWrapperImpl())),
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
      print('Usage: gwt add <branch> [options]');
      print('');
      print('Add a new Git worktree for the specified branch.');
      print('');
      print(parser.usage);
      return ExitCode.success;
    }

    final args = results.rest;
    if (args.isEmpty) {
      print('Error: Branch name is required.');
      print('Usage: gwt add <branch> [options]');
      return ExitCode.invalidArguments;
    }

    final branch = args[0];
    final createBranch = results.flag('create-branch');

    try {
      // Validate we're in eval wrapper
      EvalValidator.validate(skipCheck: skipEvalCheck);

      // Use the worktree service to create the worktree
      final exitCode = await _worktreeService.addWorktree(
        branch,
        createBranch: createBranch,
      );

      // If worktree was created, navigate to it
      if (exitCode == ExitCode.success) {
        final worktreePath = await _worktreeService.getWorktreePath(branch);
        _shellIntegration.outputWorktreeCreated(worktreePath);
      }

      return exitCode;
    } on ShellWrapperMissingException catch (e) {
      print(e.message);
      return e.exitCode;
    } catch (e) {
      print('Error: Failed to create worktree: $e');
      return ExitCode.gitFailed;
    }
  }

  @override
  ExitCode validate(ArgResults results) {
    final args = results.rest;
    if (args.length > 1) {
      print('Error: Too many arguments. Expected exactly one branch name.');
      return ExitCode.invalidArguments;
    }
    return ExitCode.success;
  }
}
