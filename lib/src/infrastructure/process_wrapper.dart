import 'dart:async';
import 'dart:io';

/// Interface for executing external processes.
///
/// This abstraction allows for different implementations in production code
/// (using actual Process execution) and test code (using fake implementations).
abstract class ProcessWrapper {
  /// Executes a command synchronously and returns the result.
  ///
  /// [command] The command to execute.
  /// [arguments] The command arguments.
  /// [timeout] Optional timeout for the command execution.
  /// [workingDirectory] Optional working directory for command execution.
  ///
  /// Returns a [ProcessResult] containing the exit code, stdout, and stderr.
  Future<ProcessResult> run(
    String command,
    List<String> arguments, {
    Duration? timeout,
    String? workingDirectory,
  });

  /// Executes a command and returns a stream of output lines.
  ///
  /// [command] The command to execute.
  /// [arguments] The command arguments.
  /// [workingDirectory] Optional working directory for command execution.
  ///
  /// Returns a [Stream<String>] of output lines from both stdout and stderr.
  Stream<String> runStreamed(
    String command,
    List<String> arguments, {
    String? workingDirectory,
  });
}
