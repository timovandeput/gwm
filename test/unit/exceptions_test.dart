import 'package:test/test.dart';
import 'package:gwm/src/exceptions.dart';
import 'package:gwm/src/models/exit_codes.dart';

void main() {
  group('GwmException', () {
    test('is base class for all exceptions', () {
      final exception = WorktreeExistsException('test-worktree');
      expect(exception, isA<GwmException>());
    });
  });

  group('WorktreeExistsException', () {
    const exception = WorktreeExistsException('feature-auth');

    test('has correct exit code', () {
      expect(exception.exitCode, equals(ExitCode.worktreeExists));
    });

    test('has correct message', () {
      expect(
        exception.message,
        equals('Worktree "feature-auth" already exists'),
      );
    });

    test('stores worktree name', () {
      expect(exception.worktreeName, equals('feature-auth'));
    });

    test('toString returns message', () {
      expect(exception.toString(), equals(exception.message));
    });
  });

  group('BranchNotFoundException', () {
    const exception = BranchNotFoundException('feature/missing');

    test('has correct exit code', () {
      expect(exception.exitCode, equals(ExitCode.branchNotFound));
    });

    test('has correct message', () {
      expect(exception.message, equals('Branch "feature/missing" not found'));
    });

    test('stores branch name', () {
      expect(exception.branch, equals('feature/missing'));
    });
  });

  group('HookExecutionException', () {
    final exception = HookExecutionException(
      'post_add',
      'npm install',
      'npm ERR! missing script: install',
    );

    test('has correct exit code', () {
      expect(exception.exitCode, equals(ExitCode.hookFailed));
    });

    test('has correct message format', () {
      expect(
        exception.message,
        equals(
          'Hook "post_add" failed: Command "npm install" exited with error:\nnpm ERR! missing script: install',
        ),
      );
    });

    test('stores hook details', () {
      expect(exception.hookName, equals('post_add'));
      expect(exception.command, equals('npm install'));
      expect(exception.output, equals('npm ERR! missing script: install'));
    });
  });

  group('ConfigException', () {
    const exception = ConfigException('/path/to/.gwm.json', 'invalid json');

    test('has correct exit code', () {
      expect(exception.exitCode, equals(ExitCode.configError));
    });

    test('has correct message', () {
      expect(
        exception.message,
        equals('Configuration error in "/path/to/.gwm.json": invalid json'),
      );
    });

    test('stores config details', () {
      expect(exception.configPath, equals('/path/to/.gwm.json'));
      expect(exception.reason, equals('invalid json'));
    });
  });

  group('GitException', () {
    final exception = GitException('git worktree add', [
      '/path',
      'branch',
    ], 'fatal: Invalid path');

    test('has correct exit code', () {
      expect(exception.exitCode, equals(ExitCode.gitFailed));
    });

    test('has correct message format', () {
      expect(
        exception.message,
        equals(
          'Git command failed: "git worktree add /path branch"\nfatal: Invalid path',
        ),
      );
    });

    test('stores git details', () {
      expect(exception.command, equals('git worktree add'));
      expect(exception.arguments, equals(['/path', 'branch']));
      expect(exception.output, equals('fatal: Invalid path'));
    });

    test('toString returns message', () {
      expect(exception.toString(), equals(exception.message));
    });
  });

  group('NoWorktreesAvailableException', () {
    const exception = NoWorktreesAvailableException();

    test('has correct exit code', () {
      expect(exception.exitCode, equals(ExitCode.invalidArguments));
    });

    test('has correct message', () {
      expect(exception.message, equals('No worktrees available to switch to.'));
    });

    test('toString returns message', () {
      expect(exception.toString(), equals(exception.message));
    });
  });

  group('ShellWrapperMissingException', () {
    const exception = ShellWrapperMissingException('Shell wrapper not found');

    test('has correct exit code', () {
      expect(exception.exitCode, equals(ExitCode.shellWrapperMissing));
    });

    test('has correct message', () {
      expect(exception.message, equals('Shell wrapper not found'));
    });

    test('toString returns message', () {
      expect(exception.toString(), equals(exception.message));
    });
  });
}
