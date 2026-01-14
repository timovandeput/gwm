import 'dart:io';

import '../exceptions.dart';
import 'shell_detector.dart';

/// Utility for validating that GWM is running inside an eval wrapper.
class EvalValidator {
  /// Checks if GWM is running in an eval context.
  ///
  /// When running in an eval wrapper, stdout is not connected to a terminal
  /// because output is being captured by shell wrapper for evaluation.
  ///
  /// Throws exception if validation fails.
  ///
  /// [skipCheck] if true, bypasses validation (used with --no-eval-check flag).
  static void validate({bool skipCheck = false}) {
    if (skipCheck) return;

    // Check if stdout is connected to a terminal
    // If it is, we're NOT in an eval wrapper (wrapper pipes output away from TTY)
    // If it isn't, we're likely in an eval wrapper
    if (stdout.hasTerminal) {
      final shell = ShellDetector.detect();
      final instructions = ShellDetector.getWrapperInstallationInstructions();
      throw ShellWrapperMissingException(
        'GWM must be run with a shell wrapper for directory switching.\n\n'
        'Detected shell: ${shell.name}\n\n'
        '$instructions\n\n'
        'Or use --no-eval-check to bypass this validation (not recommended).',
      );
    }
  }
}
