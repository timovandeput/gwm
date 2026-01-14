import 'dart:io';

import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gwm/src/commands/switch.dart';
import 'package:gwm/src/models/exit_codes.dart';
import 'package:gwm/src/models/worktree.dart';
import 'package:gwm/src/infrastructure/git_client.dart';
import 'package:gwm/src/infrastructure/prompt_selector.dart';
import 'package:gwm/src/services/shell_integration.dart';
import 'package:gwm/src/services/copy_service.dart';
import 'package:gwm/src/models/config.dart';

// Mock classes
class MockGitClient extends Mock implements GitClient {}

class MockPromptSelector extends Mock implements PromptSelector {}

class MockShellIntegration extends Mock implements ShellIntegration {}

class MockCopyService extends Mock implements CopyService {}

// Fake classes for fallbacks
class FakeCopyConfig extends Fake implements CopyConfig {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCopyConfig());
  });

  late MockGitClient mockGitClient;
  late MockPromptSelector mockPromptSelector;
  late MockShellIntegration mockShellIntegration;
  late SwitchCommand switchCommand;

  setUp(() {
    mockGitClient = MockGitClient();
    mockPromptSelector = MockPromptSelector();
    mockShellIntegration = MockShellIntegration();
    final mockCopyService = MockCopyService();
    switchCommand = SwitchCommand(
      gitClient: mockGitClient,
      promptSelector: mockPromptSelector,
      shellIntegration: mockShellIntegration,
      copyService: mockCopyService,
    );

    // Register fallback values
    registerFallbackValue(
      Worktree(
        name: 'fallback',
        branch: 'fallback',
        path: '/fallback',
        isMain: false,
        status: WorktreeStatus.clean,
      ),
    );
  });

  group('SwitchCommand', () {
    test('shows help message when --help flag is provided', () async {
      final results = switchCommand.parser.parse(['--help']);
      final exitCode = await switchCommand.execute(results);
      expect(exitCode, ExitCode.success);
    });

    test('switches to specified worktree by name', () async {
      final worktrees = [
        Worktree(
          name: 'main',
          branch: 'main',
          path: '/repo',
          isMain: true,
          status: WorktreeStatus.clean,
        ),
        Worktree(
          name: 'feature-auth',
          branch: 'feature/auth',
          path: '/repo/worktrees/feature-auth',
          isMain: false,
          status: WorktreeStatus.clean,
        ),
      ];

      when(() => mockGitClient.getRepoRoot()).thenAnswer((_) async => '/repo');
      when(
        () => mockGitClient.listWorktrees(),
      ).thenAnswer((_) async => worktrees);

      final results = switchCommand.parser.parse(['feature-auth']);
      final exitCode = await switchCommand.execute(results);

      expect(exitCode, ExitCode.success);
      verify(
        () => mockShellIntegration.outputCdCommand(
          '/repo/worktrees/feature-auth',
        ),
      ).called(1);
    });

    test('switches to main workspace when "." is specified', () async {
      final worktrees = [
        Worktree(
          name: 'main',
          branch: 'main',
          path: '/repo',
          isMain: true,
          status: WorktreeStatus.clean,
        ),
      ];

      when(() => mockGitClient.getRepoRoot()).thenAnswer((_) async => '/repo');
      when(
        () => mockGitClient.listWorktrees(),
      ).thenAnswer((_) async => worktrees);

      final results = switchCommand.parser.parse(['.']);
      final exitCode = await switchCommand.execute(results);

      expect(exitCode, ExitCode.success);
      verify(() => mockShellIntegration.outputCdCommand('/repo')).called(1);
    });

    test(
      'shows interactive selection when no argument provided and eval check skipped',
      () async {
        final worktrees = [
          Worktree(
            name: 'main',
            branch: 'main',
            path: '/repo',
            isMain: true,
            status: WorktreeStatus.clean,
          ),
        ];

        // Create command with eval check skipped
        final commandWithSkipEval = SwitchCommand(
          gitClient: mockGitClient,
          promptSelector: mockPromptSelector,
          shellIntegration: mockShellIntegration,
          skipEvalCheck: true,
        );

        when(
          () => mockGitClient.getRepoRoot(),
        ).thenAnswer((_) async => '/repo');
        when(
          () => mockGitClient.listWorktrees(),
        ).thenAnswer((_) async => worktrees);
        when(
          () => mockPromptSelector.selectWorktree(worktrees),
        ).thenAnswer((_) async => worktrees[0]);

        final results = commandWithSkipEval.parser.parse([]);
        final exitCode = await commandWithSkipEval.execute(results);

        expect(exitCode, ExitCode.success);
        verify(() => mockPromptSelector.selectWorktree(worktrees)).called(1);
        verify(() => mockShellIntegration.outputCdCommand('/repo')).called(1);
      },
    );

    test(
      'returns error when interactive selection requested but eval check not skipped',
      () async {
        final worktrees = [
          Worktree(
            name: 'main',
            branch: 'main',
            path: '/repo',
            isMain: true,
            status: WorktreeStatus.clean,
          ),
          Worktree(
            name: 'feature-auth',
            branch: 'feature/auth',
            path: '/repo/worktrees/feature-auth',
            isMain: false,
            status: WorktreeStatus.clean,
          ),
        ];

        when(
          () => mockGitClient.getRepoRoot(),
        ).thenAnswer((_) async => '/repo');
        when(
          () => mockGitClient.listWorktrees(),
        ).thenAnswer((_) async => worktrees);

        final results = switchCommand.parser.parse([]);
        final exitCode = await switchCommand.execute(results);

        expect(exitCode, ExitCode.invalidArguments);
        verifyNever(() => mockPromptSelector.selectWorktree(any()));
        verifyNever(() => mockShellIntegration.outputCdCommand(any()));
      },
    );

    test('returns error when specified worktree does not exist', () async {
      final worktrees = [
        Worktree(
          name: 'main',
          branch: 'main',
          path: '/repo',
          isMain: true,
          status: WorktreeStatus.clean,
        ),
      ];

      when(() => mockGitClient.getRepoRoot()).thenAnswer((_) async => '/repo');
      when(
        () => mockGitClient.listWorktrees(),
      ).thenAnswer((_) async => worktrees);

      final results = switchCommand.parser.parse(['nonexistent']);
      final exitCode = await switchCommand.execute(results);

      expect(exitCode, ExitCode.generalError);
      verifyNever(() => mockShellIntegration.outputCdCommand(any()));
    });

    test('returns error when not in a git repository', () async {
      when(
        () => mockGitClient.getRepoRoot(),
      ).thenThrow(Exception('Not a git repo'));

      final results = switchCommand.parser.parse(['main']);
      final exitCode = await switchCommand.execute(results);

      expect(exitCode, ExitCode.generalError);
      verifyNever(() => mockGitClient.listWorktrees());
    });

    test('returns git failed when git operation fails', () async {
      when(() => mockGitClient.getRepoRoot()).thenAnswer((_) async => '/repo');
      when(
        () => mockGitClient.listWorktrees(),
      ).thenThrow(Exception('Git error'));

      final results = switchCommand.parser.parse(['main']);
      final exitCode = await switchCommand.execute(results);

      expect(exitCode, ExitCode.gitFailed);
    });

    test('validation fails with too many arguments', () {
      final results = switchCommand.parser.parse(['arg1', 'arg2']);
      final exitCode = switchCommand.validate(results);
      expect(exitCode, ExitCode.invalidArguments);
    });

    test('validation succeeds with valid arguments', () {
      final results = switchCommand.parser.parse(['worktree-name']);
      final exitCode = switchCommand.validate(results);
      expect(exitCode, ExitCode.success);
    });

    test('returns error when no worktrees available to switch to', () async {
      final currentPath = Directory.current.path;
      final worktrees = [
        Worktree(
          name: 'main',
          branch: 'main',
          path: currentPath,
          isMain: true,
          status: WorktreeStatus.clean,
        ),
      ];

      when(
        () => mockGitClient.getRepoRoot(),
      ).thenAnswer((_) async => currentPath);
      when(
        () => mockGitClient.listWorktrees(),
      ).thenAnswer((_) async => worktrees);

      final results = switchCommand.parser.parse([]);
      final exitCode = await switchCommand.execute(results);

      expect(exitCode, ExitCode.invalidArguments);
      verifyNever(() => mockPromptSelector.selectWorktree(any()));
      verifyNever(() => mockShellIntegration.outputCdCommand(any()));
    });

    test('reconfigures worktree when --reconfigure flag is used', () async {
      final mockCopyService = MockCopyService();
      final switchCommandWithCopy = SwitchCommand(
        gitClient: mockGitClient,
        promptSelector: mockPromptSelector,
        shellIntegration: mockShellIntegration,
        copyService: mockCopyService,
      );

      final worktrees = [
        Worktree(
          name: 'feature-branch',
          branch: 'feature-branch',
          path: '/repo/worktrees/feature-branch',
          isMain: false,
          status: WorktreeStatus.clean,
        ),
      ];

      when(() => mockGitClient.getRepoRoot()).thenAnswer((_) async => '/repo');
      when(
        () => mockGitClient.listWorktrees(),
      ).thenAnswer((_) async => worktrees);
      when(
        () => mockCopyService.copyFiles(any(), any(), any()),
      ).thenAnswer((_) async {});

      final results = switchCommandWithCopy.parser.parse([
        'feature-branch',
        '--reconfigure',
      ]);
      final exitCode = await switchCommandWithCopy.execute(results);

      expect(exitCode, ExitCode.success);
      verify(
        () => mockCopyService.copyFiles(
          any(),
          '/repo',
          '/repo/worktrees/feature-branch',
        ),
      ).called(1);
      verify(
        () => mockShellIntegration.outputCdCommand(
          '/repo/worktrees/feature-branch',
        ),
      ).called(1);
    });
  });
}
