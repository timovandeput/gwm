import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gwm/src/commands/clean.dart';
import 'package:gwm/src/models/exit_codes.dart';
import 'package:gwm/src/models/config.dart';
import 'package:gwm/src/infrastructure/git_client.dart';
import 'package:gwm/src/services/config_service.dart';

// Mock classes
class MockGitClient extends Mock implements GitClient {}

class MockConfigService extends Mock implements ConfigService {}

void main() {
  late MockGitClient mockGitClient;
  late MockConfigService mockConfigService;
  late CleanCommand cleanCommand;

  setUp(() {
    mockGitClient = MockGitClient();
    mockConfigService = MockConfigService();
    cleanCommand = CleanCommand(
      gitClient: mockGitClient,
      configService: mockConfigService,
    );

    // Register fallback values for mocks
    registerFallbackValue('');
  });

  group('CleanCommand', () {
    test('shows help message when --help flag is provided', () async {
      final results = cleanCommand.parser.parse(['--help']);
      final exitCode = await cleanCommand.execute(results);
      expect(exitCode, ExitCode.success);
    });

    test('fails when not in a worktree', () async {
      when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);

      final results = cleanCommand.parser.parse([]);
      final exitCode = await cleanCommand.execute(results);

      expect(exitCode, ExitCode.invalidArguments);
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
        () => mockGitClient.getMainRepoPath(),
      ).thenAnswer((_) async => '/path/to/main');
      when(() => mockGitClient.removeWorktree(any())).thenAnswer((_) async {});

      final results = cleanCommand.parser.parse(['--force']);
      final exitCode = await cleanCommand.execute(results);

      expect(exitCode, ExitCode.success);
      verify(() => mockGitClient.removeWorktree(any())).called(1);
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
        () => mockGitClient.getMainRepoPath(),
      ).thenAnswer((_) async => '/path/to/main');
      when(() => mockGitClient.removeWorktree(any())).thenAnswer((_) async {});

      final results = cleanCommand.parser.parse([]);
      final exitCode = await cleanCommand.execute(results);

      expect(exitCode, ExitCode.success);
      verify(() => mockGitClient.removeWorktree(any())).called(1);
    });

    test('handles Git command failures', () async {
      when(() => mockGitClient.isWorktree()).thenAnswer((_) async => true);
      when(() => mockGitClient.getRepoRoot()).thenThrow(Exception('Git error'));

      final results = cleanCommand.parser.parse([]);
      final exitCode = await cleanCommand.execute(results);

      expect(exitCode, ExitCode.gitFailed);
    });
  });
}
