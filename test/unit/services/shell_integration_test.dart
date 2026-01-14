import 'package:test/test.dart';

import 'package:gwm/src/models/config.dart';
import 'package:gwm/src/services/shell_integration.dart';

void main() {
  group('ShellIntegration', () {
    late ShellIntegration shellIntegrationEnabled;
    late ShellIntegration shellIntegrationDisabled;

    setUp(() {
      shellIntegrationEnabled = ShellIntegration(
        ShellIntegrationConfig(enableEvalOutput: true),
      );
      shellIntegrationDisabled = ShellIntegration(
        ShellIntegrationConfig(enableEvalOutput: false),
      );
    });

    test('can be instantiated with enabled eval output', () {
      expect(shellIntegrationEnabled, isNotNull);
    });

    test('can be instantiated with disabled eval output', () {
      expect(shellIntegrationDisabled, isNotNull);
    });

    test('outputCdCommand does not throw when enabled', () {
      expect(
        () => shellIntegrationEnabled.outputCdCommand('/path/to/worktree'),
        returnsNormally,
      );
    });

    test('outputCdCommand does not throw when disabled', () {
      expect(
        () => shellIntegrationDisabled.outputCdCommand('/path/to/worktree'),
        returnsNormally,
      );
    });

    test('outputWorktreeCreated does not throw when enabled', () {
      expect(
        () => shellIntegrationEnabled.outputWorktreeCreated(
          '/path/to/new-worktree',
        ),
        returnsNormally,
      );
    });

    test('outputWorktreeCreated does not throw when disabled', () {
      expect(
        () => shellIntegrationDisabled.outputWorktreeCreated(
          '/path/to/new-worktree',
        ),
        returnsNormally,
      );
    });

    test('outputWorktreeSwitched does not throw when enabled', () {
      expect(
        () => shellIntegrationEnabled.outputWorktreeSwitched(
          '/path/to/worktree',
          'feature-branch',
        ),
        returnsNormally,
      );
    });

    test('outputWorktreeSwitched does not throw when disabled', () {
      expect(
        () => shellIntegrationDisabled.outputWorktreeSwitched(
          '/path/to/worktree',
          'feature-branch',
        ),
        returnsNormally,
      );
    });

    test('outputWorktreesListed does not throw when enabled', () {
      expect(
        () => shellIntegrationEnabled.outputWorktreesListed(3),
        returnsNormally,
      );
    });

    test('outputWorktreesListed does not throw when disabled', () {
      expect(
        () => shellIntegrationDisabled.outputWorktreesListed(3),
        returnsNormally,
      );
    });

    test(
      'outputWorktreesCleaned does not throw when enabled with worktrees',
      () {
        expect(
          () => shellIntegrationEnabled.outputWorktreesCleaned([
            'worktree1',
            'worktree2',
          ]),
          returnsNormally,
        );
      },
    );

    test(
      'outputWorktreesCleaned does not throw when enabled with empty list',
      () {
        expect(
          () => shellIntegrationEnabled.outputWorktreesCleaned([]),
          returnsNormally,
        );
      },
    );

    test('outputWorktreesCleaned does not throw when disabled', () {
      expect(
        () => shellIntegrationDisabled.outputWorktreesCleaned(['worktree1']),
        returnsNormally,
      );
    });

    test('outputError always works regardless of eval output setting', () {
      expect(
        () => shellIntegrationEnabled.outputError('Something went wrong'),
        returnsNormally,
      );
      expect(
        () => shellIntegrationDisabled.outputError('Something went wrong'),
        returnsNormally,
      );
    });
  });
}
