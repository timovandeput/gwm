import 'package:args/args.dart';
import 'package:test/test.dart';

import 'package:gwm/src/cli_utils.dart';

void main() {
  group('printSafe', () {
    test('prints directly when hasTerminal is true', () {
      final output = <String>[];
      printSafe('Test message', hasTerminal: true, printFunction: output.add);
      expect(output, ['Test message']);
    });

    test('prints echo command when hasTerminal is false', () {
      final output = <String>[];
      printSafe('Test message', hasTerminal: false, printFunction: output.add);
      expect(output, ["echo 'Test message'"]);
    });

    test('escapes single quotes in message', () {
      final output = <String>[];
      printSafe("Don't panic", hasTerminal: false, printFunction: output.add);
      expect(output, ["echo 'Don'\"'\"'t panic'"]);
    });

    test('handles empty message', () {
      final output = <String>[];
      printSafe('', hasTerminal: false, printFunction: output.add);
      expect(output, ["echo ''"]);
    });
  });

  group('printUsage', () {
    late ArgParser argParser;

    setUp(() {
      argParser = ArgParser()
        ..addFlag('help', abbr: 'h')
        ..addFlag('version');
    });

    test('prints directly when hasTerminal is true', () {
      final output = <String>[];
      printUsage(argParser, hasTerminal: true, printFunction: output.add);
      expect(output.length, greaterThan(5));
      expect(
        output[0],
        'GWM (Git Worktree Manager) - Streamlined Git worktree management',
      );
      expect(output.contains('Available commands:'), isTrue);
      expect(output.contains('Global options:'), isTrue);
      // Should not contain echo commands
      expect(output.any((line) => line.startsWith('echo ')), isFalse);
    });

    test('prints echo commands when hasTerminal is false', () {
      final output = <String>[];
      printUsage(argParser, hasTerminal: false, printFunction: output.add);
      expect(output.length, greaterThan(5));
      expect(
        output[0],
        "echo 'GWM (Git Worktree Manager) - Streamlined Git worktree management'",
      );
      expect(output.any((line) => line.contains('Available commands')), isTrue);
      expect(output.any((line) => line.contains('Global options')), isTrue);
      // All lines should be echo commands
      expect(output.every((line) => line.startsWith('echo ')), isTrue);
    });

    test('escapes single quotes in usage text', () {
      final argParserWithQuotes = ArgParser()
        ..addFlag('help', help: "Don't use this");
      final output = <String>[];
      printUsage(
        argParserWithQuotes,
        hasTerminal: false,
        printFunction: output.add,
      );
      expect(output.any((line) => line.contains("'\"'\"'")), isTrue);
    });
  });
}
