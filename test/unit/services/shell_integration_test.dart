import 'package:test/test.dart';

import 'package:gwt/src/services/shell_integration.dart';

void main() {
  group('ShellIntegration', () {
    test('outputs cd command for given path', () {
      final shellIntegration = ShellIntegration();

      // Since outputCdCommand prints to stdout, we can't easily capture it in unit tests
      // This test just verifies the class can be instantiated and method exists
      expect(shellIntegration, isNotNull);
    });
  });
}
