import 'dart:io';

import '../exceptions.dart';
import 'shell_detector.dart';

/// Utility for validating that GWT is running inside an eval wrapper.
class EvalValidator {
  /// Checks if GWT is running in an eval context.
  ///
  /// When running in an eval wrapper, stdout is not connected to a terminal
  /// because output is being captured by shell wrapper for evaluation.
  ///
  /// Returns [true] if validation passes, throws exception otherwise.
  ///
  /// [skipCheck] if true, bypasses validation (used with --no-eval-check flag).
  static bool validate({bool skipCheck = false}) {
    if (skipCheck) return true;

    // Check if stdout is connected to a terminal
    // If it is, we're NOT in an eval wrapper (wrapper pipes output away from TTY)
    // If it isn't, we're likely in an eval wrapper
    if (stdout.hasTerminal) {
      final shell = ShellDetector.detect();
      final instructions = ShellDetector.getWrapperInstallationInstructions();
      throw ShellWrapperMissingException(
        'GWT must be run with a shell wrapper for directory switching.\n\n'
        'Detected shell: ${shell.name}\n\n'
        '$instructions\n\n'
        'Or use --no-eval-check to bypass this validation (not recommended).',
      );
    }

    return true;
  }
}
