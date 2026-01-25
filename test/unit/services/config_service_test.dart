import 'dart:io';

import 'package:test/test.dart';

import 'package:gwm/src/services/config_service.dart';
import 'package:gwm/src/exceptions.dart';

void main() {
  group('ConfigService', () {
    late ConfigService configService;
    late Directory tempDir;
    late Directory fakeHomeDir;

    setUp(() {
      configService = ConfigService();
      tempDir = Directory.systemTemp.createTempSync('gwm_config_test_');
      fakeHomeDir = Directory.systemTemp.createTempSync('gwm_fake_home_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
      fakeHomeDir.deleteSync(recursive: true);
      // Clean up any global config files created during tests
      final globalDir = Directory(
        '${Platform.environment['HOME']}/.config/gwm',
      );
      if (globalDir.existsSync()) {
        globalDir.deleteSync(recursive: true);
      }
    });

    group('loadConfig', () {
      test('returns default config when no files exist', () async {
        final config = await configService.loadConfig();

        expect(config.version, '1.0');
        expect(config.copy.files, isEmpty);
        expect(config.copy.directories, isEmpty);
        expect(config.hooks.timeout, 30);
        expect(config.hooks.preCreate, isNull);
        expect(config.shellIntegration.enableEvalOutput, false);
      });

      test('loads global JSON config', () async {
        final globalDir = Directory(
          '${Platform.environment['HOME']}/.config/gwm',
        );
        globalDir.createSync(recursive: true);
        addTearDown(() => globalDir.deleteSync(recursive: true));

        final configFile = File('${globalDir.path}/config.json');
        configFile.writeAsStringSync('''
{
  "version": "1.0",
  "copy": {
    "files": ["*.md"],
    "directories": ["docs"]
  },
  "hooks": {
    "timeout": 60
  },
  "shellIntegration": {
    "enableEvalOutput": true
  }
}
''');

        final config = await configService.loadConfig();

        expect(config.version, '1.0');
        expect(config.copy.files, ['*.md']);
        expect(config.copy.directories, ['docs']);
        expect(config.hooks.timeout, 60);
        expect(config.shellIntegration.enableEvalOutput, true);
      });

      test('loads global YAML config', () async {
        final globalDir = Directory(
          '${Platform.environment['HOME']}/.config/gwm',
        );
        globalDir.createSync(recursive: true);
        addTearDown(() => globalDir.deleteSync(recursive: true));

        final configFile = File('${globalDir.path}/config.yaml');
        configFile.writeAsStringSync('''
version: "1.0"
copy:
  files:
    - "*.md"
  directories:
    - "docs"
hooks:
  timeout: 60
shellIntegration:
  enableEvalOutput: true
''');

        final config = await configService.loadConfig();

        expect(config.version, '1.0');
        expect(config.copy.files, ['*.md']);
        expect(config.copy.directories, ['docs']);
        expect(config.hooks.timeout, 60);
        expect(config.shellIntegration.enableEvalOutput, true);
      });

      test('loads repo config', () async {
        final repoConfig = File('${tempDir.path}/.gwm.json');
        repoConfig.writeAsStringSync('''
{
  "version": "1.0",
  "hooks": {
    "postCreate": ["echo 'repo hook'"]
  }
}
''');

        final config = await configService.loadConfig(repoRoot: tempDir.path);

        expect(config.hooks.postCreate?.commands, ['echo \'repo hook\'']);
      });

      test('loads local config with higher priority', () async {
        final repoConfig = File('${tempDir.path}/.gwm.json');
        repoConfig.writeAsStringSync('''
{
  "hooks": {
    "postCreate": ["echo 'repo hook'"]
  }
}
''');

        final localConfig = File('${tempDir.path}/.gwm.local.json');
        localConfig.writeAsStringSync('''
{
  "hooks": {
    "postCreate": ["echo 'local hook'"]
  }
}
''');

        final config = await configService.loadConfig(repoRoot: tempDir.path);

        expect(config.hooks.postCreate?.commands, ['echo \'local hook\'']);
      });

      test(
        'merges configs with correct priority: local > repo > global',
        () async {
          // Global config
          final globalDir = Directory(
            '${Platform.environment['HOME']}/.config/gwm',
          );
          globalDir.createSync(recursive: true);
          addTearDown(() => globalDir.deleteSync(recursive: true));

          final globalConfig = File('${globalDir.path}/config.json');
          globalConfig.writeAsStringSync('''
{
  "copy": {
    "files": ["global.md"]
  },
  "hooks": {
    "timeout": 30,
    "postCreate": ["echo 'global'"]
  }
}
''');

          // Repo config
          final repoConfig = File('${tempDir.path}/.gwm.json');
          repoConfig.writeAsStringSync('''
{
  "copy": {
    "files": ["repo.md"]
  },
  "hooks": {
    "postCreate": ["echo 'repo'"]
  }
}
''');

          // Local config
          final localConfig = File('${tempDir.path}/.gwm.local.json');
          localConfig.writeAsStringSync('''
{
  "copy": {
    "files": ["local.md"]
  },
  "hooks": {
    "postCreate": ["echo 'local'"]
  }
}
''');

          final config = await configService.loadConfig(repoRoot: tempDir.path);

          expect(config.copy.files, ['local.md']); // Local overrides
          expect(config.hooks.timeout, 30); // From global
          expect(config.hooks.postCreate?.commands, [
            'echo \'local\'',
          ]); // Local overrides
        },
      );
    });

    group('hook merging', () {
      test('prepend commands to hook', () async {
        final repoConfig = File('${tempDir.path}/.gwm.json');
        repoConfig.writeAsStringSync('''
{
  "hooks": {
    "postCreate": ["echo 'repo'"]
  }
}
''');

        final localConfig = File('${tempDir.path}/.gwm.local.json');
        localConfig.writeAsStringSync('''
{
  "hooks": {
    "postCreate_prepend": ["echo 'local prepend'"]
  }
}
''');

        final config = await configService.loadConfig(repoRoot: tempDir.path);

        expect(config.hooks.postCreate?.commands, [
          'echo \'local prepend\'',
          'echo \'repo\'',
        ]);
      });

      test('append commands to hook', () async {
        final repoConfig = File('${tempDir.path}/.gwm.json');
        repoConfig.writeAsStringSync('''
{
  "hooks": {
    "postCreate": ["echo 'repo'"]
  }
}
''');

        final localConfig = File('${tempDir.path}/.gwm.local.json');
        localConfig.writeAsStringSync('''
{
  "hooks": {
    "postCreate_append": ["echo 'local append'"]
  }
}
''');

        final config = await configService.loadConfig(repoRoot: tempDir.path);

        expect(config.hooks.postCreate?.commands, [
          'echo \'repo\'',
          'echo \'local append\'',
        ]);
      });

      test('prepend and append together', () async {
        final repoConfig = File('${tempDir.path}/.gwm.json');
        repoConfig.writeAsStringSync('''
{
  "hooks": {
    "postCreate": ["echo 'repo'"]
  }
}
''');

        final localConfig = File('${tempDir.path}/.gwm.local.json');
        localConfig.writeAsStringSync('''
{
  "hooks": {
    "postCreate_prepend": ["echo 'prepend'"],
    "postCreate_append": ["echo 'append'"]
  }
}
''');

        final config = await configService.loadConfig(repoRoot: tempDir.path);

        expect(config.hooks.postCreate?.commands, [
          'echo \'prepend\'',
          'echo \'repo\'',
          'echo \'append\'',
        ]);
      });

      test('prepend/append work with object format hooks', () async {
        final repoConfig = File('${tempDir.path}/.gwm.json');
        repoConfig.writeAsStringSync('''
{
  "hooks": {
    "postCreate": {
      "commands": ["echo 'repo'"],
      "timeout": 45
    }
  }
}
''');

        final localConfig = File('${tempDir.path}/.gwm.local.json');
        localConfig.writeAsStringSync('''
{
  "hooks": {
    "postCreate_prepend": ["echo 'prepend'"],
    "postCreate_append": ["echo 'append'"]
  }
}
''');

        final config = await configService.loadConfig(repoRoot: tempDir.path);

        expect(config.hooks.postCreate?.commands, [
          'echo \'prepend\'',
          'echo \'repo\'',
          'echo \'append\'',
        ]);
        expect(config.hooks.postCreate?.timeout, 45);
      });
    });

    group('hook formats', () {
      test('supports array format hooks', () async {
        final configFile = File('${tempDir.path}/.gwm.json');
        configFile.writeAsStringSync('''
{
  "hooks": {
    "postCreate": ["echo 'hello'", "echo 'world'"]
  }
}
''');

        final config = await configService.loadConfig(repoRoot: tempDir.path);

        expect(config.hooks.postCreate?.commands, [
          'echo \'hello\'',
          'echo \'world\'',
        ]);
        expect(config.hooks.postCreate?.timeout, isNull);
      });

      test('supports object format hooks', () async {
        final configFile = File('${tempDir.path}/.gwm.json');
        configFile.writeAsStringSync('''
{
  "hooks": {
    "postCreate": {
      "commands": ["echo 'hello'"],
      "timeout": 120
    }
  }
}
''');

        final config = await configService.loadConfig(repoRoot: tempDir.path);

        expect(config.hooks.postCreate?.commands, ['echo \'hello\'']);
        expect(config.hooks.postCreate?.timeout, 120);
      });

      test('supports string format hooks', () async {
        final configFile = File('${tempDir.path}/.gwm.json');
        configFile.writeAsStringSync('''
{
  "hooks": {
    "postCreate": "echo 'single command'"
  }
}
''');

        final config = await configService.loadConfig(repoRoot: tempDir.path);

        expect(config.hooks.postCreate?.commands, ['echo \'single command\'']);
        expect(config.hooks.postCreate?.timeout, isNull);
      });

      test('supports string format hooks in YAML', () async {
        final configFile = File('${tempDir.path}/.gwm.yaml');
        configFile.writeAsStringSync('''
version: "1.0"
hooks:
  postCreate: "echo 'yaml single command'"
''');

        final config = await configService.loadConfig(repoRoot: tempDir.path);

        expect(config.hooks.postCreate?.commands, [
          'echo \'yaml single command\'',
        ]);
        expect(config.hooks.postCreate?.timeout, isNull);
      });
    });

    group('error handling', () {
      test('throws ConfigException for invalid JSON', () async {
        final configFile = File('${tempDir.path}/.gwm.json');
        configFile.writeAsStringSync('{"invalid": json}');

        expect(
          () => configService.loadConfig(repoRoot: tempDir.path),
          throwsA(isA<ConfigException>()),
        );
      });

      test('throws ConfigException for invalid YAML', () async {
        final configFile = File('${tempDir.path}/.gwm.yaml');
        configFile.writeAsStringSync('invalid: yaml: content: [');

        expect(
          () => configService.loadConfig(repoRoot: tempDir.path),
          throwsA(isA<ConfigException>()),
        );
      });
    });
  });
}
