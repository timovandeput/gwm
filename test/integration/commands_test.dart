import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gwm/src/commands/create.dart';
import 'package:gwm/src/commands/switch.dart';
import 'package:gwm/src/commands/delete.dart';
import 'package:gwm/src/commands/list.dart';
import 'package:gwm/src/models/config.dart';
import 'package:gwm/src/models/exit_codes.dart';
import 'package:gwm/src/models/worktree.dart';
import 'package:gwm/src/services/worktree_service.dart';
import 'package:gwm/src/services/config_service.dart';
import 'package:gwm/src/services/hook_service.dart';
import 'package:gwm/src/services/copy_service.dart';
import 'package:gwm/src/services/shell_integration.dart';
import 'package:gwm/src/infrastructure/prompt_selector.dart';
import 'package:gwm/src/infrastructure/file_system_adapter.dart';
import 'package:gwm/src/utils/output_formatter.dart';

import '../mock_objects/fake_process_wrapper.dart';
import '../mock_objects/mock_git_client.dart';

class MockWorktreeService extends Mock implements WorktreeService {}

class MockConfigService extends Mock implements ConfigService {}

class MockPromptSelector extends Mock implements PromptSelector {}

void main() {
  registerFallbackValue('');
  registerFallbackValue(
    const Config(
      version: '1.0',
      copy: CopyConfig(files: [], directories: []),
      hooks: HooksConfig(timeout: 30),
      shellIntegration: ShellIntegrationConfig(enableEvalOutput: false),
    ),
  );

  group('CreateCommand Integration', () {
    late MockGitClient mockGitClient;
    late MockWorktreeService mockWorktreeService;
    late MockConfigService mockConfigService;
    late HookService hookService;
    late ShellIntegration shellIntegration;
    late FakeProcessWrapper fakeProcessWrapper;
    late CreateCommand createCommand;

    setUp(() {
      mockGitClient = MockGitClient();
      mockWorktreeService = MockWorktreeService();
      mockConfigService = MockConfigService();
      fakeProcessWrapper = FakeProcessWrapper();
      hookService = HookService(fakeProcessWrapper);
      shellIntegration = ShellIntegration(
        ShellIntegrationConfig(enableEvalOutput: true),
      );

      createCommand = CreateCommand(
        mockWorktreeService,
        mockConfigService,
        shellIntegration,
        hookService,
        mockGitClient,
        skipEvalCheck: true,
      );

      when(() => mockGitClient.getRepoRoot()).thenAnswer((_) async => '/repo');
      when(
        () => mockConfigService.loadConfig(repoRoot: any(named: 'repoRoot')),
      ).thenAnswer(
        (_) async => const Config(
          version: '1.0',
          copy: CopyConfig(files: [], directories: []),
          hooks: HooksConfig(timeout: 30),
          shellIntegration: ShellIntegrationConfig(enableEvalOutput: true),
        ),
      );
    });

    tearDown(() {
      fakeProcessWrapper.clearResponses();
    });

    test('shows help when --help flag is provided', () async {
      final results = createCommand.parser.parse(['--help']);
      final exitCode = await createCommand.execute(results);

      expect(exitCode, ExitCode.success);
    });

    test('returns error when no branch is provided', () async {
      final results = createCommand.parser.parse([]);
      final exitCode = await createCommand.execute(results);

      expect(exitCode, ExitCode.invalidArguments);
    });

    test('creates worktree for existing branch', () async {
      const branch = 'feature/test';
      final results = createCommand.parser.parse([branch]);

      when(
        () => mockWorktreeService.createWorktree(
          branch,
          createBranch: false,
          config: any(named: 'config'),
        ),
      ).thenAnswer((_) async => ExitCode.success);
      when(
        () => mockWorktreeService.getWorktreePath(branch),
      ).thenAnswer((_) async => '/worktrees/repo_feature_test');

      final exitCode = await createCommand.execute(results);

      expect(exitCode, ExitCode.success);
      verify(
        () => mockWorktreeService.createWorktree(
          branch,
          createBranch: false,
          config: any(named: 'config'),
        ),
      ).called(1);
    });

    test('creates worktree with -b flag for new branch', () async {
      const branch = 'brand-new-feature';
      final results = createCommand.parser.parse(['-b', branch]);

      when(
        () => mockWorktreeService.createWorktree(
          branch,
          createBranch: true,
          config: any(named: 'config'),
        ),
      ).thenAnswer((_) async => ExitCode.success);
      when(
        () => mockWorktreeService.getWorktreePath(branch),
      ).thenAnswer((_) async => '/worktrees/repo_brand_new_feature');

      final exitCode = await createCommand.execute(results);

      expect(exitCode, ExitCode.success);
      verify(
        () => mockWorktreeService.createWorktree(
          branch,
          createBranch: true,
          config: any(named: 'config'),
        ),
      ).called(1);
    });

    test(
      'switches to existing worktree when worktree already exists',
      () async {
        const branch = 'existing-branch';
        final results = createCommand.parser.parse([branch]);

        when(
          () => mockWorktreeService.createWorktree(
            branch,
            createBranch: false,
            config: any(named: 'config'),
          ),
        ).thenAnswer((_) async => ExitCode.worktreeExistsButSwitched);
        when(
          () => mockWorktreeService.getWorktreePath(branch),
        ).thenAnswer((_) async => '/worktrees/repo_existing_branch');

        final exitCode = await createCommand.execute(results);

        expect(exitCode, ExitCode.worktreeExistsButSwitched);
      },
    );

    test('handles worktree service failure', () async {
      const branch = 'failing-branch';
      final results = createCommand.parser.parse([branch]);

      when(
        () => mockWorktreeService.createWorktree(
          branch,
          createBranch: false,
          config: any(named: 'config'),
        ),
      ).thenAnswer((_) async => ExitCode.gitFailed);

      final exitCode = await createCommand.execute(results);

      expect(exitCode, ExitCode.gitFailed);
    });

    test('validates too many arguments', () {
      final results = createCommand.parser.parse(['branch1', 'branch2']);
      final exitCode = createCommand.validate(results);

      expect(exitCode, ExitCode.invalidArguments);
    });
  });

  group('SwitchCommand Integration', () {
    late MockGitClient mockGitClient;
    late MockConfigService mockConfigService;
    late MockPromptSelector mockPromptSelector;
    late HookService hookService;
    late CopyService copyService;
    late ShellIntegration shellIntegration;
    late FakeProcessWrapper fakeProcessWrapper;
    late SwitchCommand switchCommand;

    setUp(() {
      mockGitClient = MockGitClient();
      mockConfigService = MockConfigService();
      mockPromptSelector = MockPromptSelector();
      fakeProcessWrapper = FakeProcessWrapper();
      hookService = HookService(fakeProcessWrapper);
      copyService = CopyService(_FakeFileSystemAdapter());
      shellIntegration = ShellIntegration(
        ShellIntegrationConfig(enableEvalOutput: true),
      );

      switchCommand = SwitchCommand(
        mockGitClient,
        mockPromptSelector,
        mockConfigService,
        hookService,
        copyService,
        shellIntegration,
        skipEvalCheck: true,
      );

      when(() => mockGitClient.getRepoRoot()).thenAnswer((_) async => '/repo');
      when(() => mockGitClient.listWorktrees()).thenAnswer(
        (_) async => [
          Worktree(
            name: 'main',
            branch: 'main',
            path: '/repo',
            isMain: true,
            status: WorktreeStatus.clean,
          ),
          Worktree(
            name: 'feature',
            branch: 'feature/test',
            path: '/worktrees/repo_feature_test',
            isMain: false,
            status: WorktreeStatus.clean,
          ),
        ],
      );
      when(
        () => mockConfigService.loadConfig(repoRoot: any(named: 'repoRoot')),
      ).thenAnswer(
        (_) async => const Config(
          version: '1.0',
          copy: CopyConfig(files: [], directories: []),
          hooks: HooksConfig(timeout: 30),
          shellIntegration: ShellIntegrationConfig(enableEvalOutput: true),
        ),
      );
    });

    tearDown(() {
      fakeProcessWrapper.clearResponses();
    });

    test('shows help when --help flag is provided', () async {
      final results = switchCommand.parser.parse(['--help']);
      final exitCode = await switchCommand.execute(results);

      expect(exitCode, ExitCode.success);
    });

    test('switches to specified worktree', () async {
      final results = switchCommand.parser.parse(['feature']);

      final exitCode = await switchCommand.execute(results);

      expect(exitCode, ExitCode.success);
    });

    test('switches to main workspace with "."', () async {
      final results = switchCommand.parser.parse(['.']);

      final exitCode = await switchCommand.execute(results);

      expect(exitCode, ExitCode.success);
    });

    test('returns error for non-existent worktree', () async {
      final results = switchCommand.parser.parse(['nonexistent']);

      final exitCode = await switchCommand.execute(results);

      expect(exitCode, ExitCode.generalError);
    });

    test('validates too many arguments', () {
      final results = switchCommand.parser.parse(['worktree1', 'worktree2']);
      final exitCode = switchCommand.validate(results);

      expect(exitCode, ExitCode.invalidArguments);
    });

    test('handles reconfigure flag', () async {
      final results = switchCommand.parser.parse(['--reconfigure', 'feature']);

      final exitCode = await switchCommand.execute(results);

      expect(exitCode, ExitCode.success);
    });
  });

  group('DeleteCommand Integration', () {
    late MockGitClient mockGitClient;
    late MockConfigService mockConfigService;
    late HookService hookService;
    late ShellIntegration shellIntegration;
    late FakeProcessWrapper fakeProcessWrapper;
    late DeleteCommand deleteCommand;

    setUp(() {
      mockGitClient = MockGitClient();
      mockConfigService = MockConfigService();
      fakeProcessWrapper = FakeProcessWrapper();
      hookService = HookService(fakeProcessWrapper);
      shellIntegration = ShellIntegration(
        ShellIntegrationConfig(enableEvalOutput: true),
      );

      deleteCommand = DeleteCommand(
        mockGitClient,
        mockConfigService,
        hookService,
        shellIntegration,
        skipEvalCheck: true,
      );

      when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);
      when(() => mockGitClient.getRepoRoot()).thenAnswer((_) async => '/repo');
      when(
        () => mockGitClient.getMainRepoPath(),
      ).thenAnswer((_) async => '/repo');
      when(() => mockGitClient.listWorktrees()).thenAnswer(
        (_) async => [
          Worktree(
            name: 'main',
            branch: 'main',
            path: '/repo',
            isMain: true,
            status: WorktreeStatus.clean,
          ),
          Worktree(
            name: 'feature',
            branch: 'feature/test',
            path: '/worktrees/repo_feature_test',
            isMain: false,
            status: WorktreeStatus.clean,
          ),
        ],
      );
      when(
        () => mockGitClient.hasUncommittedChanges(any()),
      ).thenAnswer((_) async => false);
      when(
        () => mockGitClient.removeWorktree(any(), force: any(named: 'force')),
      ).thenAnswer((_) async {});
      when(
        () => mockConfigService.loadConfig(repoRoot: any(named: 'repoRoot')),
      ).thenAnswer(
        (_) async => const Config(
          version: '1.0',
          copy: CopyConfig(files: [], directories: []),
          hooks: HooksConfig(timeout: 30),
          shellIntegration: ShellIntegrationConfig(enableEvalOutput: true),
        ),
      );
    });

    tearDown(() {
      fakeProcessWrapper.clearResponses();
    });

    test('shows help when --help flag is provided', () async {
      final results = deleteCommand.parser.parse(['--help']);
      final exitCode = await deleteCommand.execute(results);

      expect(exitCode, ExitCode.success);
    });

    test('deletes specified worktree from main workspace', () async {
      final results = deleteCommand.parser.parse(['feature']);

      final exitCode = await deleteCommand.execute(results);

      expect(exitCode, ExitCode.success);
      verify(() => mockGitClient.removeWorktree(any())).called(1);
    });

    test('returns error when trying to delete main workspace', () async {
      final results = deleteCommand.parser.parse(['main']);

      final exitCode = await deleteCommand.execute(results);

      expect(exitCode, ExitCode.invalidArguments);
    });

    test('returns error for non-existent worktree', () async {
      final results = deleteCommand.parser.parse(['nonexistent']);

      final exitCode = await deleteCommand.execute(results);

      expect(exitCode, ExitCode.invalidArguments);
    });

    test('handles force flag', () async {
      when(
        () => mockGitClient.hasUncommittedChanges(any()),
      ).thenAnswer((_) async => true);

      final results = deleteCommand.parser.parse(['--force', 'feature']);

      final exitCode = await deleteCommand.execute(results);

      expect(exitCode, ExitCode.success);
    });

    test('returns error for uncommitted changes without force', () async {
      when(
        () => mockGitClient.hasUncommittedChanges(any()),
      ).thenAnswer((_) async => true);

      final results = deleteCommand.parser.parse(['feature']);

      final exitCode = await deleteCommand.execute(results);

      expect(exitCode, ExitCode.invalidArguments);
    });

    test('validates too many arguments', () {
      final results = deleteCommand.parser.parse(['worktree1', 'worktree2']);
      final exitCode = deleteCommand.validate(results);

      expect(exitCode, ExitCode.invalidArguments);
    });
  });

  group('ListCommand Integration', () {
    late MockGitClient mockGitClient;
    late OutputFormatter formatter;
    late ListCommand listCommand;

    setUp(() {
      mockGitClient = MockGitClient();
      formatter = OutputFormatter();

      listCommand = ListCommand(mockGitClient, formatter);

      when(() => mockGitClient.getRepoRoot()).thenAnswer((_) async => '/repo');
      when(() => mockGitClient.listWorktrees()).thenAnswer(
        (_) async => [
          Worktree(
            name: 'main',
            branch: 'main',
            path: '/repo',
            isMain: true,
            status: WorktreeStatus.clean,
          ),
          Worktree(
            name: 'feature-a',
            branch: 'feature/a',
            path: '/worktrees/repo_feature_a',
            isMain: false,
            status: WorktreeStatus.clean,
          ),
          Worktree(
            name: 'feature-b',
            branch: 'feature/b',
            path: '/worktrees/repo_feature_b',
            isMain: false,
            status: WorktreeStatus.modified,
          ),
        ],
      );
      when(
        () => mockGitClient.getLastCommitTime(any()),
      ).thenAnswer((_) async => DateTime.now());
    });

    test('shows help when --help flag is provided', () async {
      final results = listCommand.parser.parse(['--help']);
      final exitCode = await listCommand.execute(results);

      expect(exitCode, ExitCode.success);
    });

    test('lists all worktrees', () async {
      final results = listCommand.parser.parse([]);

      final exitCode = await listCommand.execute(results);

      expect(exitCode, ExitCode.success);
      verify(() => mockGitClient.listWorktrees()).called(1);
    });

    test('handles empty worktree list', () async {
      when(() => mockGitClient.listWorktrees()).thenAnswer((_) async => []);

      final results = listCommand.parser.parse([]);

      final exitCode = await listCommand.execute(results);

      expect(exitCode, ExitCode.success);
    });
  });
}

class _FakeFileSystemAdapter implements FileSystemAdapter {
  @override
  Future<void> copyDirectory(String source, String destination) async {}

  @override
  Future<void> copyFile(String source, String destination) async {}

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<void> deleteDirectory(String path) async {}

  @override
  Future<void> deleteFile(String path) async {}

  @override
  bool directoryExists(String path) => false;

  @override
  bool fileExists(String path) => false;

  @override
  Future<int> getFileSize(String path) async => 0;

  @override
  Future<DateTime> getLastModified(String path) async => DateTime.now();

  @override
  List<String> listContents(String path, {String? pattern}) => [];

  @override
  Future<String> readFile(String path) async => '';

  @override
  Future<void> writeFile(String path, String content) async {}
}
