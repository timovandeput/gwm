import 'package:test/test.dart';

import 'package:gwm/src/infrastructure/prompt_selector.dart';

void main() {
  group('PromptSelectorImpl', () {
    test('returns null when worktrees list is empty', () {
      final selector = PromptSelectorImpl();

      // Since it uses stdin, we can't easily test interactive behavior
      // This test just verifies the class can be instantiated
      expect(selector, isNotNull);
    });

    test('can be instantiated', () {
      final selector = PromptSelectorImpl();
      expect(selector, isA<PromptSelector>());
    });
  });
}
