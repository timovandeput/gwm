import 'dart:async';

import 'package:test/test.dart';

import 'package:gwm/src/services/shell_integration.dart';
import 'package:gwm/src/services/completion_service.dart';
import 'package:gwm/src/models/config.dart';

class MockCompletionService implements CompletionService {
  final List<String> _completions;

  MockCompletionService(this._completions);

  @override
  Future<List<String>> getWorktreeCompletions() async => _completions;

  @override
  Future<List<String>> getWorktreeCompletionsExcludingCurrent() async =>
      _completions;

  @override
  Future<List<String>> getBranchCompletions() async => [];

  @override
  List<String> getConfigCompletions() => [];

  @override
  List<String> getCommandCompletions() => [];

  @override
  List<String> getFlagCompletions([String? command]) => [];

  @override
  Future<List<String>> getCompletions({
    String? command,
    String partial = '',
    int position = 0,
  }) async => _completions;
}

List<String> captureOutput(void Function() action) {
  final lines = <String>[];
  final zone = Zone.current.fork(
    specification: ZoneSpecification(
      print: (self, parent, zone, line) {
        lines.add(line);
      },
    ),
  );

  zone.run(action);
  return lines;
}

void main() {
  group('ShellIntegration Integration', () {
    group('with eval output enabled', () {
      late ShellIntegration shellIntegration;

      setUp(() {
        shellIntegration = ShellIntegration(
          ShellIntegrationConfig(enableEvalOutput: true),
        );
      });

      test('outputCdCommand prints cd command', () {
        final output = captureOutput(
          () => shellIntegration.outputCdCommand('/path/to/worktree'),
        );

        expect(output, contains('cd /path/to/worktree'));
      });

      test('outputWorktreeCreated prints cd and echo commands', () {
        final output = captureOutput(
          () => shellIntegration.outputWorktreeCreated('/worktrees/my-project'),
        );

        expect(output, contains('cd /worktrees/my-project'));
        expect(
          output,
          contains(
            'echo "Worktree created and switched to: /worktrees/my-project"',
          ),
        );
      });

      test('outputWorktreeSwitched prints cd and echo commands', () {
        final output = captureOutput(
          () => shellIntegration.outputWorktreeSwitched(
            '/worktrees/feature',
            'feature',
          ),
        );

        expect(output, contains('cd /worktrees/feature'));
        expect(output, contains('echo "Switched to worktree: feature"'));
      });

      test('outputWorktreesListed prints count message', () {
        final output = captureOutput(
          () => shellIntegration.outputWorktreesListed(5),
        );

        expect(output, contains('echo "Found 5 worktree(s)"'));
      });

      test('outputWorktreesDeleted with deleted worktrees', () {
        final output = captureOutput(
          () => shellIntegration.outputWorktreesDeleted([
            'feature-a',
            'feature-b',
          ]),
        );

        expect(
          output,
          contains('echo "Deleted worktrees: feature-a, feature-b"'),
        );
      });

      test('outputWorktreesDeleted with empty list', () {
        final output = captureOutput(
          () => shellIntegration.outputWorktreesDeleted([]),
        );

        expect(output, contains('echo "No worktrees needed deletion."'));
      });

      test('outputError prints error to stderr', () {
        final output = captureOutput(
          () => shellIntegration.outputError('Something went wrong'),
        );

        expect(output, contains('echo "Error: Something went wrong" >&2'));
      });

      test('handles paths with spaces', () {
        final output = captureOutput(
          () => shellIntegration.outputCdCommand('/path/with spaces/worktree'),
        );

        expect(output, contains('cd /path/with spaces/worktree'));
      });

      test('handles special characters in worktree names', () {
        final shellIntegration = ShellIntegration(
          ShellIntegrationConfig(enableEvalOutput: true),
        );

        final output = captureOutput(
          () => shellIntegration.outputWorktreeSwitched(
            '/worktrees/feature_test',
            'feature/test-v1.0',
          ),
        );

        expect(output.join('\n'), contains('feature/test-v1.0'));
      });
    });

    group('with eval output disabled', () {
      late ShellIntegration shellIntegration;

      setUp(() {
        shellIntegration = ShellIntegration(
          ShellIntegrationConfig(enableEvalOutput: false),
        );
      });

      test('outputCdCommand produces no output', () {
        final output = captureOutput(
          () => shellIntegration.outputCdCommand('/path/to/worktree'),
        );

        expect(output, isEmpty);
      });

      test('outputWorktreeCreated produces no output', () {
        final output = captureOutput(
          () => shellIntegration.outputWorktreeCreated('/worktrees/test'),
        );

        expect(output, isEmpty);
      });

      test('outputWorktreeSwitched produces no output', () {
        final output = captureOutput(
          () => shellIntegration.outputWorktreeSwitched(
            '/worktrees/test',
            'test',
          ),
        );

        expect(output, isEmpty);
      });

      test('outputWorktreesListed produces no output', () {
        final output = captureOutput(
          () => shellIntegration.outputWorktreesListed(3),
        );

        expect(output, isEmpty);
      });

      test('outputWorktreesDeleted produces no output', () {
        final output = captureOutput(
          () => shellIntegration.outputWorktreesDeleted(['a', 'b']),
        );

        expect(output, isEmpty);
      });

      test('outputError always produces output regardless of setting', () {
        final output = captureOutput(
          () => shellIntegration.outputError('Error message'),
        );

        expect(output, contains('echo "Error: Error message" >&2'));
      });
    });

    group('with completion service', () {
      late ShellIntegration shellIntegration;
      late MockCompletionService mockCompletionService;

      setUp(() {
        mockCompletionService = MockCompletionService([
          'feature-a',
          'feature-b',
          'main',
        ]);
        shellIntegration = ShellIntegration(
          ShellIntegrationConfig(enableEvalOutput: true),
          completionService: mockCompletionService,
        );
      });

      test('getCompletionCandidates returns completions', () async {
        final candidates = await shellIntegration.getCompletionCandidates(
          command: 'gwm',
          partial: 'fea',
        );

        expect(candidates, equals(['feature-a', 'feature-b', 'main']));
      });

      test('getCompletionCandidates with empty partial', () async {
        final candidates = await shellIntegration.getCompletionCandidates();

        expect(candidates, hasLength(3));
      });
    });

    group('without completion service', () {
      late ShellIntegration shellIntegration;

      setUp(() {
        shellIntegration = ShellIntegration(
          ShellIntegrationConfig(enableEvalOutput: true),
        );
      });

      test('getCompletionCandidates returns empty list', () async {
        final candidates = await shellIntegration.getCompletionCandidates(
          partial: 'test',
        );

        expect(candidates, isEmpty);
      });
    });

    group('edge cases', () {
      test('handles very long paths', () {
        final shellIntegration = ShellIntegration(
          ShellIntegrationConfig(enableEvalOutput: true),
        );

        final longPath = '${'/very/long/path/'}${'subdirectory/' * 50}worktree';
        final output = captureOutput(
          () => shellIntegration.outputCdCommand(longPath),
        );

        expect(output, contains('cd $longPath'));
      });

      test('handles unicode in worktree names', () {
        final shellIntegration = ShellIntegration(
          ShellIntegrationConfig(enableEvalOutput: true),
        );

        final output = captureOutput(
          () => shellIntegration.outputWorktreeSwitched(
            '/worktrees/feature',
            'feature-日本語-🎉',
          ),
        );

        expect(output.join('\n'), contains('feature-日本語-🎉'));
      });

      test('handles empty worktree deletion list', () {
        final shellIntegration = ShellIntegration(
          ShellIntegrationConfig(enableEvalOutput: true),
        );

        final output = captureOutput(
          () => shellIntegration.outputWorktreesDeleted([]),
        );

        expect(output.join('\n'), contains('No worktrees needed deletion'));
      });

      test('handles single worktree deletion', () {
        final shellIntegration = ShellIntegration(
          ShellIntegrationConfig(enableEvalOutput: true),
        );

        final output = captureOutput(
          () => shellIntegration.outputWorktreesDeleted(['single-feature']),
        );

        expect(
          output.join('\n'),
          contains('Deleted worktrees: single-feature'),
        );
      });

      test('handles many deleted worktrees', () {
        final shellIntegration = ShellIntegration(
          ShellIntegrationConfig(enableEvalOutput: true),
        );

        final deleted = List.generate(10, (i) => 'feature-$i');
        final output = captureOutput(
          () => shellIntegration.outputWorktreesDeleted(deleted),
        );

        final outputStr = output.join('\n');
        expect(outputStr, contains('feature-0'));
        expect(outputStr, contains('feature-9'));
      });
    });

    group('integration scenarios', () {
      test('typical worktree creation workflow output', () {
        final shellIntegration = ShellIntegration(
          ShellIntegrationConfig(enableEvalOutput: true),
        );

        final output = captureOutput(
          () => shellIntegration.outputWorktreeCreated(
            '/worktrees/my-app_feature',
          ),
        );

        expect(output.length, 2);
        expect(output[0], contains('cd'));
        expect(output[1], contains('echo'));
        expect(output[1], contains('Worktree created'));
      });

      test('typical worktree switch workflow output', () {
        final shellIntegration = ShellIntegration(
          ShellIntegrationConfig(enableEvalOutput: true),
        );

        final output = captureOutput(
          () => shellIntegration.outputWorktreeSwitched(
            '/worktrees/feature',
            'feature',
          ),
        );

        expect(output.length, 2);
        expect(output[0], contains('cd'));
        expect(output[1], contains('Switched to worktree'));
      });

      test('error handling in workflow', () {
        final shellIntegration = ShellIntegration(
          ShellIntegrationConfig(enableEvalOutput: true),
        );

        final output = captureOutput(
          () => shellIntegration.outputError('Failed to create worktree'),
        );

        final outputStr = output.join('\n');
        expect(outputStr, contains('>&2'));
        expect(outputStr, contains('Error:'));
      });
    });
  });
}
