import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';

/// Command for switching to an existing Git worktree.
///
/// Usage: gwt switch [worktree-name]
class SwitchCommand extends BaseCommand {
  @override
  ArgParser get parser {
    return ArgParser()..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print usage information for this command.',
    );
  }

  @override
  Future<ExitCode> execute(ArgResults results) async {
    if (results.flag('help')) {
      print('Usage: gwt switch [worktree-name]');
      print('');
      print('Switch to the specified worktree. If no worktree is specified,');
      print('lists available worktrees for selection.');
      print('');
      print(parser.usage);
      return ExitCode.success;
    }

    final args = results.rest;
    final worktreeName = args.isNotEmpty ? args[0] : null;

    // TODO: Implement actual worktree switching logic
    // For now, just print what would be done
    if (worktreeName != null) {
      print('Switching to worktree: $worktreeName');
    } else {
      print('No worktree specified. Would show interactive selection.');
    }

    return ExitCode.success;
  }

  @override
  ExitCode validate(ArgResults results) {
    final args = results.rest;
    if (args.length > 1) {
      print('Error: Too many arguments. Expected at most one worktree name.');
      return ExitCode.invalidArguments;
    }
    return ExitCode.success;
  }
}
