import 'dart:async';
import 'dart:io';

import 'package:gwm/src/infrastructure/process_wrapper.dart';

/// Fake implementation of [ProcessWrapper] for testing.
///
/// This implementation allows configuring canned responses for specific commands,
/// making tests deterministic and avoiding external process invocations.
class FakeProcessWrapper implements ProcessWrapper {
  /// Internal storage for command responses.
  final Map<String, _CommandResult> _responses = {};

  /// Adds a canned response for a specific command and arguments.
  ///
  /// [command] The command to mock.
  /// [args] The command arguments.
  /// [exitCode] The exit code to return (default: 0).
  /// [stdout] The stdout content to return.
  /// [stderr] The stderr content to return.
  void addResponse(
    String command,
    List<String> args, {
    int exitCode = 0,
    String stdout = '',
    String stderr = '',
  }) {
    final key = _key(command, args);
    _responses[key] = _CommandResult(
      exitCode: exitCode,
      stdout: stdout,
      stderr: stderr,
    );
  }

  /// Clears all configured responses.
  void clearResponses() {
    _responses.clear();
  }

  @override
  Future<ProcessResult> run(
    String command,
    List<String> arguments, {
    Duration? timeout,
    String? workingDirectory,
  }) async {
    final key = _key(command, arguments);
    final response = _responses[key];

    if (response == null) {
      throw AssertionError(
        'No mock response configured for command: $key\n'
        'Available responses: ${_responses.keys.join(', ')}\n'
        'Configure a response using addResponse() in your test setup.',
      );
    }

    return ProcessResult(
      0, // Fake PID
      response.exitCode,
      response.stdout,
      response.stderr,
    );
  }

  @override
  Stream<String> runStreamed(
    String command,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    final key = _key(command, arguments);
    final response = _responses[key];

    if (response == null) {
      throw AssertionError(
        'No mock response configured for command: $key\n'
        'Available responses: ${_responses.keys.join(', ')}\n'
        'Configure a response using addResponse() in your test setup.',
      );
    }

    // Combine stdout and stderr lines into a single stream
    final lines = <String>[];
    lines.addAll(response.stdout.split('\n').where((line) => line.isNotEmpty));
    lines.addAll(response.stderr.split('\n').where((line) => line.isNotEmpty));

    return Stream.fromIterable(lines);
  }

  /// Generates a key for storing/retrieving responses.
  String _key(String command, List<String> args) =>
      '$command ${args.join(' ')}';
}

/// Internal representation of a command execution result.
class _CommandResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const _CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
}
