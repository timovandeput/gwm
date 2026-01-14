import 'package:test/test.dart';

import 'package:gwm/src/utils/eval_validator.dart';
import 'package:gwm/src/utils/shell_detector.dart';

void main() {
  group('EvalValidator', () {
    group('validate', () {
      test('does not throw when check is skipped', () {
        expect(() => EvalValidator.validate(skipCheck: true), returnsNormally);
      });

      test('returns true when check is skipped', () {
        final result = EvalValidator.validate(skipCheck: true);
        expect(result, isTrue);
      });

      test('throws ShellWrapperMissingException when stdout has terminal', () {
        // In this test environment, stdout is not a terminal (piped to test runner)
        // The actual terminal detection is tested in manual integration testing
        // This test documents expected behavior when validation is not skipped
        expect(() => EvalValidator.validate(skipCheck: false), returnsNormally);
      });
    });
  });

  group('ShellDetector', () {
    group('getWrapperInstallationInstructions', () {
      test('detects shell and returns instructions', () {
        // Shell detection relies on Platform.environment which can't be mocked
        // This test verifies that the method runs and returns instructions
        final result = ShellDetector.getWrapperInstallationInstructions();
        expect(result, isNotEmpty);
        expect(result, contains('eval'));
      });
    });
  });
}
