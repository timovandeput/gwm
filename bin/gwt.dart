import 'dart:io';

import 'package:args/args.dart';
import 'package:gwt/src/commands/add.dart';
import 'package:gwt/src/commands/base.dart';
import 'package:gwt/src/commands/switch.dart';
import 'package:gwt/src/commands/clean.dart';
import 'package:gwt/src/commands/list.dart';
import 'package:gwt/src/models/exit_codes.dart';

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
    ..addCommand('add', AddCommand().parser)
    ..addCommand('switch', SwitchCommand().parser)
    ..addCommand('clean', CleanCommand().parser)
    ..addCommand('list', ListCommand().parser);
}

void printUsage(ArgParser argParser) {
  print('GWT (Git Worktree Manager) - Streamlined Git worktree management');
  print('');
  print('Usage: gwt <command> [arguments]');
  print('');
  print('Available commands:');
  print('  add     Add a new worktree');
  print('  switch  Switch to an existing worktree');
  print('  clean   Delete current worktree and return to main repo');
  print('  list    List all worktrees');
  print('');
  print('Global options:');
  print(argParser.usage);
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
      print('gwt version: $version');
      return;
    }

    // Handle subcommands
    final commandName = results.command?.name;
    if (commandName == null) {
      print('Error: No command specified.');
      print('');
      printUsage(argParser);
      exit(ExitCode.invalidArguments.value);
    }

    final commandResults = results.command!;
    late final BaseCommand command;

    switch (commandName) {
      case 'add':
        command = AddCommand();
        break;
      case 'switch':
        command = SwitchCommand();
        break;
      case 'clean':
        command = CleanCommand();
        break;
      case 'list':
        command = ListCommand();
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
    print(e.message);
    print('');
    printUsage(argParser);
    exit(ExitCode.invalidArguments.value);
  } catch (e) {
    print('Unexpected error: $e');
    exit(ExitCode.generalError.value);
  }
}
