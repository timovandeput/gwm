import 'package:test/test.dart';
import 'package:gwm/src/models/exit_codes.dart';

void main() {
  group('ExitCode', () {
    test('success has value 0', () {
      expect(ExitCode.success.value, equals(0));
    });

    test('generalError has value 1', () {
      expect(ExitCode.generalError.value, equals(1));
    });

    test('invalidArguments has value 2', () {
      expect(ExitCode.invalidArguments.value, equals(2));
    });

    test('worktreeExists has value 3', () {
      expect(ExitCode.worktreeExists.value, equals(3));
    });

    test('branchNotFound has value 4', () {
      expect(ExitCode.branchNotFound.value, equals(4));
    });

    test('hookFailed has value 5', () {
      expect(ExitCode.hookFailed.value, equals(5));
    });

    test('configError has value 6', () {
      expect(ExitCode.configError.value, equals(6));
    });

    test('gitFailed has value 7', () {
      expect(ExitCode.gitFailed.value, equals(7));
    });

    test('all values are unique', () {
      final values = ExitCode.values.map((e) => e.value).toSet();
      expect(values.length, equals(ExitCode.values.length));
    });

    test('values are in ascending order', () {
      for (int i = 0; i < ExitCode.values.length - 1; i++) {
        expect(
          ExitCode.values[i].value,
          lessThan(ExitCode.values[i + 1].value),
        );
      }
    });
  });
}
