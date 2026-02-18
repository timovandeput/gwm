import 'dart:io';

import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gwm/src/commands/switch.dart';
import 'package:gwm/src/models/exit_codes.dart';
import 'package:gwm/src/models/worktree.dart';
import 'package:gwm/src/infrastructure/prompt_selector.dart';
import 'package:gwm/src/services/shell_integration.dart';
import 'package:gwm/src/services/copy_service.dart';
import 'package:gwm/src/services/config_service.dart';
import 'package:gwm/src/services/hook_service.dart';
import 'package:gwm/src/models/config.dart';
import 'package:gwm/src/exceptions.dart';

import '../../mock_objects/mock_git_client.dart';

class MockPromptSelector extends Mock implements PromptSelector {}

class MockShellIntegration extends Mock implements ShellIntegration {}

class MockCopyService extends Mock implements CopyService {}

class MockConfigService extends Mock implements ConfigService {}

class MockHookService extends Mock implements HookService {}

// Fake classes for fallbacks
class FakeCopyConfig extends Fake implements CopyConfig {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCopyConfig());
  });

  late MockGitClient mockGitClient;
  late MockPromptSelector mockPromptSelector;
  late MockShellIntegration mockShellIntegration;
  late MockConfigService mockConfigService;
  late MockHookService mockHookService;
  late MockCopyService mockCopyService;
  late SwitchCommand switchCommand;

  setUp(() {
    mockGitClient = MockGitClient();
    mockPromptSelector = MockPromptSelector();
    mockShellIntegration = MockShellIntegration();
    mockConfigService = MockConfigService();
    mockHookService = MockHookService();
    mockCopyService = MockCopyService();
    switchCommand = SwitchCommand(
      mockGitClient,
      mockPromptSelector,
      mockConfigService,
      mockHookService,
      mockCopyService,
      mockShellIntegration,
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

    // Set up default config service mock
    when(
      () => mockConfigService.loadConfig(repoRoot: any(named: 'repoRoot')),
    ).thenAnswer(
      (_) async => Config(
        version: '1.0',
        copy: CopyConfig(files: [], directories: []),
        hooks: HooksConfig(timeout: 30),
        shellIntegration: ShellIntegrationConfig(enableEvalOutput: true),
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
          mockGitClient,
          mockPromptSelector,
          mockConfigService,
          mockHookService,
          mockCopyService,
          mockShellIntegration,
          skipEvalCheck: true,
        );

        when(
          () => mockGitClient.getRepoRoot(),
        ).thenAnswer((_) async => '/repo');
        when(
          () => mockGitClient.isWorktree(),
        ).thenAnswer((_) async => false); // In main workspace
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

    test('shows interactive selection when no argument provided', () async {
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

      final selectedWorktree = worktrees[1]; // feature-auth

      when(() => mockGitClient.getRepoRoot()).thenAnswer((_) async => '/repo');
      when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);
      when(
        () => mockGitClient.listWorktrees(),
      ).thenAnswer((_) async => worktrees);
      when(
        () => mockPromptSelector.selectWorktree(any()),
      ).thenAnswer((_) async => selectedWorktree);

      final results = switchCommand.parser.parse([]);
      final exitCode = await switchCommand.execute(results);

      expect(exitCode, ExitCode.success);
      verify(
        () => mockPromptSelector.selectWorktree(
          worktrees,
        ), // Both worktrees available since current dir != main path
      ).called(1);
      verify(
        () => mockShellIntegration.outputCdCommand(
          '/repo/worktrees/feature-auth',
        ),
      ).called(1);
    });

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
      when(() => mockGitClient.getRepoRoot()).thenThrow(
        GitException('rev-parse', [
          '--show-toplevel',
        ], 'fatal: not a git repository'),
      );

      final results = switchCommand.parser.parse(['main']);
      final exitCode = await switchCommand.execute(results);

      expect(exitCode, ExitCode.generalError);
      verifyNever(() => mockGitClient.listWorktrees());
    });

    test('returns git failed when git operation fails', () async {
      when(() => mockGitClient.getRepoRoot()).thenAnswer((_) async => '/repo');
      when(() => mockGitClient.listWorktrees()).thenThrow(
        GitException('worktree', ['list', '--porcelain'], 'fatal: git error'),
      );

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
        mockGitClient,
        mockPromptSelector,
        mockConfigService,
        mockHookService,
        mockCopyService,
        mockShellIntegration,
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

    test('does nothing when switching to current worktree', () async {
      final currentPath = Directory.current.path;
      final worktrees = [
        Worktree(
          name: 'main',
          branch: 'main',
          path: currentPath,
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

      final results = switchCommand.parser.parse(['main']);
      final exitCode = await switchCommand.execute(results);

      expect(exitCode, ExitCode.success);
      // Should not call outputCdCommand since we're already in the target worktree
      verifyNever(() => mockShellIntegration.outputCdCommand(any()));
    });
  });
}
