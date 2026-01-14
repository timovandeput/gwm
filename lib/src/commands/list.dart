import 'dart:io';

import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';
import '../infrastructure/git_client.dart';
import '../infrastructure/git_client_impl.dart';
import '../infrastructure/process_wrapper_impl.dart';
import '../utils/output_formatter.dart';
import '../cli_utils.dart';

/// Command for listing Git worktrees.
///
/// Usage: gwm list [options]
class ListCommand extends BaseCommand {
  final GitClient _gitClient;
  final OutputFormatter _formatter;

  ListCommand({
    GitClient? gitClient,
    OutputFormatter? formatter,
    super.skipEvalCheck = false,
  }) : _gitClient = gitClient ?? GitClientImpl(ProcessWrapperImpl()),
       _formatter = formatter ?? OutputFormatter();

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
        print(_formatter.formatJson(worktrees, currentPath));
      } else {
        print(_formatter.formatTable(worktrees, currentPath, verbose: verbose));
      }

      return ExitCode.success;
    } catch (e) {
      print('Error: Failed to list worktrees: $e');
      return ExitCode.gitFailed;
    }
  }
}
