import 'package:test/test.dart';

import 'package:gwm/src/infrastructure/prompt_selector.dart';

void main() {
  group('PromptSelectorImpl', () {
    test('returns null when worktrees list is empty', () async {
      final selector = PromptSelectorImpl();
      final result = await selector.selectWorktree([]);
      expect(result, isNull);
    });

    test('can be instantiated', () {
      final selector = PromptSelectorImpl();
      expect(selector, isA<PromptSelector>());
    });
  });
}
