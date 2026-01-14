import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gwt/src/commands/add.dart';
import 'package:gwt/src/models/exit_codes.dart';
import 'package:gwt/src/services/worktree_service.dart';
import 'package:gwt/src/infrastructure/git_client.dart';
import 'package:gwt/src/services/shell_integration.dart';

// Mock classes
class MockWorktreeService extends Mock implements WorktreeService {}

class MockGitClient extends Mock implements GitClient {}

class MockShellIntegration extends Mock implements ShellIntegration {}

void main() {
  late MockWorktreeService mockWorktreeService;
  late MockGitClient mockGitClient;
  late MockShellIntegration mockShellIntegration;
  late AddCommand addCommand;

  setUp(() {
    mockWorktreeService = MockWorktreeService();
    mockGitClient = MockGitClient();
    mockShellIntegration = MockShellIntegration();
    addCommand = AddCommand(
      worktreeService: mockWorktreeService,
      gitClient: mockGitClient,
      shellIntegration: mockShellIntegration,
    );

    // Register fallback values for mocks
    registerFallbackValue('');
  });

  group('AddCommand', () {
    test('shows help message when --help flag is provided', () async {
      final results = addCommand.parser.parse(['--help']);
      final exitCode = await addCommand.execute(results);
      expect(exitCode, ExitCode.success);
    });

    test('returns invalidArguments when no branch is provided', () async {
      final results = addCommand.parser.parse([]);
      final exitCode = await addCommand.execute(results);
      expect(exitCode, ExitCode.invalidArguments);
    });

    test(
      'returns invalidArguments when too many arguments are provided',
      () async {
        final results = addCommand.parser.parse(['branch1', 'branch2']);
        final exitCode = addCommand.validate(results);
        expect(exitCode, ExitCode.invalidArguments);
      },
    );

    test('calls worktreeService.addWorktree with correct arguments', () async {
      const branch = 'feature/test';
      final results = addCommand.parser.parse([branch]);

      when(
        () => mockWorktreeService.addWorktree(branch, createBranch: false),
      ).thenAnswer((_) async => ExitCode.success);

      when(
        () => mockWorktreeService.getWorktreePath(branch),
      ).thenAnswer((_) async => '/worktree/path');

      final exitCode = await addCommand.execute(results);

      expect(exitCode, ExitCode.success);
      verify(
        () => mockWorktreeService.addWorktree(branch, createBranch: false),
      ).called(1);
      verify(
        () => mockShellIntegration.outputWorktreeCreated('/worktree/path'),
      ).called(1);
    });

    test(
      'calls worktreeService.addWorktree with createBranch true when -b flag is provided',
      () async {
        const branch = 'feature/test';
        final results = addCommand.parser.parse(['-b', branch]);

        when(
          () => mockWorktreeService.addWorktree(branch, createBranch: true),
        ).thenAnswer((_) async => ExitCode.success);

        when(
          () => mockWorktreeService.getWorktreePath(branch),
        ).thenAnswer((_) async => '/worktree/path');

        final exitCode = await addCommand.execute(results);

        expect(exitCode, ExitCode.success);
        verify(
          () => mockWorktreeService.addWorktree(branch, createBranch: true),
        ).called(1);
        verify(
          () => mockShellIntegration.outputWorktreeCreated('/worktree/path'),
        ).called(1);
      },
    );

    test('returns exit code from worktreeService.addWorktree', () async {
      const branch = 'feature/test';
      final results = addCommand.parser.parse([branch]);

      when(
        () => mockWorktreeService.addWorktree(branch, createBranch: false),
      ).thenAnswer((_) async => ExitCode.gitFailed);

      final exitCode = await addCommand.execute(results);

      expect(exitCode, ExitCode.gitFailed);
      verifyNever(() => mockShellIntegration.outputWorktreeCreated(any()));
    });
  });
}
