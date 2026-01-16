import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gwm/src/commands/list.dart';
import 'package:gwm/src/models/exit_codes.dart';
import 'package:gwm/src/models/worktree.dart';
import 'package:gwm/src/infrastructure/git_client.dart';
import 'package:gwm/src/utils/output_formatter.dart';
import 'package:gwm/src/exceptions.dart';

// Mock classes
class MockGitClient extends Mock implements GitClient {}

class MockOutputFormatter extends Mock implements OutputFormatter {}

void main() {
  late MockGitClient mockGitClient;
  late MockOutputFormatter mockFormatter;
  late ListCommand listCommand;

  setUp(() {
    mockGitClient = MockGitClient();
    mockFormatter = MockOutputFormatter();
    listCommand = ListCommand(mockGitClient, mockFormatter);

    // Register fallback values for mocks
    registerFallbackValue('');
  });

  group('ListCommand', () {
    test('shows help message when --help flag is provided', () async {
      final results = listCommand.parser.parse(['--help']);
      final exitCode = await listCommand.execute(results);
      expect(exitCode, ExitCode.success);
    });

    test('lists worktrees in table format by default', () async {
      final worktrees = [
        Worktree(
          name: 'main',
          branch: 'main',
          path: '/repo/path',
          isMain: true,
          status: WorktreeStatus.clean,
        ),
        Worktree(
          name: 'feature',
          branch: 'feature/branch',
          path: '/repo/feature',
          isMain: false,
          status: WorktreeStatus.clean,
        ),
      ];

      when(
        () => mockGitClient.listWorktrees(),
      ).thenAnswer((_) async => worktrees);
      when(
        () => mockFormatter.formatTable(any(), any(), verbose: false),
      ).thenReturn('table output');

      final results = listCommand.parser.parse([]);
      final exitCode = await listCommand.execute(results);

      expect(exitCode, ExitCode.success);
      verify(() => mockGitClient.listWorktrees()).called(1);
    });

    test(
      'lists worktrees in verbose table format when --verbose flag is provided',
      () async {
        final worktrees = [
          Worktree(
            name: 'main',
            branch: 'main',
            path: '/repo/path',
            isMain: true,
            status: WorktreeStatus.clean,
          ),
        ];

        when(
          () => mockGitClient.listWorktrees(),
        ).thenAnswer((_) async => worktrees);
        when(
          () => mockFormatter.formatTable(any(), any(), verbose: true),
        ).thenReturn('verbose table output');

        final results = listCommand.parser.parse(['--verbose']);
        final exitCode = await listCommand.execute(results);

        expect(exitCode, ExitCode.success);
        verify(() => mockGitClient.listWorktrees()).called(1);
      },
    );

    test(
      'lists worktrees in JSON format when --json flag is provided',
      () async {
        final worktrees = [
          Worktree(
            name: 'main',
            branch: 'main',
            path: '/repo/path',
            isMain: true,
            status: WorktreeStatus.clean,
          ),
        ];

        when(
          () => mockGitClient.listWorktrees(),
        ).thenAnswer((_) async => worktrees);
        when(
          () => mockFormatter.formatJson(any(), any()),
        ).thenReturn('{"json": "output"}');

        final results = listCommand.parser.parse(['--json']);
        final exitCode = await listCommand.execute(results);

        expect(exitCode, ExitCode.success);
        verify(() => mockGitClient.listWorktrees()).called(1);
        verify(() => mockFormatter.formatJson(any(), any())).called(1);
      },
    );

    test('handles empty worktree list', () async {
      when(() => mockGitClient.listWorktrees()).thenAnswer((_) async => []);
      when(
        () => mockFormatter.formatTable(any(), any(), verbose: false),
      ).thenReturn('No worktrees found.');

      final results = listCommand.parser.parse([]);
      final exitCode = await listCommand.execute(results);

      expect(exitCode, ExitCode.success);
      verify(() => mockGitClient.listWorktrees()).called(1);
    });

    test(
      'returns git failed exit code when GitClient throws exception',
      () async {
        when(() => mockGitClient.listWorktrees()).thenThrow(
          GitException('worktree', ['list', '--porcelain'], 'fatal: git error'),
        );

        final results = listCommand.parser.parse([]);
        final exitCode = await listCommand.execute(results);

        expect(exitCode, ExitCode.gitFailed);
        verify(() => mockGitClient.listWorktrees()).called(1);
        verifyNever(
          () => mockFormatter.formatTable(
            any(),
            any(),
            verbose: any(named: 'verbose'),
          ),
        );
      },
    );
  });
}
