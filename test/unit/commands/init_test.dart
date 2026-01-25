import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:io';

import 'package:gwm/src/commands/init.dart';
import 'package:gwm/src/models/exit_codes.dart';
import 'package:gwm/src/infrastructure/git_client.dart';
import 'package:gwm/src/exceptions.dart';

// Mock classes
class MockGitClient extends Mock implements GitClient {}

void main() {
  late MockGitClient mockGitClient;
  late InitCommand initCommand;

  setUp(() {
    mockGitClient = MockGitClient();
    initCommand = InitCommand(mockGitClient);

    // Register fallback values for mocks
    registerFallbackValue('');
  });

  group('InitCommand', () {
    test('shows help message when --help flag is provided', () async {
      final result = await initCommand.execute(
        initCommand.parser.parse(['--help']),
      );

      expect(result, equals(ExitCode.success));
    });

    test('returns success when config file is created successfully', () async {
      final tempDir = Directory.systemTemp.createTempSync('gwm_init_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      when(
        () => mockGitClient.getRepoRoot(),
      ).thenAnswer((_) async => tempDir.path);
      when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);

      final result = await initCommand.execute(initCommand.parser.parse([]));

      expect(result, equals(ExitCode.success));
      verify(() => mockGitClient.getRepoRoot()).called(1);
      verify(() => mockGitClient.isWorktree()).called(1);

      // Verify the config file was created
      final configFile = File('${tempDir.path}/.gwm.json');
      expect(configFile.existsSync(), isTrue);

      final content = configFile.readAsStringSync();
      expect(content, contains('"timeout": 30'));
      expect(content, contains('"preCreate": []'));
      expect(content, isNot(contains('"version"')));
      expect(content, isNot(contains('"enableEvalOutput"')));
    });

    test('returns error when not in a Git repository', () async {
      when(() => mockGitClient.getRepoRoot()).thenThrow(
        GitException('rev-parse', [
          '--show-toplevel',
        ], 'fatal: not a git repository'),
      );

      final result = await initCommand.execute(initCommand.parser.parse([]));

      expect(result, equals(ExitCode.gitFailed));
    });

    test('returns error when run from within a worktree', () async {
      when(
        () => mockGitClient.getRepoRoot(),
      ).thenAnswer((_) async => '/repo/root');
      when(() => mockGitClient.isWorktree()).thenAnswer((_) async => true);

      final result = await initCommand.execute(initCommand.parser.parse([]));

      expect(result, equals(ExitCode.generalError));
    });

    test('returns error when config file already exists', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'gwm_init_test_existing_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      // Create existing config file
      final configFile = File('${tempDir.path}/.gwm.json');
      configFile.writeAsStringSync('{}');

      when(
        () => mockGitClient.getRepoRoot(),
      ).thenAnswer((_) async => tempDir.path);
      when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);

      final result = await initCommand.execute(initCommand.parser.parse([]));

      expect(result, equals(ExitCode.generalError));
    });
  });
}
