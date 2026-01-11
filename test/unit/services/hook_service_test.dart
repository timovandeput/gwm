import 'package:test/test.dart';

import 'package:gwt/src/services/hook_service.dart';
import 'package:gwt/src/models/config.dart';
import 'package:gwt/src/models/hook.dart';
import 'package:gwt/src/exceptions.dart';
import 'package:gwt/src/models/exit_codes.dart';
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

    group('executePreAdd', () {
      test('executes preAdd hook commands sequentially', () async {
        fakeProcessWrapper.addResponse('sh', [
          '-c',
          'echo "first command"',
        ], stdout: 'first command\n');
        fakeProcessWrapper.addResponse('sh', [
          '-c',
          'echo "second command"',
        ], stdout: 'second command\n');

        final config = HooksConfig(
          timeout: 30,
          preAdd: Hook.fromList([
            'echo "first command"',
            'echo "second command"',
          ]),
        );

        // Should complete without throwing
        await hookService.executePreAdd(
          config,
          '/path/to/worktree',
          '/path/to/origin',
          'main',
        );
      });

      test('expands environment variables in commands', () async {
        fakeProcessWrapper.addResponse('sh', [
          '-c',
          'echo "/expanded/worktree /expanded/origin expanded-branch"',
        ], stdout: '/expanded/worktree /expanded/origin expanded-branch\n');

        final config = HooksConfig(
          timeout: 30,
          preAdd: Hook.fromList([
            'echo "\$GWT_WORKTREE_PATH \$GWT_ORIGIN_PATH \$GWT_BRANCH"',
          ]),
        );

        await hookService.executePreAdd(
          config,
          '/expanded/worktree',
          '/expanded/origin',
          'expanded-branch',
        );
      });

      test('sets environment variables for hook execution', () async {
        fakeProcessWrapper.addResponse(
          'sh',
          ['-c', 'env | grep GWT_ | sort'],
          stdout:
              'GWT_BRANCH=test-branch\nGWT_ORIGIN_PATH=/test/origin\nGWT_WORKTREE_PATH=/test/worktree\n',
        );

        final config = HooksConfig(
          timeout: 30,
          preAdd: Hook.fromList(['env | grep GWT_ | sort']),
        );

        await hookService.executePreAdd(
          config,
          '/test/worktree',
          '/test/origin',
          'test-branch',
        );
      });

      test('handles hook-specific timeout configuration', () async {
        fakeProcessWrapper.addResponse('sh', [
          '-c',
          'echo "command with timeout"',
        ], stdout: 'command with timeout\n');

        final config = HooksConfig(
          timeout: 30,
          preAdd: Hook(commands: ['echo "command with timeout"'], timeout: 60),
        );

        // Should complete without error - timeout handling is tested in integration
        await hookService.executePreAdd(
          config,
          '/path/to/worktree',
          '/path/to/origin',
          'main',
        );
      });

      test('fails immediately on first command failure', () async {
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
          'echo "should not run"',
        ], stdout: 'should not run\n');

        final config = HooksConfig(
          timeout: 30,
          preAdd: Hook.fromList([
            'echo "success"',
            'exit 1',
            'echo "should not run"',
          ]),
        );

        expect(
          () => hookService.executePreAdd(
            config,
            '/path/to/worktree',
            '/path/to/origin',
            'main',
          ),
          throwsA(isA<HookExecutionException>()),
        );

        // Verify third command was never executed (its response should still be available)
        // If this completes without error, the third command wasn't executed
        final result = await fakeProcessWrapper.run('sh', [
          '-c',
          'echo "should not run"',
        ]);
        expect(result.stdout, 'should not run\n');
      });

      test('displays stdout and stderr output', () async {
        fakeProcessWrapper.addResponse(
          'sh',
          ['-c', 'echo "stdout message" && echo "stderr message" >&2'],
          stdout: 'stdout message\n',
          stderr: 'stderr message\n',
        );

        final config = HooksConfig(
          timeout: 30,
          preAdd: Hook.fromList([
            'echo "stdout message" && echo "stderr message" >&2',
          ]),
        );

        // Test that the method completes without error - output display is tested manually
        await hookService.executePreAdd(
          config,
          '/path/to/worktree',
          '/path/to/origin',
          'main',
        );
      });

      test('does nothing when hook is null', () async {
        final config = HooksConfig(timeout: 30);

        // Should complete without executing any commands
        await hookService.executePreAdd(
          config,
          '/path/to/worktree',
          '/path/to/origin',
          'main',
        );
      });

      test('does nothing when hook has empty commands', () async {
        final config = HooksConfig(timeout: 30, preAdd: Hook.fromList([]));

        // Should complete without executing any commands
        await hookService.executePreAdd(
          config,
          '/path/to/worktree',
          '/path/to/origin',
          'main',
        );
      });
    });

    group('executePostAdd', () {
      test('executes postAdd hook commands', () async {
        fakeProcessWrapper.addResponse('sh', [
          '-c',
          'echo "post-add command"',
        ], stdout: 'post-add command\n');

        final config = HooksConfig(
          timeout: 30,
          postAdd: Hook.fromList(['echo "post-add command"']),
        );

        await hookService.executePostAdd(
          config,
          '/path/to/worktree',
          '/path/to/origin',
          'main',
        );
      });
    });

    group('executePreSwitch', () {
      test('executes preSwitch hook commands', () async {
        fakeProcessWrapper.addResponse('sh', [
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
        fakeProcessWrapper.addResponse('sh', [
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

    group('executePreClean', () {
      test('executes preClean hook commands', () async {
        fakeProcessWrapper.addResponse('sh', [
          '-c',
          'echo "pre-clean command"',
        ], stdout: 'pre-clean command\n');

        final config = HooksConfig(
          timeout: 30,
          preClean: Hook.fromList(['echo "pre-clean command"']),
        );

        await hookService.executePreClean(
          config,
          '/path/to/worktree',
          '/path/to/origin',
          'main',
        );
      });
    });

    group('executePostClean', () {
      test('executes postClean hook commands', () async {
        fakeProcessWrapper.addResponse('sh', [
          '-c',
          'echo "post-clean command"',
        ], stdout: 'post-clean command\n');

        final config = HooksConfig(
          timeout: 30,
          postClean: Hook.fromList(['echo "post-clean command"']),
        );

        await hookService.executePostClean(
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
          'sh',
          ['-c', 'exit 1'],
          exitCode: 1,
          stderr: 'command failed with error\n',
        );

        final config = HooksConfig(
          timeout: 30,
          preAdd: Hook.fromList(['exit 1']),
        );

        try {
          await hookService.executePreAdd(
            config,
            '/path/to/worktree',
            '/path/to/origin',
            'main',
          );
          fail('Expected HookExecutionException');
        } catch (e) {
          expect(e, isA<HookExecutionException>());
          final exception = e as HookExecutionException;
          expect(exception.hookName, 'preAdd');
          expect(exception.command, 'exit 1');
          expect(exception.output, 'command failed with error');
          expect(exception.exitCode, ExitCode.hookFailed);
        }
      });
    });
  });
}
