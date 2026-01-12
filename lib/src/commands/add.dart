import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';
import '../services/worktree_service.dart';
import '../infrastructure/git_client.dart';
import '../infrastructure/git_client_impl.dart';
import '../infrastructure/process_wrapper_impl.dart';

/// Command for adding a new Git worktree.
///
/// Usage: gwt add `<branch>` [options]
class AddCommand extends BaseCommand {
  final WorktreeService _worktreeService;

  AddCommand({WorktreeService? worktreeService, GitClient? gitClient})
    : _worktreeService =
          worktreeService ??
          WorktreeService(gitClient ?? GitClientImpl(ProcessWrapperImpl()));

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

    // Use the worktree service to create the worktree
    return await _worktreeService.addWorktree(
      branch,
      createBranch: createBranch,
    );
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
