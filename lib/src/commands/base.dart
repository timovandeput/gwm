import 'package:args/args.dart';

import '../models/exit_codes.dart';

/// Base class for all GWT CLI commands.
///
/// Provides common functionality for argument parsing, validation,
/// and error handling.
abstract class BaseCommand {
  /// Whether to skip shell wrapper validation check.
  final bool skipEvalCheck;

  /// Creates a base command with optional skipEvalCheck parameter.
  const BaseCommand({this.skipEvalCheck = false});

  /// The argument parser for this command.
  ArgParser get parser;

  /// Executes the command with the given parsed arguments.
  ///
  /// Returns an [ExitCode] indicating success or failure.
  Future<ExitCode> execute(ArgResults results);

  /// Validates the command arguments.
  ///
  /// Subclasses can override this to provide custom validation logic.
  /// Returns [ExitCode.success] if validation passes, or an error code if not.
  ExitCode validate(ArgResults results) => ExitCode.success;

  /// Handles errors that occur during command execution.
  ///
  /// Subclasses can override this to provide custom error handling.
  /// By default, prints the error message and returns [ExitCode.generalError].
  ExitCode handleError(Object error) {
    print('Error: $error');
    return ExitCode.generalError;
  }
}
