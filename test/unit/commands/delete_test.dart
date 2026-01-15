import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gwm/src/commands/delete.dart';
import 'package:gwm/src/models/exit_codes.dart';
import 'package:gwm/src/models/config.dart';
import 'package:gwm/src/models/worktree.dart';
import 'package:gwm/src/services/config_service.dart';
import 'package:gwm/src/services/hook_service.dart';
import 'package:gwm/src/services/shell_integration.dart';

import '../../mock_objects/mock_git_client.dart';
// Use the shared MockGitClient
// class MockGitClient extends Mock implements GitClient {}

class MockConfigService extends Mock implements ConfigService {}

class MockHookService extends Mock implements HookService {}

class MockShellIntegration extends Mock implements ShellIntegration {}

void main() {
  late MockGitClient mockGitClient;
  late MockConfigService mockConfigService;
  late MockHookService mockHookService;
  late MockShellIntegration mockShellIntegration;
  late DeleteCommand deleteCommand;

  setUp(() {
    mockGitClient = MockGitClient();
    mockConfigService = MockConfigService();
    mockHookService = MockHookService();
    mockShellIntegration = MockShellIntegration();
    deleteCommand = DeleteCommand(
      mockGitClient,
      mockConfigService,
      mockHookService,
      mockShellIntegration,
    );

    // Register fallback values for mocks
    registerFallbackValue('');
    registerFallbackValue(HooksConfig(timeout: 30));
    registerFallbackValue(false);
    registerFallbackValue(
      const Worktree(
        name: '',
        branch: '',
        path: '',
        isMain: false,
        status: WorktreeStatus.clean,
      ),
    );
  });

  group('DeleteCommand', () {
    test('shows help message when --help flag is provided', () async {
      final results = deleteCommand.parser.parse(['--help']);
      final exitCode = await deleteCommand.execute(results);
      expect(exitCode, ExitCode.success);
    });

    test('fails when not in a worktree', () async {
      when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);
      when(
        () => mockGitClient.getRepoRoot(),
      ).thenAnswer((_) async => '/path/to/repo');

      final results = deleteCommand.parser.parse([]);
      final exitCode = await deleteCommand.execute(results);

      expect(exitCode, ExitCode.invalidArguments);
      verify(() => mockGitClient.getRepoRoot()).called(1);
      verify(() => mockGitClient.isWorktree()).called(1);
    });

    // Note: Testing user prompts with stdin is complex and requires special setup
    // The confirmation logic is tested indirectly through the force flag test

    test('skips confirmation when force flag is used', () async {
      when(() => mockGitClient.isWorktree()).thenAnswer((_) async => true);
      when(
        () => mockGitClient.getRepoRoot(),
      ).thenAnswer((_) async => '/path/to/repo');
      when(
        () => mockGitClient.hasUncommittedChanges(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockConfigService.loadConfig(repoRoot: any(named: 'repoRoot')),
      ).thenAnswer(
        (_) async => Config(
          version: '1.0',
          copy: CopyConfig(files: [], directories: []),
          hooks: HooksConfig(timeout: 30),
          shellIntegration: ShellIntegrationConfig(enableEvalOutput: false),
        ),
      );
      when(
        () => mockGitClient.getCurrentBranch(),
      ).thenAnswer((_) async => 'test-branch');
      when(
        () => mockGitClient.getMainRepoPath(),
      ).thenAnswer((_) async => '/path/to/main');
      when(
        () => mockGitClient.removeWorktree(any(), force: any(named: 'force')),
      ).thenAnswer((_) async {});

      final results = deleteCommand.parser.parse(['--force']);
      final exitCode = await deleteCommand.execute(results);

      expect(exitCode, ExitCode.success);
      verify(
        () => mockGitClient.removeWorktree(any(), force: any(named: 'force')),
      ).called(1);
    });

    test('successfully removes worktree when no uncommitted changes', () async {
      when(() => mockGitClient.isWorktree()).thenAnswer((_) async => true);
      when(
        () => mockGitClient.getRepoRoot(),
      ).thenAnswer((_) async => '/path/to/repo');
      when(
        () => mockGitClient.hasUncommittedChanges(any()),
      ).thenAnswer((_) async => false);
      when(
        () => mockConfigService.loadConfig(repoRoot: any(named: 'repoRoot')),
      ).thenAnswer(
        (_) async => Config(
          version: '1.0',
          copy: CopyConfig(files: [], directories: []),
          hooks: HooksConfig(timeout: 30),
          shellIntegration: ShellIntegrationConfig(enableEvalOutput: false),
        ),
      );
      when(
        () => mockGitClient.getCurrentBranch(),
      ).thenAnswer((_) async => 'test-branch');
      when(
        () => mockGitClient.getMainRepoPath(),
      ).thenAnswer((_) async => '/path/to/main');
      when(
        () => mockHookService.executePreDelete(any(), any(), any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => mockHookService.executePostDelete(any(), any(), any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => mockGitClient.removeWorktree(any(), force: false),
      ).thenAnswer((_) async {});

      final results = deleteCommand.parser.parse([]);
      final exitCode = await deleteCommand.execute(results);

      expect(exitCode, ExitCode.success);
    });

    test('handles Git command failures', () async {
      when(() => mockGitClient.isWorktree()).thenAnswer((_) async => true);
      when(() => mockGitClient.getRepoRoot()).thenThrow(Exception('Git error'));

      final results = deleteCommand.parser.parse([]);
      final exitCode = await deleteCommand.execute(results);

      expect(exitCode, ExitCode.gitFailed);
    });

    test('successfully deletes named worktree from main workspace', () async {
      when(() => mockGitClient.listWorktrees()).thenAnswer(
        (_) async => [
          const Worktree(
            name: 'feature-branch',
            branch: 'feature/branch',
            path: '/path/to/worktree',
            isMain: false,
            status: WorktreeStatus.clean,
          ),
        ],
      );
      when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);
      when(
        () => mockConfigService.loadConfig(repoRoot: any(named: 'repoRoot')),
      ).thenAnswer(
        (_) async => Config(
          version: '1.0',
          copy: CopyConfig(files: [], directories: []),
          hooks: HooksConfig(timeout: 30),
          shellIntegration: ShellIntegrationConfig(enableEvalOutput: false),
        ),
      );
      when(
        () => mockGitClient.getCurrentBranch(),
      ).thenAnswer((_) async => 'test-branch');
      when(
        () => mockGitClient.getMainRepoPath(),
      ).thenAnswer((_) => Future.value('/path/to/main'));
      when(
        () => mockGitClient.removeWorktree(any(), force: false),
      ).thenAnswer((_) async {});

      final results = deleteCommand.parser.parse(['feature-branch']);
      final exitCode = await deleteCommand.execute(results);

      expect(exitCode, ExitCode.success);
      verify(() => mockGitClient.listWorktrees()).called(1);
      verify(() => mockGitClient.removeWorktree(any(), force: false)).called(1);
    });

    test(
      'fails when trying to delete named worktree from within a worktree',
      () async {
        when(() => mockGitClient.isWorktree()).thenAnswer((_) async => true);

        final results = deleteCommand.parser.parse(['feature-branch']);
        final exitCode = await deleteCommand.execute(results);

        expect(exitCode, ExitCode.invalidArguments);
        verifyNever(() => mockGitClient.listWorktrees());
      },
    );

    test('fails when trying to delete main workspace', () async {
      when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);
      when(() => mockGitClient.listWorktrees()).thenAnswer(
        (_) async => [
          const Worktree(
            name: '.',
            branch: 'main',
            path: '/path/to/main',
            isMain: true,
            status: WorktreeStatus.clean,
          ),
        ],
      );

      final results = deleteCommand.parser.parse(['.']);
      final exitCode = await deleteCommand.execute(results);

      expect(exitCode, ExitCode.invalidArguments);
      verify(() => mockGitClient.listWorktrees()).called(1);
    });

    test('fails when named worktree does not exist', () async {
      when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);
      when(() => mockGitClient.listWorktrees()).thenAnswer(
        (_) async => [
          const Worktree(
            name: 'existing-branch',
            branch: 'existing/branch',
            path: '/path/to/worktree',
            isMain: false,
            status: WorktreeStatus.clean,
          ),
        ],
      );

      final results = deleteCommand.parser.parse(['nonexistent-branch']);
      final exitCode = await deleteCommand.execute(results);

      expect(exitCode, ExitCode.gitFailed);
      verify(() => mockGitClient.listWorktrees()).called(1);
    });

    test('validates too many arguments', () async {
      final results = deleteCommand.parser.parse(['arg1', 'arg2']);
      final exitCode = deleteCommand.validate(results);

      expect(exitCode, ExitCode.invalidArguments);
    });
  });
}
