import 'package:test/test.dart';
import 'package:gwm/src/utils/validation.dart';
import 'package:gwm/src/exceptions.dart';

void main() {
  const configPath = '/test/.gwm.json';

  group('validateConfigFile', () {
    test('accepts empty config', () {
      expect(() => validateConfigFile({}, configPath), returnsNormally);
    });

    group('version validation', () {
      test('accepts valid version string', () {
        expect(
          () => validateConfigFile({'version': '1.0'}, configPath),
          returnsNormally,
        );
      });

      test('rejects non-string version', () {
        expect(
          () => validateConfigFile({'version': 42}, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              'version must be a string',
            ),
          ),
        );
      });

      test('rejects invalid version format', () {
        expect(
          () => validateConfigFile({'version': 'abc'}, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              contains('major.minor'),
            ),
          ),
        );
      });

      test('accepts multi-digit version', () {
        expect(
          () => validateConfigFile({'version': '10.23'}, configPath),
          returnsNormally,
        );
      });
    });

    group('copy section validation', () {
      test('accepts valid copy config', () {
        expect(
          () => validateConfigFile({
            'copy': {
              'files': ['*.env', '.gitignore'],
              'directories': ['config'],
            },
          }, configPath),
          returnsNormally,
        );
      });

      test('rejects non-object copy', () {
        expect(
          () => validateConfigFile({'copy': 'invalid'}, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              'copy must be an object',
            ),
          ),
        );
      });

      test('rejects non-array files', () {
        expect(
          () => validateConfigFile({
            'copy': {'files': 'not-a-list'},
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              'copy.files must be an array',
            ),
          ),
        );
      });

      test('rejects non-string items in files', () {
        expect(
          () => validateConfigFile({
            'copy': {
              'files': [42],
            },
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              'copy.files must contain only strings',
            ),
          ),
        );
      });

      test('rejects non-array directories', () {
        expect(
          () => validateConfigFile({
            'copy': {'directories': 'not-a-list'},
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              'copy.directories must be an array',
            ),
          ),
        );
      });

      test('rejects non-string items in directories', () {
        expect(
          () => validateConfigFile({
            'copy': {
              'directories': [123],
            },
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              'copy.directories must contain only strings',
            ),
          ),
        );
      });

      test('rejects glob pattern with parent directory traversal', () {
        expect(
          () => validateConfigFile({
            'copy': {
              'files': ['../etc/passwd'],
            },
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              contains('potentially unsafe pattern'),
            ),
          ),
        );
      });

      test('rejects glob pattern with absolute path', () {
        expect(
          () => validateConfigFile({
            'copy': {
              'files': ['/etc/passwd'],
            },
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              contains('potentially unsafe pattern'),
            ),
          ),
        );
      });

      test('rejects overly long glob pattern', () {
        final longPattern = 'a' * 257;
        expect(
          () => validateConfigFile({
            'copy': {
              'files': [longPattern],
            },
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              contains('pattern is too long'),
            ),
          ),
        );
      });
    });

    group('hooks section validation', () {
      test('accepts valid hooks config', () {
        expect(
          () => validateConfigFile({
            'hooks': {
              'timeout': 30,
              'preCreate': ['npm install'],
              'postCreate': 'echo done',
            },
          }, configPath),
          returnsNormally,
        );
      });

      test('rejects non-object hooks', () {
        expect(
          () => validateConfigFile({'hooks': 'invalid'}, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              'hooks must be an object',
            ),
          ),
        );
      });

      test('rejects non-integer timeout', () {
        expect(
          () => validateConfigFile({
            'hooks': {'timeout': 'fast'},
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              'hooks.timeout must be an integer',
            ),
          ),
        );
      });

      test('rejects timeout below 1', () {
        expect(
          () => validateConfigFile({
            'hooks': {'timeout': 0},
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              contains('between 1 and 3600'),
            ),
          ),
        );
      });

      test('rejects timeout above 3600', () {
        expect(
          () => validateConfigFile({
            'hooks': {'timeout': 3601},
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              contains('between 1 and 3600'),
            ),
          ),
        );
      });

      test('accepts hook as string', () {
        expect(
          () => validateConfigFile({
            'hooks': {'preCreate': 'npm install'},
          }, configPath),
          returnsNormally,
        );
      });

      test('accepts hook as array of strings', () {
        expect(
          () => validateConfigFile({
            'hooks': {
              'preCreate': ['npm install', 'npm run build'],
            },
          }, configPath),
          returnsNormally,
        );
      });

      test('accepts hook as object with commands', () {
        expect(
          () => validateConfigFile({
            'hooks': {
              'preCreate': {
                'commands': ['npm install'],
                'timeout': 60,
              },
            },
          }, configPath),
          returnsNormally,
        );
      });

      test('rejects hook array with non-string items', () {
        expect(
          () => validateConfigFile({
            'hooks': {
              'preCreate': [42],
            },
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              contains('array must contain only strings'),
            ),
          ),
        );
      });

      test('rejects hook object without commands field', () {
        expect(
          () => validateConfigFile({
            'hooks': {
              'preCreate': {'timeout': 30},
            },
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              contains('must contain "commands" field'),
            ),
          ),
        );
      });

      test('rejects hook object with non-array commands', () {
        expect(
          () => validateConfigFile({
            'hooks': {
              'preCreate': {'commands': 'not-a-list'},
            },
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              contains('commands must be an array'),
            ),
          ),
        );
      });

      test('rejects hook object with non-string commands', () {
        expect(
          () => validateConfigFile({
            'hooks': {
              'preCreate': {
                'commands': [42],
              },
            },
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              contains('commands must contain only strings'),
            ),
          ),
        );
      });

      test('rejects hook object with invalid timeout', () {
        expect(
          () => validateConfigFile({
            'hooks': {
              'preCreate': {
                'commands': ['npm install'],
                'timeout': 'fast',
              },
            },
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              contains('timeout must be an integer'),
            ),
          ),
        );
      });

      test('rejects hook object with out-of-range timeout', () {
        expect(
          () => validateConfigFile({
            'hooks': {
              'preCreate': {
                'commands': ['npm install'],
                'timeout': 0,
              },
            },
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              contains('between 1 and 3600'),
            ),
          ),
        );
      });

      test('rejects hook with unsupported type', () {
        expect(
          () => validateConfigFile({
            'hooks': {'preCreate': 42},
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              contains('must be a string, array, or object'),
            ),
          ),
        );
      });

      test('validates all hook names', () {
        for (final hookName in [
          'preCreate',
          'postCreate',
          'preSwitch',
          'postSwitch',
          'preDelete',
          'postDelete',
        ]) {
          expect(
            () => validateConfigFile({
              'hooks': {hookName: 'echo test'},
            }, configPath),
            returnsNormally,
          );
        }
      });

      test('rejects non-array prepend variant', () {
        expect(
          () => validateConfigFile({
            'hooks': {'preCreate_prepend': 'not-a-list'},
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              contains('preCreate_prepend must be an array'),
            ),
          ),
        );
      });

      test('rejects non-string items in prepend variant', () {
        expect(
          () => validateConfigFile({
            'hooks': {
              'preCreate_prepend': [42],
            },
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              contains('preCreate_prepend must contain only strings'),
            ),
          ),
        );
      });

      test('rejects non-array append variant', () {
        expect(
          () => validateConfigFile({
            'hooks': {'postDelete_append': 'not-a-list'},
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              contains('postDelete_append must be an array'),
            ),
          ),
        );
      });

      test('rejects non-string items in append variant', () {
        expect(
          () => validateConfigFile({
            'hooks': {
              'postDelete_append': [123],
            },
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              contains('postDelete_append must contain only strings'),
            ),
          ),
        );
      });
    });

    group('shellIntegration section validation', () {
      test('accepts valid shellIntegration config', () {
        expect(
          () => validateConfigFile({
            'shellIntegration': {'enableEvalOutput': true},
          }, configPath),
          returnsNormally,
        );
      });

      test('rejects non-object shellIntegration', () {
        expect(
          () => validateConfigFile(
            {'shellIntegration': 'invalid'},
            configPath,
          ),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              'shellIntegration must be an object',
            ),
          ),
        );
      });

      test('rejects non-boolean enableEvalOutput', () {
        expect(
          () => validateConfigFile({
            'shellIntegration': {'enableEvalOutput': 'yes'},
          }, configPath),
          throwsA(
            isA<ConfigException>().having(
              (e) => e.reason,
              'reason',
              'shellIntegration.enableEvalOutput must be a boolean',
            ),
          ),
        );
      });
    });
  });
}
