import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gwm/src/services/completion_service.dart';

import 'package:gwm/src/models/worktree.dart';
import '../../mock_objects/mock_git_client.dart';

void main() {
  group('CompletionService', () {
    late MockGitClient mockGitClient;
    late CompletionService completionService;

    setUp(() {
      mockGitClient = MockGitClient();
      completionService = CompletionService(mockGitClient);
    });

    group('getWorktreeCompletions', () {
      test(
        'returns worktree names with main workspace dot when successful',
        () async {
          final mockWorktrees = [
            Worktree(
              name: 'feature-branch',
              branch: 'feature/branch',
              path: '/path/to/feature',
              isMain: false,
              status: WorktreeStatus.clean,
            ),
            Worktree(
              name: 'bugfix',
              branch: 'bugfix/login',
              path: '/path/to/bugfix',
              isMain: false,
              status: WorktreeStatus.clean,
            ),
          ];

          when(
            () => mockGitClient.listWorktrees(),
          ).thenAnswer((_) async => mockWorktrees);

          final completions = await completionService.getWorktreeCompletions();

          expect(completions, ['.', 'feature-branch', 'bugfix']);
          verify(() => mockGitClient.listWorktrees()).called(1);
        },
      );

      test(
        'returns only dot when worktree list includes main workspace',
        () async {
          final mockWorktrees = [
            Worktree(
              name: '.',
              branch: 'main',
              path: '/main/path',
              isMain: true,
              status: WorktreeStatus.clean,
            ),
            Worktree(
              name: 'feature-branch',
              branch: 'feature/branch',
              path: '/path/to/feature',
              isMain: false,
              status: WorktreeStatus.clean,
            ),
          ];

          when(
            () => mockGitClient.listWorktrees(),
          ).thenAnswer((_) async => mockWorktrees);

          final completions = await completionService.getWorktreeCompletions();

          expect(completions, ['.', 'feature-branch']);
          verify(() => mockGitClient.listWorktrees()).called(1);
        },
      );

      test('returns only dot when listWorktrees throws exception', () async {
        when(
          () => mockGitClient.listWorktrees(),
        ).thenThrow(Exception('Git error'));

        final completions = await completionService.getWorktreeCompletions();

        expect(completions, ['.']);
        verify(() => mockGitClient.listWorktrees()).called(1);
      });

      test('returns only dot when listWorktrees returns empty list', () async {
        when(() => mockGitClient.listWorktrees()).thenAnswer((_) async => []);

        final completions = await completionService.getWorktreeCompletions();

        expect(completions, ['.']);
        verify(() => mockGitClient.listWorktrees()).called(1);
      });
    });

    group('getWorktreeCompletionsExcludingCurrent', () {
      test(
        'returns worktree names excluding current worktree when in main workspace',
        () async {
          final mockWorktrees = [
            Worktree(
              name: 'feature-branch',
              branch: 'feature/branch',
              path: '/path/to/feature',
              isMain: false,
              status: WorktreeStatus.clean,
            ),
            Worktree(
              name: 'bugfix',
              branch: 'bugfix/login',
              path: '/path/to/bugfix',
              isMain: false,
              status: WorktreeStatus.clean,
            ),
          ];

          when(() => mockGitClient.isWorktree()).thenAnswer((_) async => false);
          when(
            () => mockGitClient.listWorktrees(),
          ).thenAnswer((_) async => mockWorktrees);

          final completions = await completionService
              .getWorktreeCompletionsExcludingCurrent();

          expect(completions, ['feature-branch', 'bugfix']);
          verify(() => mockGitClient.isWorktree()).called(1);
          verify(() => mockGitClient.listWorktrees()).called(1);
          verifyNever(() => mockGitClient.getCurrentBranch());
        },
      );

      test(
        'returns worktree names excluding current worktree when in a worktree',
        () async {
          final mockWorktrees = [
            Worktree(
              name: 'feature-branch',
              branch: 'feature/branch',
              path: '/path/to/feature',
              isMain: false,
              status: WorktreeStatus.clean,
            ),
            Worktree(
              name: 'bugfix',
              branch: 'bugfix',
              path: '/path/to/bugfix',
              isMain: false,
              status: WorktreeStatus.clean,
            ),
          ];

          when(() => mockGitClient.isWorktree()).thenAnswer((_) async => true);
          when(
            () => mockGitClient.getCurrentBranch(),
          ).thenAnswer((_) async => 'bugfix');
          when(
            () => mockGitClient.listWorktrees(),
          ).thenAnswer((_) async => mockWorktrees);

          final completions = await completionService
              .getWorktreeCompletionsExcludingCurrent();

          expect(completions, ['.', 'feature-branch']);
          verify(() => mockGitClient.isWorktree()).called(1);
          verify(() => mockGitClient.getCurrentBranch()).called(1);
          verify(() => mockGitClient.listWorktrees()).called(1);
        },
      );

      test(
        'returns only dot when all worktrees are current worktree',
        () async {
          final mockWorktrees = [
            Worktree(
              name: 'feature-branch',
              branch: 'feature-branch',
              path: '/path/to/feature',
              isMain: false,
              status: WorktreeStatus.clean,
            ),
          ];

          when(() => mockGitClient.isWorktree()).thenAnswer((_) async => true);
          when(
            () => mockGitClient.getCurrentBranch(),
          ).thenAnswer((_) async => 'feature-branch');
          when(
            () => mockGitClient.listWorktrees(),
          ).thenAnswer((_) async => mockWorktrees);

          final completions = await completionService
              .getWorktreeCompletionsExcludingCurrent();

          expect(completions, ['.']);
          verify(() => mockGitClient.isWorktree()).called(1);
          verify(() => mockGitClient.getCurrentBranch()).called(1);
          verify(() => mockGitClient.listWorktrees()).called(1);
        },
      );

      test('handles errors gracefully', () async {
        when(
          () => mockGitClient.isWorktree(),
        ).thenThrow(Exception('Git error'));
        when(() => mockGitClient.listWorktrees()).thenAnswer((_) async => []);

        final completions = await completionService
            .getWorktreeCompletionsExcludingCurrent();

        expect(completions, []);
        verify(() => mockGitClient.isWorktree()).called(1);
        verify(() => mockGitClient.listWorktrees()).called(1);
        verifyNever(() => mockGitClient.getCurrentBranch());
      });
    });

    group('getBranchCompletions', () {
      test('returns branch names when successful', () async {
        final mockBranches = [
          'main',
          'feature/auth',
          'bugfix/login',
          'develop',
        ];

        when(
          () => mockGitClient.listBranches(),
        ).thenAnswer((_) async => mockBranches);

        final completions = await completionService.getBranchCompletions();

        expect(completions, mockBranches);
        verify(() => mockGitClient.listBranches()).called(1);
      });

      test('returns empty list when listBranches throws exception', () async {
        when(
          () => mockGitClient.listBranches(),
        ).thenThrow(Exception('Git error'));

        final completions = await completionService.getBranchCompletions();

        expect(completions, isEmpty);
        verify(() => mockGitClient.listBranches()).called(1);
      });

      test('returns empty list when listBranches returns empty list', () async {
        when(() => mockGitClient.listBranches()).thenAnswer((_) async => []);

        final completions = await completionService.getBranchCompletions();

        expect(completions, isEmpty);
        verify(() => mockGitClient.listBranches()).called(1);
      });
    });

    group('getConfigCompletions', () {
      test('returns expected config keys', () {
        final completions = completionService.getConfigCompletions();

        expect(completions, [
          'version',
          'copy.files',
          'copy.directories',
          'hooks.timeout',
          'hooks.pre_add',
          'hooks.post_add',
          'hooks.pre_switch',
          'hooks.post_switch',
          'hooks.pre_delete',
          'hooks.post_delete',
          'shell_integration.enable_eval_output',
        ]);
      });
    });

    group('getCommandCompletions', () {
      test('returns expected subcommands', () {
        final completions = completionService.getCommandCompletions();

        expect(completions, ['add', 'switch', 'delete', 'list']);
      });
    });

    group('getCompletions', () {
      test(
        'returns filtered command completions when command is null and partial is empty',
        () async {
          final completions = await completionService.getCompletions();

          expect(completions, ['add', 'switch', 'delete', 'list']);
        },
      );

      test(
        'returns filtered command completions when command is null and partial matches',
        () async {
          final completions = await completionService.getCompletions(
            partial: 'sw',
          );

          expect(completions, ['switch']);
        },
      );

      test(
        'returns filtered command completions when command is null and partial does not match',
        () async {
          final completions = await completionService.getCompletions(
            partial: 'xyz',
          );

          expect(completions, isEmpty);
        },
      );

      test(
        'returns branch completions for add command at position 0',
        () async {
          final mockBranches = ['main', 'feature/auth', 'develop'];
          when(
            () => mockGitClient.listBranches(),
          ).thenAnswer((_) async => mockBranches);

          final completions = await completionService.getCompletions(
            command: 'add',
            position: 0,
          );

          expect(completions, mockBranches);
          verify(() => mockGitClient.listBranches()).called(1);
        },
      );

      test(
        'returns filtered branch completions for add command with partial input',
        () async {
          final mockBranches = [
            'main',
            'feature/auth',
            'feature/ui',
            'develop',
          ];
          when(
            () => mockGitClient.listBranches(),
          ).thenAnswer((_) async => mockBranches);

          final completions = await completionService.getCompletions(
            command: 'add',
            partial: 'feature',
            position: 0,
          );

          expect(completions, ['feature/auth', 'feature/ui']);
          verify(() => mockGitClient.listBranches()).called(1);
        },
      );

      test(
        'returns worktree completions for switch command at position 0',
        () async {
          final mockWorktrees = [
            Worktree(
              name: 'feature-branch',
              branch: 'feature/branch',
              path: '/path/to/feature',
              isMain: false,
              status: WorktreeStatus.clean,
            ),
          ];
          when(
            () => mockGitClient.isWorktree(),
          ).thenAnswer((_) async => false); // In main workspace
          when(
            () => mockGitClient.listWorktrees(),
          ).thenAnswer((_) async => mockWorktrees);

          final completions = await completionService.getCompletions(
            command: 'switch',
            position: 0,
          );

          expect(completions, ['feature-branch']);
          verify(
            () => mockGitClient.isWorktree(),
          ).called(1); // Called in getWorktreeCompletionsExcludingCurrent
          verify(() => mockGitClient.listWorktrees()).called(1);
          verifyNever(() => mockGitClient.getCurrentBranch());
        },
      );

      test('returns empty list for list command', () async {
        final completions = await completionService.getCompletions(
          command: 'list',
          position: 0,
        );

        expect(completions, isEmpty);
      });

      test('returns empty list for unknown command', () async {
        final completions = await completionService.getCompletions(
          command: 'unknown',
          position: 0,
        );

        expect(completions, isEmpty);
      });

      test('handles errors in branch completion gracefully', () async {
        when(
          () => mockGitClient.listBranches(),
        ).thenThrow(Exception('Git error'));

        final completions = await completionService.getCompletions(
          command: 'add',
          position: 0,
        );

        expect(completions, isEmpty);
        verify(() => mockGitClient.listBranches()).called(1);
      });

      test('handles errors in worktree completion gracefully', () async {
        when(
          () => mockGitClient.isWorktree(),
        ).thenThrow(Exception('Git error'));
        when(() => mockGitClient.listWorktrees()).thenAnswer((_) async => []);

        final completions = await completionService.getCompletions(
          command: 'switch',
          position: 0,
        );

        expect(completions, []);
        verify(() => mockGitClient.isWorktree()).called(1);
        verify(() => mockGitClient.listWorktrees()).called(1);
        verifyNever(() => mockGitClient.getCurrentBranch());
      });
    });
  });
}
