import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';

/// Command for cleaning up Git worktrees.
///
/// Usage: gwt clean [options]
class CleanCommand extends BaseCommand {
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
      print('Usage: gwt clean [options]');
      print('');
      print('Clean up unused Git worktrees. Removes worktrees that are');
      print('no longer needed or have been marked for deletion.');
      print('');
      print(parser.usage);
      return ExitCode.success;
    }

    final force = results.flag('force');

    // TODO: Implement actual worktree cleanup logic
    // For now, just print what would be done
    print('Cleaning worktrees...');
    if (force) {
      print('Force mode enabled - no confirmation prompts.');
    } else {
      print('Interactive mode - will prompt for confirmation.');
    }

    return ExitCode.success;
  }
}
