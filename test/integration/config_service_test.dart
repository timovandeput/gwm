import 'dart:convert';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'package:gwm/src/models/config.dart';
import 'package:gwm/src/models/hook.dart';
import 'package:gwm/src/exceptions.dart';

void main() {
  group('ConfigService Integration', () {
    group('JSON parsing', () {
      test('parses simple JSON config', () {
        final json = '''
{
  "version": "1.0",
  "copy": {
    "files": [".env"],
    "directories": ["config"]
  }
}
''';

        final data = jsonDecode(json) as Map<String, dynamic>;
        expect(data['version'], '1.0');
        expect(data['copy']['files'], ['.env']);
        expect(data['copy']['directories'], ['config']);
      });

      test('parses JSON config with hooks', () {
        final json = '''
{
  "hooks": {
    "timeout": 60,
    "preCreate": ["echo 'pre-create'"],
    "postCreate": ["echo 'post-create'"]
  }
}
''';

        final data = jsonDecode(json) as Map<String, dynamic>;
        expect(data['hooks']['timeout'], 60);
        expect(data['hooks']['preCreate'], ["echo 'pre-create'"]);
        expect(data['hooks']['postCreate'], ["echo 'post-create'"]);
      });

      test('parses JSON config with complex hooks', () {
        final json = '''
{
  "hooks": {
    "preCreate": {
      "commands": ["cmd1", "cmd2"],
      "timeout": 120
    }
  }
}
''';

        final data = jsonDecode(json) as Map<String, dynamic>;
        final preCreate = data['hooks']['preCreate'] as Map<String, dynamic>;
        expect(preCreate['commands'], ['cmd1', 'cmd2']);
        expect(preCreate['timeout'], 120);
      });
    });

    group('YAML parsing', () {
      test('parses simple YAML config', () {
        final yaml = '''
version: "2.0"
copy:
  files:
    - .env
    - .env.local
  directories:
    - node_modules
''';

        final data = loadYaml(yaml);
        expect(data['version'], '2.0');
        expect(data['copy']['files'], containsAll(['.env', '.env.local']));
        expect(data['copy']['directories'], contains('node_modules'));
      });

      test('parses YAML config with hooks', () {
        final yaml = '''
hooks:
  timeout: 45
  preSwitch:
    - echo "switching"
  postSwitch:
    - echo "switched"
''';

        final data = loadYaml(yaml);
        expect(data['hooks']['timeout'], 45);
        expect(data['hooks']['preSwitch'], contains('echo "switching"'));
        expect(data['hooks']['postSwitch'], contains('echo "switched"'));
      });
    });

    group('Hook parsing', () {
      test('parses hook from string', () {
        final hook = Hook.fromList(['echo "test"']);
        expect(hook.commands, ['echo "test"']);
        expect(hook.timeout, isNull);
      });

      test('parses hook from list', () {
        final hook = Hook.fromList(['cmd1', 'cmd2']);
        expect(hook.commands, ['cmd1', 'cmd2']);
      });

      test('parses hook from map with timeout', () {
        final hook = Hook.fromMap({
          'commands': ['cmd1'],
          'timeout': 60,
        });
        expect(hook.commands, ['cmd1']);
        expect(hook.timeout, 60);
      });
    });

    group('Config model', () {
      test('creates config with defaults', () {
        const config = Config(
          version: '1.0',
          copy: CopyConfig(files: [], directories: []),
          hooks: HooksConfig(timeout: 30),
          shellIntegration: ShellIntegrationConfig(enableEvalOutput: false),
        );

        expect(config.version, '1.0');
        expect(config.copy.files, isEmpty);
        expect(config.copy.directories, isEmpty);
        expect(config.hooks.timeout, 30);
        expect(config.shellIntegration.enableEvalOutput, isFalse);
      });

      test('creates config with hooks', () {
        final config = Config(
          version: '1.0',
          copy: const CopyConfig(files: [], directories: []),
          hooks: HooksConfig(
            timeout: 60,
            preCreate: Hook.fromList(['echo "pre"']),
            postCreate: Hook.fromList(['echo "post"']),
          ),
          shellIntegration: const ShellIntegrationConfig(
            enableEvalOutput: true,
          ),
        );

        expect(config.hooks.timeout, 60);
        expect(config.hooks.preCreate?.commands, ['echo "pre"']);
        expect(config.hooks.postCreate?.commands, ['echo "post"']);
        expect(config.shellIntegration.enableEvalOutput, isTrue);
      });

      test('creates config with copy settings', () {
        const config = Config(
          version: '1.0',
          copy: CopyConfig(
            files: ['.env', '.envrc'],
            directories: ['config', 'node_modules'],
          ),
          hooks: HooksConfig(timeout: 30),
          shellIntegration: ShellIntegrationConfig(enableEvalOutput: false),
        );

        expect(config.copy.files, ['.env', '.envrc']);
        expect(config.copy.directories, ['config', 'node_modules']);
      });
    });

    group('HooksConfig', () {
      test('creates with all hook types', () {
        final config = HooksConfig(
          timeout: 45,
          preCreate: Hook.fromList(['pre-create']),
          postCreate: Hook.fromList(['post-create']),
          preSwitch: Hook.fromList(['pre-switch']),
          postSwitch: Hook.fromList(['post-switch']),
          preDelete: Hook.fromList(['pre-delete']),
          postDelete: Hook.fromList(['post-delete']),
        );

        expect(config.timeout, 45);
        expect(config.preCreate?.commands, ['pre-create']);
        expect(config.postCreate?.commands, ['post-create']);
        expect(config.preSwitch?.commands, ['pre-switch']);
        expect(config.postSwitch?.commands, ['post-switch']);
        expect(config.preDelete?.commands, ['pre-delete']);
        expect(config.postDelete?.commands, ['post-delete']);
      });
    });

    group('ConfigException', () {
      test('creates exception with path and message', () {
        const exception = ConfigException(
          '/path/to/config.yaml',
          'Invalid YAML',
        );

        expect(exception.configPath, '/path/to/config.yaml');
        expect(exception.reason, 'Invalid YAML');
        expect(exception.toString(), contains('Configuration error'));
        expect(exception.toString(), contains('/path/to/config.yaml'));
      });
    });
  });
}
