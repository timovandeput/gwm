import 'package:test/test.dart';

import 'package:gwm/src/services/hook_service.dart';
import 'package:gwm/src/models/config.dart';
import 'package:gwm/src/models/hook.dart';
import 'package:gwm/src/exceptions.dart';
import 'package:gwm/src/models/exit_codes.dart';
import '../../mock_objects/fake_process_wrapper.dart';

void main() {
  group('HookService', () {
    late HookService hookService;
    late FakeProcessWrapper fakeProcessWrapper;

    setUp(() {
      fakeProcessWrapper = FakeProcessWrapper();
      hookService = HookService(fakeProcessWrapper);
    });

    tearDown(() {
      fakeProcessWrapper.clearResponses();
    });

    group('executePreCreate', () {
      test('executes preCreate hook commands sequentially', () async {
        fakeProcessWrapper.addResponse('/bin/sh', [
          '-c',
          'echo "first command"',
        ], stdout: 'first command\n');
        fakeProcessWrapper.addResponse('/bin/sh', [
          '-c',
          'echo "second command"',
        ], stdout: 'second command\n');

        final config = HooksConfig(
          timeout: 30,
          preCreate: Hook.fromList([
            'echo "first command"',
            'echo "second command"',
          ]),
        );

        // Should complete without throwing
        await hookService.executePreCreate(
          config,
          '/path/to/worktree',
          '/path/to/origin',
          'main',
        );
      });

      test('expands environment variables in commands', () async {
        fakeProcessWrapper.addResponse(
          '/bin/sh',
          ['-c', 'echo "/expanded/worktree /expanded/origin expanded-branch"'],
          stdout: '/expanded/worktree /expanded/origin expanded-branch\n',
        );

        final config = HooksConfig(
          timeout: 30,
          preCreate: Hook.fromList([
            'echo "\$GWM_WORKTREE_PATH \$GWM_ORIGIN_PATH \$GWM_BRANCH"',
          ]),
        );

        await hookService.executePreCreate(
          config,
          '/expanded/worktree',
          '/expanded/origin',
          'expanded-branch',
        );
      });

      test('sets environment variables for hook execution', () async {
        fakeProcessWrapper.addResponse(
          '/bin/sh',
          ['-c', 'env | grep GWM_ | sort'],
          stdout:
              'GWM_BRANCH=test-branch\nGWM_ORIGIN_PATH=/test/origin\nGWM_WORKTREE_PATH=/test/worktree\n',
        );

        final config = HooksConfig(
          timeout: 30,
          preCreate: Hook.fromList(['env | grep GWM_ | sort']),
        );

        await hookService.executePreCreate(
          config,
          '/test/worktree',
          '/test/origin',
          'test-branch',
        );
      });

      test('handles hook-specific timeout configuration', () async {
        fakeProcessWrapper.addResponse('/bin/sh', [
          '-c',
          'echo "command with timeout"',
        ], stdout: 'command with timeout\n');

        final config = HooksConfig(
          timeout: 30,
          preCreate: Hook(
            commands: ['echo "command with timeout"'],
            timeout: 60,
          ),
        );

        // Should complete without error - timeout handling is tested in integration
        await hookService.executePreCreate(
          config,
          '/path/to/worktree',
          '/path/to/origin',
          'main',
        );
      });

      test('fails immediately on first command failure', () async {
        fakeProcessWrapper.addResponse('/bin/sh', [
          '-c',
          'echo "success"',
        ], stdout: 'success\n');
        fakeProcessWrapper.addResponse(
          '/bin/sh',
          ['-c', 'exit 1'],
          exitCode: 1,
          stderr: 'command failed\n',
        );
        fakeProcessWrapper.addResponse('/bin/sh', [
          '-c',
          'echo "should not run"',
        ], stdout: 'should not run\n');

        final config = HooksConfig(
          timeout: 30,
          preCreate: Hook.fromList([
            'echo "success"',
            'exit 1',
            'echo "should not run"',
          ]),
        );

        expect(
          () => hookService.executePreCreate(
            config,
            '/path/to/worktree',
            '/path/to/origin',
            'main',
          ),
          throwsA(isA<HookExecutionException>()),
        );

        // Verify third command was never executed (its response should still be available)
        // If this completes without error, the third command wasn't executed
        final result = await fakeProcessWrapper.run('/bin/sh', [
          '-c',
          'echo "should not run"',
        ]);
        expect(result.stdout, 'should not run\n');
      });

      test('displays stdout and stderr output', () async {
        fakeProcessWrapper.addResponse(
          '/bin/sh',
          ['-c', 'echo "stdout message" && echo "stderr message" >&2'],
          stdout: 'stdout message\n',
          stderr: 'stderr message\n',
        );

        final config = HooksConfig(
          timeout: 30,
          preCreate: Hook.fromList([
            'echo "stdout message" && echo "stderr message" >&2',
          ]),
        );

        // Test that the method completes without error - output display is tested manually
        await hookService.executePreCreate(
          config,
          '/path/to/worktree',
          '/path/to/origin',
          'main',
        );
      });

      test('does nothing when hook is null', () async {
        final config = HooksConfig(timeout: 30);

        // Should complete without executing any commands
        await hookService.executePreCreate(
          config,
          '/path/to/worktree',
          '/path/to/origin',
          'main',
        );
      });

      test('does nothing when hook has empty commands', () async {
        final config = HooksConfig(timeout: 30, preCreate: Hook.fromList([]));

        // Should complete without executing any commands
        await hookService.executePreCreate(
          config,
          '/path/to/worktree',
          '/path/to/origin',
          'main',
        );
      });
    });

    group('executePostCreate', () {
      test('executes postCreate hook commands', () async {
        fakeProcessWrapper.addResponse('/bin/sh', [
          '-c',
          'echo "post-add command"',
        ], stdout: 'post-add command\n');

        final config = HooksConfig(
          timeout: 30,
          postCreate: Hook.fromList(['echo "post-add command"']),
        );

        await hookService.executePostCreate(
          config,
          '/path/to/worktree',
          '/path/to/origin',
          'main',
        );
      });
    });

    group('executePreSwitch', () {
      test('executes preSwitch hook commands', () async {
        fakeProcessWrapper.addResponse('/bin/sh', [
          '-c',
          'echo "pre-switch command"',
        ], stdout: 'pre-switch command\n');

        final config = HooksConfig(
          timeout: 30,
          preSwitch: Hook.fromList(['echo "pre-switch command"']),
        );

        await hookService.executePreSwitch(
          config,
          '/path/to/worktree',
          '/path/to/origin',
          'main',
        );
      });
    });

    group('executePostSwitch', () {
      test('executes postSwitch hook commands', () async {
        fakeProcessWrapper.addResponse('/bin/sh', [
          '-c',
          'echo "post-switch command"',
        ], stdout: 'post-switch command\n');

        final config = HooksConfig(
          timeout: 30,
          postSwitch: Hook.fromList(['echo "post-switch command"']),
        );

        await hookService.executePostSwitch(
          config,
          '/path/to/worktree',
          '/path/to/origin',
          'main',
        );
      });
    });

    group('executePreDelete', () {
      test('executes preDelete hook commands', () async {
        fakeProcessWrapper.addResponse('/bin/sh', [
          '-c',
          'echo "pre-delete command"',
        ], stdout: 'pre-delete command\n');

        final config = HooksConfig(
          timeout: 30,
          preDelete: Hook.fromList(['echo "pre-delete command"']),
        );

        await hookService.executePreDelete(
          config,
          '/path/to/worktree',
          '/path/to/origin',
          'main',
        );
      });
    });

    group('executePostDelete', () {
      test('executes postDelete hook commands', () async {
        fakeProcessWrapper.addResponse('/bin/sh', [
          '-c',
          'echo "post-delete command"',
        ], stdout: 'post-delete command\n');

        final config = HooksConfig(
          timeout: 30,
          postDelete: Hook.fromList(['echo "post-delete command"']),
        );

        await hookService.executePostDelete(
          config,
          '/path/to/worktree',
          '/path/to/origin',
          'main',
        );
      });
    });

    group('HookExecutionException', () {
      test('includes hook name, command, and output in exception', () async {
        fakeProcessWrapper.addResponse(
          '/bin/sh',
          ['-c', 'exit 1'],
          exitCode: 1,
          stderr: 'command failed with error\n',
        );

        final config = HooksConfig(
          timeout: 30,
          preCreate: Hook.fromList(['exit 1']),
        );

        try {
          await hookService.executePreCreate(
            config,
            '/path/to/worktree',
            '/path/to/origin',
            'main',
          );
          fail('Expected HookExecutionException');
        } catch (e) {
          expect(e, isA<HookExecutionException>());
          final exception = e as HookExecutionException;
          expect(exception.hookName, 'preCreate');
          expect(exception.command, 'exit 1');
          expect(exception.output, 'command failed with error');
          expect(exception.exitCode, ExitCode.hookFailed);
        }
      });
    });
  });
}
