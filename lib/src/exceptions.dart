import 'models/exit_codes.dart';

/// Base exception class for all GWT-related errors.
///
/// Provides consistent error handling with exit codes and messages
/// that can be displayed to users.
abstract class GwtException implements Exception {
  /// The exit code associated with this exception
  final ExitCode exitCode;

  /// A human-readable error message
  final String message;

  const GwtException(this.exitCode, this.message);

  @override
  String toString() => message;
}

/// Exception thrown when attempting to create a worktree that already exists.
class WorktreeExistsException extends GwtException {
  /// The name of the worktree that already exists
  final String worktreeName;

  const WorktreeExistsException(this.worktreeName)
    : super(ExitCode.worktreeExists, 'Worktree "$worktreeName" already exists');
}

/// Exception thrown when a specified Git branch does not exist.
class BranchNotFoundException extends GwtException {
  /// The name of the branch that was not found
  final String branch;

  const BranchNotFoundException(this.branch)
    : super(ExitCode.branchNotFound, 'Branch "$branch" not found');
}

/// Exception thrown when a hook command fails during execution.
class HookExecutionException extends GwtException {
  /// The name of the hook that failed
  final String hookName;

  /// The command that failed
  final String command;

  /// The output from the failed command
  final String output;

  HookExecutionException(this.hookName, this.command, this.output)
    : super(
        ExitCode.hookFailed,
        'Hook "$hookName" failed: Command "$command" exited with error:\n$output',
      );
}

/// Exception thrown when configuration files are invalid or malformed.
class ConfigException extends GwtException {
  /// The path to the configuration file that caused the error
  final String configPath;

  /// The specific reason for the configuration error
  final String reason;

  const ConfigException(this.configPath, this.reason)
    : super(
        ExitCode.configError,
        'Configuration error in "$configPath": $reason',
      );
}

/// Exception thrown when a Git command fails.
class GitException extends GwtException {
  /// The Git command that failed
  final String command;

  /// The arguments passed to the command
  final List<String> arguments;

  /// The error output from the Git command
  final String output;

  GitException(this.command, this.arguments, this.output)
    : super(
        ExitCode.gitFailed,
        'Git command failed: "$command ${arguments.join(' ')}"\n$output',
      );
}

/// Exception thrown when GWT is run without proper shell wrapper.
class ShellWrapperMissingException extends GwtException {
  const ShellWrapperMissingException(String message)
    : super(ExitCode.shellWrapperMissing, message);
}
