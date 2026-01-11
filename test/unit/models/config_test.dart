import 'package:test/test.dart';
import 'package:gwt/src/models/config.dart';
import 'package:gwt/src/models/hook.dart';

void main() {
  group('Config', () {
    final copyConfig = CopyConfig(
      files: ['.env', '*.env.*'],
      directories: ['node_modules'],
    );

    final hooksConfig = HooksConfig(
      timeout: 30,
      postAdd: Hook.fromList(['npm install']),
    );

    final shellConfig = ShellIntegrationConfig(enableEvalOutput: true);

    final config = Config(
      version: '1.0',
      copy: copyConfig,
      hooks: hooksConfig,
      shellIntegration: shellConfig,
    );

    test('creates config with correct properties', () {
      expect(config.version, equals('1.0'));
      expect(config.copy, equals(copyConfig));
      expect(config.hooks, equals(hooksConfig));
      expect(config.shellIntegration, equals(shellConfig));
    });

    test('copyWith updates specified fields', () {
      final updated = config.copyWith(version: '2.0');

      expect(updated.version, equals('2.0'));
      expect(updated.copy, equals(config.copy));
      expect(updated.hooks, equals(config.hooks));
      expect(updated.shellIntegration, equals(config.shellIntegration));
    });

    test('equality works correctly', () {
      final sameConfig = Config(
        version: '1.0',
        copy: copyConfig,
        hooks: hooksConfig,
        shellIntegration: shellConfig,
      );

      expect(config, equals(sameConfig));
    });
  });

  group('CopyConfig', () {
    final config = CopyConfig(
      files: ['.env', '*.env.*'],
      directories: ['node_modules'],
    );

    test('creates copy config with correct properties', () {
      expect(config.files, equals(['.env', '*.env.*']));
      expect(config.directories, equals(['node_modules']));
    });

    test('copyWith updates specified fields', () {
      final updated = config.copyWith(files: ['.env.local']);

      expect(updated.files, equals(['.env.local']));
      expect(updated.directories, equals(config.directories));
    });

    test('equality works correctly', () {
      final sameConfig = CopyConfig(
        files: ['.env', '*.env.*'],
        directories: ['node_modules'],
      );

      expect(config, equals(sameConfig));
    });
  });

  group('HooksConfig', () {
    final config = HooksConfig(
      timeout: 30,
      preAdd: Hook.fromList(['echo starting']),
      postAdd: Hook.fromList(['npm install']),
    );

    test('creates hooks config with correct properties', () {
      expect(config.timeout, equals(30));
      expect(config.preAdd, isNotNull);
      expect(config.postAdd, isNotNull);
      expect(config.preSwitch, isNull);
    });

    test('copyWith updates specified fields', () {
      final updated = config.copyWith(timeout: 60);

      expect(updated.timeout, equals(60));
      expect(updated.preAdd, equals(config.preAdd));
    });

    test('equality works correctly', () {
      final sameConfig = HooksConfig(
        timeout: 30,
        preAdd: Hook.fromList(['echo starting']),
        postAdd: Hook.fromList(['npm install']),
      );

      expect(config, equals(sameConfig));
    });
  });

  group('ShellIntegrationConfig', () {
    final config = ShellIntegrationConfig(enableEvalOutput: true);

    test('creates shell config with correct properties', () {
      expect(config.enableEvalOutput, isTrue);
    });

    test('copyWith updates specified fields', () {
      final updated = config.copyWith(enableEvalOutput: false);

      expect(updated.enableEvalOutput, isFalse);
    });

    test('equality works correctly', () {
      final sameConfig = ShellIntegrationConfig(enableEvalOutput: true);

      expect(config, equals(sameConfig));
    });
  });
}
