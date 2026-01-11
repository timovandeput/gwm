import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';

/// Command for adding a new Git worktree.
///
/// Usage: gwt add `<branch>` [options]
class AddCommand extends BaseCommand {
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

    // TODO: Implement actual worktree creation logic
    // For now, just print what would be done
    print('Adding worktree for branch: $branch');
    if (createBranch) {
      print('Will create branch if it does not exist.');
    }

    return ExitCode.success;
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
