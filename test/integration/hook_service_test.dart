import 'package:test/test.dart';

import 'package:gwm/src/services/hook_service.dart';
import 'package:gwm/src/models/config.dart';
import 'package:gwm/src/models/hook.dart';
import 'package:gwm/src/exceptions.dart';
import '../mock_objects/fake_process_wrapper.dart';

void main() {
  group('HookService Integration', () {
    late HookService hookService;
    late FakeProcessWrapper fakeProcessWrapper;

    setUp(() {
      fakeProcessWrapper = FakeProcessWrapper();
      hookService = HookService(fakeProcessWrapper);
    });

    tearDown(() {
      fakeProcessWrapper.clearResponses();
    });

    group('executePreAdd with complex scenarios', () {
      test(
        'executes multiple commands with environment variable expansion',
        () async {
          fakeProcessWrapper.addResponse('sh', [
            '-c',
            'echo "Worktree: /complex/worktree"',
          ], stdout: 'Worktree: /complex/worktree\n');
          fakeProcessWrapper.addResponse('sh', [
            '-c',
            'echo "Origin: /complex/origin"',
          ], stdout: 'Origin: /complex/origin\n');
          fakeProcessWrapper.addResponse('sh', [
            '-c',
            'echo "Branch: complex-branch"',
          ], stdout: 'Branch: complex-branch\n');

          final config = HooksConfig(
            timeout: 30,
            preAdd: Hook.fromList([
              'echo "Worktree: \$GWM_WORKTREE_PATH"',
              'echo "Origin: \$GWM_ORIGIN_PATH"',
              'echo "Branch: \$GWM_BRANCH"',
            ]),
          );

          await hookService.executePreAdd(
            config,
            '/complex/worktree',
            '/complex/origin',
            'complex-branch',
          );
        },
      );

      test('stops execution on first command failure', () async {
        fakeProcessWrapper.addResponse('sh', [
          '-c',
          'echo "success"',
        ], stdout: 'success\n');
        fakeProcessWrapper.addResponse(
          'sh',
          ['-c', 'exit 1'],
          exitCode: 1,
          stderr: 'command failed\n',
        );
        fakeProcessWrapper.addResponse('sh', [
          '-c',
          'echo "should not execute"',
        ], stdout: 'should not execute\n');

        final config = HooksConfig(
          timeout: 30,
          preAdd: Hook.fromList([
            'echo "success"',
            'exit 1',
            'echo "should not execute"',
          ]),
        );

        expect(
          () => hookService.executePreAdd(
            config,
            '/fake/worktree',
            '/fake/origin',
            'test-branch',
          ),
          throwsA(isA<HookExecutionException>()),
        );

        // Verify the third command's response is still available (wasn't consumed)
        final result = await fakeProcessWrapper.run('sh', [
          '-c',
          'echo "should not execute"',
        ]);
        expect(result.stdout, 'should not execute\n');
      });

      test('handles hook-specific timeout override', () async {
        fakeProcessWrapper.addResponse('sh', [
          '-c',
          'echo "hook timeout test"',
        ], stdout: 'hook timeout test\n');

        final config = HooksConfig(
          timeout: 30, // Global timeout
          preAdd: Hook(
            commands: ['echo "hook timeout test"'],
            timeout: 60, // Hook-specific timeout
          ),
        );

        await hookService.executePreAdd(
          config,
          '/fake/worktree',
          '/fake/origin',
          'test-branch',
        );
      });
    });

    group('all hook phases', () {
      test('executePostAdd works', () async {
        fakeProcessWrapper.addResponse('sh', [
          '-c',
          'echo "post-add integration test"',
        ], stdout: 'post-add integration test\n');

        final config = HooksConfig(
          timeout: 30,
          postAdd: Hook.fromList(['echo "post-add integration test"']),
        );

        await hookService.executePostAdd(
          config,
          '/fake/worktree',
          '/fake/origin',
          'test-branch',
        );
      });

      test('executePreSwitch works', () async {
        fakeProcessWrapper.addResponse('sh', [
          '-c',
          'echo "pre-switch integration test"',
        ], stdout: 'pre-switch integration test\n');

        final config = HooksConfig(
          timeout: 30,
          preSwitch: Hook.fromList(['echo "pre-switch integration test"']),
        );

        await hookService.executePreSwitch(
          config,
          '/fake/worktree',
          '/fake/origin',
          'test-branch',
        );
      });

      test('executePostSwitch works', () async {
        fakeProcessWrapper.addResponse('sh', [
          '-c',
          'echo "post-switch integration test"',
        ], stdout: 'post-switch integration test\n');

        final config = HooksConfig(
          timeout: 30,
          postSwitch: Hook.fromList(['echo "post-switch integration test"']),
        );

        await hookService.executePostSwitch(
          config,
          '/fake/worktree',
          '/fake/origin',
          'test-branch',
        );
      });

      test('executePreClean works', () async {
        fakeProcessWrapper.addResponse('sh', [
          '-c',
          'echo "pre-clean integration test"',
        ], stdout: 'pre-clean integration test\n');

        final config = HooksConfig(
          timeout: 30,
          preClean: Hook.fromList(['echo "pre-clean integration test"']),
        );

        await hookService.executePreClean(
          config,
          '/fake/worktree',
          '/fake/origin',
          'test-branch',
        );
      });

      test('executePostClean works', () async {
        fakeProcessWrapper.addResponse('sh', [
          '-c',
          'echo "post-clean integration test"',
        ], stdout: 'post-clean integration test\n');

        final config = HooksConfig(
          timeout: 30,
          postClean: Hook.fromList(['echo "post-clean integration test"']),
        );

        await hookService.executePostClean(
          config,
          '/fake/worktree',
          '/fake/origin',
          'test-branch',
        );
      });
    });
  });
}
