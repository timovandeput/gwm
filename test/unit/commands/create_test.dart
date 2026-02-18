import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gwm/src/commands/create.dart';
import 'package:gwm/src/models/exit_codes.dart';
import 'package:gwm/src/services/worktree_service.dart';
import 'package:gwm/src/services/config_service.dart';
import 'package:gwm/src/services/shell_integration.dart';
import 'package:gwm/src/services/hook_service.dart';
import 'package:gwm/src/models/config.dart';

import '../../mock_objects/mock_git_client.dart';

// Mock classes
class MockWorktreeService extends Mock implements WorktreeService {}

class MockConfigService extends Mock implements ConfigService {}

class MockShellIntegration extends Mock implements ShellIntegration {}

class MockHookService extends Mock implements HookService {}

void main() {
  late MockWorktreeService mockWorktreeService;
  late MockConfigService mockConfigService;
  late MockShellIntegration mockShellIntegration;
  late MockHookService mockHookService;
  late MockGitClient mockGitClient;
  late CreateCommand createCommand;

  setUp(() {
    mockWorktreeService = MockWorktreeService();
    mockConfigService = MockConfigService();
    mockShellIntegration = MockShellIntegration();
    mockHookService = MockHookService();
    mockGitClient = MockGitClient();

    createCommand = CreateCommand(
      mockWorktreeService,
      mockConfigService,
      mockShellIntegration,
      mockHookService,
      mockGitClient,
    );

    // Register fallback values for mocks
    registerFallbackValue('');
    registerFallbackValue(
      const Config(
        version: '1.0',
        copy: CopyConfig(files: [], directories: []),
        hooks: HooksConfig(timeout: 30),
        shellIntegration: ShellIntegrationConfig(enableEvalOutput: false),
      ),
    );

    // Mock GitClient methods
    when(
      () => mockGitClient.getRepoRoot(),
    ).thenAnswer((_) async => '/mock/repo/root');
  });

  group('CreateCommand', () {
    test('shows help message when --help flag is provided', () async {
      final results = createCommand.parser.parse(['--help']);
      final exitCode = await createCommand.execute(results);
      expect(exitCode, ExitCode.success);
    });

    test('returns invalidArguments when no branch is provided', () async {
      final results = createCommand.parser.parse([]);
      final exitCode = await createCommand.execute(results);
      expect(exitCode, ExitCode.invalidArguments);
    });

    test('returns invalidArguments when too many arguments are provided', () {
      final results = createCommand.parser.parse(['branch1', 'branch2']);
      final exitCode = createCommand.validate(results);
      expect(exitCode, ExitCode.invalidArguments);
    });

    test('calls worktreeService.addWorktree with correct arguments', () async {
      const branch = 'feature/test';
      final results = createCommand.parser.parse([branch]);

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
        () => mockWorktreeService.createWorktree(
          branch,
          createBranch: false,
          config: any(named: 'config'),
        ),
      ).thenAnswer((_) async => ExitCode.success);

      when(
        () => mockWorktreeService.getWorktreePath(branch),
      ).thenAnswer((_) async => '/worktree/path');

      final exitCode = await createCommand.execute(results);

      expect(exitCode, ExitCode.success);
      verify(
        () => mockWorktreeService.createWorktree(
          branch,
          createBranch: false,
          config: any(named: 'config'),
        ),
      ).called(1);
      verify(
        () => mockShellIntegration.outputWorktreeCreated('/worktree/path'),
      ).called(1);
    });

    test(
      'calls worktreeService.addWorktree with createBranch true when -b flag is provided',
      () async {
        const branch = 'feature/test';
        final results = createCommand.parser.parse(['-b', branch]);

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
          () => mockWorktreeService.createWorktree(
            branch,
            createBranch: true,
            config: any(named: 'config'),
          ),
        ).thenAnswer((_) async => ExitCode.success);

        when(
          () => mockWorktreeService.getWorktreePath(branch),
        ).thenAnswer((_) async => '/worktree/path');

        final exitCode = await createCommand.execute(results);

        expect(exitCode, ExitCode.success);
        verify(
          () => mockWorktreeService.createWorktree(
            branch,
            createBranch: true,
            config: any(named: 'config'),
          ),
        ).called(1);
        verify(
          () => mockShellIntegration.outputWorktreeCreated('/worktree/path'),
        ).called(1);
      },
    );

    test('returns exit code from worktreeService.addWorktree', () async {
      const branch = 'feature/test';
      final results = createCommand.parser.parse([branch]);

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
        () => mockWorktreeService.createWorktree(
          branch,
          createBranch: false,
          config: any(named: 'config'),
        ),
      ).thenAnswer((_) async => ExitCode.gitFailed);

      final exitCode = await createCommand.execute(results);

      expect(exitCode, ExitCode.gitFailed);
      verifyNever(() => mockShellIntegration.outputWorktreeCreated(any()));
    });

    test(
      'switches to existing worktree when worktree already exists',
      () async {
        const branch = 'existing-feature';
        final results = createCommand.parser.parse([branch]);

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
          () => mockWorktreeService.createWorktree(
            branch,
            createBranch: false,
            config: any(named: 'config'),
          ),
        ).thenAnswer((_) async => ExitCode.worktreeExistsButSwitched);

        when(
          () => mockWorktreeService.getWorktreePath(branch),
        ).thenAnswer((_) async => '/existing/worktree/path');

        final exitCode = await createCommand.execute(results);

        expect(exitCode, ExitCode.worktreeExistsButSwitched);
        verify(
          () => mockShellIntegration.outputCdCommand('/existing/worktree/path'),
        ).called(1);
        verifyNever(() => mockShellIntegration.outputWorktreeCreated(any()));
      },
    );
  });
}
