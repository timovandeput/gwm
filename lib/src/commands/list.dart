import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';

/// Command for listing Git worktrees.
///
/// Usage: gwt list [options]
class ListCommand extends BaseCommand {
  @override
  ArgParser get parser {
    return ArgParser()
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Show detailed information about each worktree.',
      )
      ..addFlag('json', abbr: 'j', help: 'Output in JSON format.')
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
      print('Usage: gwt list [options]');
      print('');
      print('List all Git worktrees in the current repository.');
      print('');
      print(parser.usage);
      return ExitCode.success;
    }

    final verbose = results.flag('verbose');
    final json = results.flag('json');

    // TODO: Implement actual worktree listing logic
    // For now, just print what would be done
    print('Listing worktrees...');
    if (json) {
      print('Output format: JSON');
    } else if (verbose) {
      print('Output format: verbose text');
    } else {
      print('Output format: concise text');
    }

    return ExitCode.success;
  }
}
