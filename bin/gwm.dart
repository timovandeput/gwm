import 'dart:io';

import 'package:args/args.dart';
import 'package:gwm/src/commands/add.dart';
import 'package:gwm/src/commands/base.dart';
import 'package:gwm/src/commands/init.dart';
import 'package:gwm/src/commands/switch.dart';
import 'package:gwm/src/commands/delete.dart';
import 'package:gwm/src/commands/list.dart';
import 'package:gwm/src/models/exit_codes.dart';
import 'package:gwm/src/exceptions.dart';
import 'package:gwm/src/cli_utils.dart';
import 'package:gwm/src/infrastructure/git_client_impl.dart';
import 'package:gwm/src/infrastructure/process_wrapper_impl.dart';
import 'package:gwm/src/infrastructure/prompt_selector.dart';
import 'package:gwm/src/infrastructure/file_system_adapter_impl.dart';
import 'package:gwm/src/services/worktree_service.dart';
import 'package:gwm/src/services/config_service.dart';
import 'package:gwm/src/services/hook_service.dart';
import 'package:gwm/src/services/copy_service.dart';
import 'package:gwm/src/services/shell_integration.dart';
import 'package:gwm/src/services/completion_service.dart';
import 'package:gwm/src/utils/output_formatter.dart';
import 'package:gwm/src/models/config.dart';

const String version = '0.1.0';

/// Handles tab completion requests.
///
/// Completion requests are made by shell completion scripts with special arguments.
/// The format is: gwm --complete `command` `partial` `position`
///
/// Returns ExitCode.success on completion, or an error code if completion fails.
Future<ExitCode> handleCompletion(
  List<String> arguments,
  CompletionService completionService,
) async {
  // Arguments should be: [--complete, command?, partial?, position?]
  // Skip the --complete flag
  final completionArgs = arguments.skip(1).toList();

  String? command;
  String partial = '';
  int position = 0;

  if (completionArgs.isNotEmpty) {
    command = completionArgs[0];
  }
  if (completionArgs.length > 1) {
    partial = completionArgs[1];
  }
  if (completionArgs.length > 2) {
    position = int.tryParse(completionArgs[2]) ?? 0;
  }

  try {
    final completions = await completionService.getCompletions(
      command: command,
      partial: partial,
      position: position,
    );

    // Output completions one per line
    for (final completion in completions) {
      printSafe(completion);
    }

    return ExitCode.success;
  } catch (e) {
    // On completion errors, output nothing and exit successfully
    // This prevents completion from breaking the shell
    return ExitCode.success;
  }
}

ArgParser buildParser() {
  // Create dummy commands just for their parsers
  // These won't be used for actual execution
  final dummyProcessWrapper = ProcessWrapperImpl();
  final dummyGitClient = GitClientImpl(dummyProcessWrapper);
  final dummyFileSystemAdapter = FileSystemAdapterImpl();
  final dummyPromptSelector = PromptSelectorImpl();
  final dummyOutputFormatter = OutputFormatter();
  final dummyConfigService = ConfigService();
  final dummyHookService = HookService(dummyProcessWrapper);
  final dummyCopyService = CopyService(dummyFileSystemAdapter);
  final dummyShellIntegration = ShellIntegration(
    ShellIntegrationConfig(enableEvalOutput: true),
  );
  final dummyWorktreeService = WorktreeService(
    dummyGitClient,
    dummyHookService,
    dummyCopyService,
  );

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
    ..addFlag(
      'complete',
      negatable: false,
      help:
          'Generate tab completion candidates (used by shell completion scripts).',
    )
    ..addCommand(
      'add',
      AddCommand(
        dummyWorktreeService,
        dummyConfigService,
        dummyShellIntegration,
        dummyHookService,
        dummyGitClient,
      ).parser,
    )
    ..addCommand(
      'switch',
      SwitchCommand(
        dummyGitClient,
        dummyPromptSelector,
        dummyConfigService,
        dummyHookService,
        dummyCopyService,
        dummyShellIntegration,
      ).parser,
    )
    ..addCommand(
      'delete',
      DeleteCommand(
        dummyGitClient,
        dummyConfigService,
        dummyHookService,
        dummyShellIntegration,
      ).parser,
    )
    ..addCommand(
      'list',
      ListCommand(dummyGitClient, dummyOutputFormatter).parser,
    )
    ..addCommand('init', InitCommand(dummyGitClient).parser);
}

Future<void> main(List<String> arguments) async {
  // Create infrastructure dependencies
  final processWrapper = ProcessWrapperImpl();
  final gitClient = GitClientImpl(processWrapper);
  final fileSystemAdapter = FileSystemAdapterImpl();
  final promptSelector = PromptSelectorImpl();
  final outputFormatter = OutputFormatter();

  // Create service dependencies
  final configService = ConfigService();
  final hookService = HookService(processWrapper);
  final copyService = CopyService(fileSystemAdapter);

  // Create worktree service with its dependencies
  final worktreeService = WorktreeService(gitClient, hookService, copyService);

  final ArgParser argParser = buildParser();

  // Handle completion before parsing to avoid invalid option errors
  if (arguments.contains('--complete')) {
    final completionService = CompletionService(gitClient, argParser);
    final exitCode = await handleCompletion(arguments, completionService);
    exit(exitCode.value);
  }

  final completionService = CompletionService(gitClient, argParser);
  final shellIntegration = ShellIntegration(
    ShellIntegrationConfig(enableEvalOutput: true),
    completionService: completionService,
  );

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
        command = AddCommand(
          worktreeService,
          configService,
          shellIntegration,
          hookService,
          gitClient,
          skipEvalCheck: skipEvalCheck,
        );
        break;
      case 'switch':
        command = SwitchCommand(
          gitClient,
          promptSelector,
          configService,
          hookService,
          copyService,
          shellIntegration,
          skipEvalCheck: skipEvalCheck,
        );
        break;
      case 'delete':
        command = DeleteCommand(
          gitClient,
          configService,
          hookService,
          shellIntegration,
          skipEvalCheck: skipEvalCheck,
        );
        break;
      case 'list':
        command = ListCommand(
          gitClient,
          outputFormatter,
          skipEvalCheck: skipEvalCheck,
        );
        break;
      case 'init':
        command = InitCommand(gitClient, skipEvalCheck: skipEvalCheck);
        break;
      default:
        printSafe('Error: Unknown command "$commandName".');
        printSafe('');
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
