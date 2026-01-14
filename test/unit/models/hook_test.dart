import 'package:test/test.dart';
import 'package:gwm/src/models/hook.dart';

void main() {
  group('Hook', () {
    test('fromList creates hook with commands', () {
      final hook = Hook.fromList(['npm install', 'npm run build']);

      expect(hook.commands, equals(['npm install', 'npm run build']));
      expect(hook.timeout, isNull);
    });

    test('fromMap creates hook with commands and timeout', () {
      final map = {
        'commands': ['npm install'],
        'timeout': 120,
      };

      final hook = Hook.fromMap(map);

      expect(hook.commands, equals(['npm install']));
      expect(hook.timeout, equals(120));
    });

    test('fromMap handles missing timeout', () {
      final map = {
        'commands': ['echo hello'],
      };

      final hook = Hook.fromMap(map);

      expect(hook.commands, equals(['echo hello']));
      expect(hook.timeout, isNull);
    });

    test('copyWith updates specified fields', () {
      final original = Hook(commands: ['npm install'], timeout: 30);

      final updated = original.copyWith(timeout: 60);

      expect(updated.commands, equals(['npm install']));
      expect(updated.timeout, equals(60));
    });

    test('equality works correctly', () {
      final hook1 = Hook(commands: ['npm install'], timeout: 30);
      final hook2 = Hook(commands: ['npm install'], timeout: 30);
      final hook3 = Hook(commands: ['npm install'], timeout: 60);

      expect(hook1, equals(hook2));
      expect(hook1, isNot(equals(hook3)));
    });

    test('hashCode is consistent for equal objects', () {
      final hook1 = Hook(commands: ['npm install'], timeout: 30);
      final hook2 = Hook(commands: ['npm install'], timeout: 30);

      expect(hook1.hashCode, equals(hook2.hashCode));
    });

    test('toString provides useful representation', () {
      final hook = Hook(commands: ['npm install'], timeout: 30);

      final result = hook.toString();
      expect(result, contains('Hook'));
      expect(result, contains('npm install'));
      expect(result, contains('30'));
    });
  });
}
