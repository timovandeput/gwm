import 'dart:async';
import 'dart:io';

import '../infrastructure/process_wrapper.dart';
import '../models/config.dart';
import '../models/hook.dart';
import '../exceptions.dart';
import '../cli_utils.dart';

/// Service for executing hooks during worktree operations.
///
/// Provides sequential execution of hook commands with environment variable
/// expansion, timeout handling, and proper error reporting.
class HookService {
  final ProcessWrapper _processWrapper;

  HookService(this._processWrapper);

  /// Executes hooks for the 'preAdd' phase.
  ///
  /// [config] contains the hook configuration.
  /// [worktreePath] is the path to the worktree being created.
  /// [originPath] is the path to the origin repository.
  /// [branch] is the branch name for the new worktree.
  Future<void> executePreAdd(
    HooksConfig config,
    String worktreePath,
    String originPath,
    String branch,
  ) async {
    await _executeHook(
      config.preAdd,
      'preAdd',
      config.timeout,
      worktreePath,
      originPath,
      branch,
    );
  }

  /// Executes hooks for the 'postAdd' phase.
  ///
  /// [config] contains the hook configuration.
  /// [worktreePath] is the path to the worktree that was created.
  /// [originPath] is the path to the origin repository.
  /// [branch] is the branch name for the new worktree.
  Future<void> executePostAdd(
    HooksConfig config,
    String worktreePath,
    String originPath,
    String branch,
  ) async {
    await _executeHook(
      config.postAdd,
      'postAdd',
      config.timeout,
      worktreePath,
      originPath,
      branch,
    );
  }

  /// Executes hooks for the 'preSwitch' phase.
  ///
  /// [config] contains the hook configuration.
  /// [worktreePath] is the path to the worktree being switched to.
  /// [originPath] is the path to the origin repository.
  /// [branch] is the branch name for the worktree.
  Future<void> executePreSwitch(
    HooksConfig config,
    String worktreePath,
    String originPath,
    String branch,
  ) async {
    await _executeHook(
      config.preSwitch,
      'preSwitch',
      config.timeout,
      worktreePath,
      originPath,
      branch,
    );
  }

  /// Executes hooks for the 'postSwitch' phase.
  ///
  /// [config] contains the hook configuration.
  /// [worktreePath] is the path to the worktree that was switched to.
  /// [originPath] is the path to the origin repository.
  /// [branch] is the branch name for the worktree.
  Future<void> executePostSwitch(
    HooksConfig config,
    String worktreePath,
    String originPath,
    String branch,
  ) async {
    await _executeHook(
      config.postSwitch,
      'postSwitch',
      config.timeout,
      worktreePath,
      originPath,
      branch,
    );
  }

  /// Executes hooks for the 'preClean' phase.
  ///
  /// [config] contains the hook configuration.
  /// [worktreePath] is the path to the worktree being cleaned.
  /// [originPath] is the path to the origin repository.
  /// [branch] is the branch name for the worktree.
  Future<void> executePreClean(
    HooksConfig config,
    String worktreePath,
    String originPath,
    String branch,
  ) async {
    await _executeHook(
      config.preClean,
      'preClean',
      config.timeout,
      worktreePath,
      originPath,
      branch,
    );
  }

  /// Executes hooks for the 'postClean' phase.
  ///
  /// [config] contains the hook configuration.
  /// [worktreePath] is the path to the worktree that was cleaned.
  /// [originPath] is the path to the origin repository.
  /// [branch] is the branch name for the worktree.
  Future<void> executePostClean(
    HooksConfig config,
    String worktreePath,
    String originPath,
    String branch,
  ) async {
    await _executeHook(
      config.postClean,
      'postClean',
      config.timeout,
      worktreePath,
      originPath,
      branch,
    );
  }

  /// Executes a single hook if it exists.
  ///
  /// [hook] is the hook configuration to execute (may be null).
  /// [hookName] is the name of the hook for error reporting.
  /// [defaultTimeout] is the global timeout to use if hook has no timeout.
  /// [worktreePath], [originPath], [branch] are environment variables.
  Future<void> _executeHook(
    Hook? hook,
    String hookName,
    int defaultTimeout,
    String worktreePath,
    String originPath,
    String branch,
  ) async {
    if (hook == null || hook.commands.isEmpty) {
      return;
    }

    final timeout = hook.timeout ?? defaultTimeout;
    final environment = _createEnvironment(worktreePath, originPath, branch);

    for (final command in hook.commands) {
      await _executeCommand(
        command,
        hookName,
        timeout,
        environment,
        worktreePath,
      );
    }
  }

  /// Executes a single command with timeout and error handling.
  ///
  /// [command] is the command string to execute (may contain variables).
  /// [hookName] is the name of the hook for error reporting.
  /// [timeoutSeconds] is the timeout in seconds.
  /// [environment] is the environment variables to set.
  /// [workingDirectory] is the working directory for execution.
  Future<void> _executeCommand(
    String command,
    String hookName,
    int timeoutSeconds,
    Map<String, String> environment,
    String workingDirectory,
  ) async {
    final expandedCommand = _expandVariables(command, environment);

    printSafe('Executing hook "$hookName": $expandedCommand');

    final timeout = Duration(seconds: timeoutSeconds);

    try {
      final result = await _processWrapper
          .run(
            'sh',
            ['-c', expandedCommand],
            timeout: timeout,
            workingDirectory: workingDirectory,
          )
          .timeout(
            timeout,
            onTimeout: () {
              throw TimeoutException(
                'Command timed out after $timeoutSeconds seconds',
              );
            },
          );

      // Display output
      if (result.stdout.isNotEmpty) {
        printSafe(result.stdout);
      }
      if (result.stderr.isNotEmpty) {
        printSafe(result.stderr);
      }

      // Check for failure
      if (result.exitCode != 0) {
        final output = '${result.stdout}${result.stderr}'.trim();
        throw HookExecutionException(hookName, expandedCommand, output);
      }
    } on TimeoutException catch (e) {
      printSafe('Hook "$hookName" timed out: $e');
      throw HookExecutionException(
        hookName,
        expandedCommand,
        'Command timed out after $timeoutSeconds seconds',
      );
    } catch (e) {
      if (e is HookExecutionException) rethrow;
      throw HookExecutionException(hookName, expandedCommand, e.toString());
    }
  }

  /// Creates environment variables for hook execution.
  Map<String, String> _createEnvironment(
    String worktreePath,
    String originPath,
    String branch,
  ) {
    return {
      ...Platform.environment,
      'GWM_WORKTREE_PATH': worktreePath,
      'GWM_ORIGIN_PATH': originPath,
      'GWM_BRANCH': branch,
    };
  }

  /// Expands environment variables in a command string.
  ///
  /// Supports $VARIABLE syntax for the predefined variables.
  String _expandVariables(String command, Map<String, String> environment) {
    var expanded = command;

    // Expand predefined GWM variables
    expanded = expanded.replaceAll(
      '\$GWM_WORKTREE_PATH',
      environment['GWM_WORKTREE_PATH']!,
    );
    expanded = expanded.replaceAll(
      '\$GWM_ORIGIN_PATH',
      environment['GWM_ORIGIN_PATH']!,
    );
    expanded = expanded.replaceAll('\$GWM_BRANCH', environment['GWM_BRANCH']!);

    // Expand other environment variables
    environment.forEach((key, value) {
      expanded = expanded.replaceAll('\$$key', value);
    });

    return expanded;
  }
}
