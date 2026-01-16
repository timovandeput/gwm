import 'package:args/args.dart';
import 'package:test/test.dart';

import 'package:gwm/src/commands/base.dart';
import 'package:gwm/src/models/exit_codes.dart';

class TestCommand extends BaseCommand {
  TestCommand({super.skipEvalCheck});

  @override
  ArgParser get parser => ArgParser()..addFlag('test');

  @override
  Future<ExitCode> execute(ArgResults results) async {
    return ExitCode.success;
  }
}

void main() {
  group('BaseCommand', () {
    test('validate returns success by default', () {
      final command = TestCommand();
      final results = command.parser.parse([]);
      expect(command.validate(results), ExitCode.success);
    });

    test('handleError prints error and returns generalError', () {
      final command = TestCommand();
      final exitCode = command.handleError('test error');
      expect(exitCode, ExitCode.generalError);
    });

    test('can be instantiated with skipEvalCheck', () {
      final command = TestCommand(skipEvalCheck: true);
      expect(command.skipEvalCheck, isTrue);
    });
  });
}
