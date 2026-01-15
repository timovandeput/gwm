import 'dart:io';

import 'package:args/args.dart';

/// Prints a message safely for both normal execution and eval context.
///
/// [hasTerminal] indicates if output is going to a terminal.
/// If true, prints directly. If false (eval context), outputs echo command.
/// [printFunction] allows injecting a custom print function for testing.
void printSafe(
  String message, {
  bool? hasTerminal,
  void Function(String)? printFunction,
}) {
  hasTerminal ??= stdout.hasTerminal;
  printFunction ??= print;
  if (hasTerminal) {
    // Normal execution: print directly
    printFunction(message);
  } else {
    // Eval context: output echo command
    final escaped = message.replaceAll("'", "'\"'\"'");
    printFunction("echo '$escaped'");
  }
}

/// Prints usage information safely based on terminal context.
/// [printFunction] allows injecting a custom print function for testing.
void printUsage(
  ArgParser argParser, {
  bool? hasTerminal,
  void Function(String)? printFunction,
}) {
  hasTerminal ??= stdout.hasTerminal;
  printFunction ??= print;
  final lines = [
    'GWM (Git Worktree Manager) - Streamlined Git worktree management',
    '',
    'Usage: gwm <command> [arguments]',
    '',
    'Available commands:',
    '  add     Add a new worktree',
    '  switch  Switch to an existing worktree',
    '  delete   Delete current worktree and return to main repo',
    '  list    List all worktrees',
    '',
    'Global options:',
    argParser.usage,
  ];

  if (hasTerminal) {
    // Normal execution: print directly
    for (final line in lines) {
      printFunction(line);
    }
  } else {
    // Eval context: output echo commands
    for (final line in lines) {
      // Escape single quotes in the line
      final escaped = line.replaceAll("'", "'\"'\"'");
      printFunction("echo '$escaped'");
    }
  }
}

/// Prints command-specific usage information safely based on terminal context.
/// [printFunction] allows injecting a custom print function for testing.
void printCommandUsage(
  String commandName,
  String description,
  ArgParser argParser, {
  bool? hasTerminal,
  void Function(String)? printFunction,
}) {
  hasTerminal ??= stdout.hasTerminal;
  printFunction ??= print;
  final lines = [
    'Usage: gwm $commandName',
    '',
    description,
    '',
    argParser.usage,
  ];

  if (hasTerminal) {
    // Normal execution: print directly
    for (final line in lines) {
      printFunction(line);
    }
  } else {
    // Eval context: output echo commands
    for (final line in lines) {
      // Escape single quotes in the line
      final escaped = line.replaceAll("'", "'\"'\"'");
      printFunction("echo '$escaped'");
    }
  }
}
