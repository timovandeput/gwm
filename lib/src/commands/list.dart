import 'dart:io';

import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';
import '../infrastructure/git_client.dart';
import '../utils/output_formatter.dart';
import '../cli_utils.dart';

/// Command for listing Git worktrees.
///
/// Usage: gwm list [options]
class ListCommand extends BaseCommand {
  final GitClient _gitClient;
  final OutputFormatter _formatter;

  ListCommand(this._gitClient, this._formatter, {super.skipEvalCheck = false});

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
      printCommandUsage(
        'list [options]',
        'List all Git worktrees in the current repository.',
        parser,
      );
      return ExitCode.success;
    }

    final verbose = results.flag('verbose');
    final json = results.flag('json');

    try {
      // Get current directory path
      final currentPath = Directory.current.path;

      // List all worktrees
      final worktrees = await _gitClient.listWorktrees();

      // Output in requested format
      if (json) {
        printSafe(_formatter.formatJson(worktrees, currentPath));
      } else {
        printSafe(
          _formatter.formatTable(worktrees, currentPath, verbose: verbose),
        );
      }

      return ExitCode.success;
    } catch (e) {
      printSafe('Error: Failed to list worktrees: $e');
      return ExitCode.gitFailed;
    }
  }
}
