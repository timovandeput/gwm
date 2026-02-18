import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';
import '../infrastructure/git_client.dart';
import '../exceptions.dart';
import '../cli_utils.dart';

/// Command for initializing GWM configuration in a Git repository.
///
/// Usage: gwm init
class InitCommand extends BaseCommand {
  final GitClient _gitClient;

  InitCommand(this._gitClient, {super.skipEvalCheck = false});

  static ArgParser buildArgParser() {
    return ArgParser()..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print usage information for this command.',
    );
  }

  @override
  ArgParser get parser => buildArgParser();

  @override
  Future<ExitCode> execute(ArgResults results) async {
    if (results.flag('help')) {
      printCommandUsage(
        'init',
        'Initialize GWM configuration in the current Git repository.',
        parser,
      );
      return ExitCode.success;
    }

    try {
      // Check if we're in a Git repository
      final repoRoot = await _gitClient.getRepoRoot();

      // Check if we're in a worktree
      final isWorktree = await _gitClient.isWorktree();
      if (isWorktree) {
        printSafe(
          'Error: Cannot initialize GWM configuration from within a worktree.',
        );
        printSafe(
          'Please run this command from the main repository directory.',
        );
        return ExitCode.generalError;
      }

      // Check if config file already exists
      final configFile = File('$repoRoot/.gwm.json');
      if (await configFile.exists()) {
        printSafe(
          'Error: GWM configuration file already exists at $repoRoot/.gwm.json',
        );
        printSafe('Remove the existing file if you want to recreate it.');
        return ExitCode.generalError;
      }

      // Create the configuration
      final config = {
        'copy': {'files': <String>[], 'directories': <String>[]},
        'hooks': {
          'timeout': 30,
          'preCreate': <String>[],
          'postCreate': <String>[],
          'preSwitch': <String>[],
          'postSwitch': <String>[],
          'preDelete': <String>[],
          'postDelete': <String>[],
        },
      };

      // Write the configuration file
      await configFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(config),
      );

      printSafe(
        'GWM configuration initialized successfully at $repoRoot/.gwm.json',
      );
      printSafe('You can now customize the configuration file as needed.');

      return ExitCode.success;
    } on GitException catch (e) {
      if (e.message.contains('Not in a Git repository')) {
        printSafe('Error: Not in a Git repository.');
        printSafe('Please navigate to a Git repository and try again.');
        return ExitCode.gitFailed;
      }
      printSafe(e.message);
      return e.exitCode;
    } on GwmException catch (e) {
      printSafe(e.message);
      return e.exitCode;
    } catch (e) {
      printSafe('Unexpected error: Failed to initialize GWM configuration: $e');
      return ExitCode.generalError;
    }
  }
}
