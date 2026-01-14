import 'dart:io';

import 'package:args/args.dart';
import 'package:gwm/src/commands/add.dart';
import 'package:gwm/src/commands/base.dart';
import 'package:gwm/src/commands/switch.dart';
import 'package:gwm/src/commands/clean.dart';
import 'package:gwm/src/commands/list.dart';
import 'package:gwm/src/models/exit_codes.dart';
import 'package:gwm/src/exceptions.dart';
import 'package:gwm/src/cli_utils.dart';

const String version = '0.0.1';

ArgParser buildParser() {
  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show additional command output.',
    )
    ..addFlag('version', negatable: false, help: 'Print the tool version.')
    ..addFlag(
      'no-eval-check',
      negatable: false,
      help: 'Skip shell wrapper validation check (not recommended).',
    )
    ..addCommand('add', AddCommand().parser)
    ..addCommand('switch', SwitchCommand().parser)
    ..addCommand('clean', CleanCommand().parser)
    ..addCommand('list', ListCommand().parser);
}

Future<void> main(List<String> arguments) async {
  final ArgParser argParser = buildParser();

  try {
    final ArgResults results = argParser.parse(arguments);

    // Handle global flags
    if (results.flag('help')) {
      printUsage(argParser);
      return;
    }
    if (results.flag('version')) {
      printSafe('gwm version: $version');
      return;
    }

    // Handle subcommands
    final commandName = results.command?.name;
    if (commandName == null) {
      printSafe('Error: No command specified.');
      printSafe('');
      printUsage(argParser);
      exit(ExitCode.invalidArguments.value);
    }

    final commandResults = results.command!;
    late final BaseCommand command;

    final skipEvalCheck = results.flag('no-eval-check');

    switch (commandName) {
      case 'add':
        command = AddCommand(skipEvalCheck: skipEvalCheck);
        break;
      case 'switch':
        command = SwitchCommand(skipEvalCheck: skipEvalCheck);
        break;
      case 'clean':
        command = CleanCommand(skipEvalCheck: skipEvalCheck);
        break;
      case 'list':
        command = ListCommand(skipEvalCheck: skipEvalCheck);
        break;
      default:
        print('Error: Unknown command "$commandName".');
        print('');
        printUsage(argParser);
        exit(ExitCode.invalidArguments.value);
    }

    // Validate arguments
    final validationResult = command.validate(commandResults);
    if (validationResult != ExitCode.success) {
      exit(validationResult.value);
    }

    // Execute command
    final exitCode = await command.execute(commandResults);
    exit(exitCode.value);
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    printSafe(e.message);
    printSafe('');
    printUsage(argParser);
    exit(ExitCode.invalidArguments.value);
  } on ShellWrapperMissingException catch (e) {
    printSafe(e.message);
    exit(e.exitCode.value);
  } catch (e) {
    printSafe('Unexpected error: $e');
    exit(ExitCode.generalError.value);
  }
}
