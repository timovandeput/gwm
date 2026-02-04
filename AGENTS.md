# AGENTS.md - Development Guidelines for GWM CLI Tool

## Project Overview
GWM (Git Worktree Manager) is a Dart CLI tool for streamlined Git worktree management with automatic directory navigation, configurable hooks, and cross-platform support.

**Architecture**: Clean Architecture with Presentation, Application, Domain, and Infrastructure layers. See `docs/ARCHITECTURE.md`.

## Dependencies

**Runtime:** `args` (^2.7.0), `yaml` (^3.1.3), `glob` (^2.1.3), `path` (^1.9.1)  
**Dev:** `lints` (^6.0.0), `mocktail` (^1.0.4), `test` (^1.25.6)

Add: `dart pub add <package>`

## Build, Lint, and Test Commands

### Build
- **Run**: `dart run bin/gwm.dart`
- **Compile**: `dart compile exe bin/gwm.dart -o gwm`

### Lint
- **Analyze**: `dart analyze`
- **Format**: `dart format .`
- **Check format**: `dart format --set-exit-if-changed .`

### Test
- **All tests**: `dart test`
- **Single file**: `dart test test/unit/commands/add_test.dart`
- **By name**: `dart test -n "creates worktree with tracking"`
- **Coverage**: `dart test --coverage=coverage`
- **Verbose**: `dart test -v`

**Testing Rule**: Never invoke external tools in tests. Use mocks/fakes. Tests must be fast (< 5s) and deterministic.

## Development Workflow
1. Make changes
2. Format: `dart format .`
3. Lint: `dart analyze`
4. Test: `dart test`
5. Verify: `dart run bin/gwm.dart --help`

## Code Style Guidelines

### General
- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `package:lints/recommended.yaml`
- Prefer immutable data structures
- 2-space indentation, 80-character limit

### File Organization
```
bin/gwm.dart                 # CLI entry point
lib/src/
  commands/                  # Command handlers
  services/                  # Business logic
  models/                    # Domain models
  infrastructure/            # External integrations
  utils/                     # Utilities
test/
  unit/                      # Unit tests
  integration/               # E2E tests
  fixtures/                  # Test data
  mock_objects/              # Test doubles
```

### Naming Conventions
- **Variables/Functions**: `lowerCamelCase`
- **Classes/Types**: `UpperCamelCase`
- **Constants**: `SCREAMING_SNAKE_CASE`
- **Private members**: `_underscorePrefix`
- **Files**: `snake_case.dart`
- **Tests**: `*_test.dart`

### Imports
Order: 1) Dart SDK, 2) Third-party, 3) Relative. Blank lines between groups.

```dart
import 'dart:io';

import 'package:args/args.dart';

import '../models/config.dart';
```

### Types
- Explicit types for public APIs
- `var` only when type is obvious
- `final` over `var` for immutables

```dart
final Map<String, List<int>> data = {};
final Config config;
```

### Error Handling
Use specific exceptions, try-catch for expected errors, and meaningful messages.

```dart
try {
  await processData(input);
} on GitException catch (e) {
  printSafe('Git operation failed: ${e.message}');
  return ExitCode.gitFailed;
}
```

### Argument Parsing
Use `args` package with descriptive help text.

```dart
ArgParser buildParser() => ArgParser()
  ..addFlag('verbose', abbr: 'v', help: 'Show detailed output')
  ..addOption('config', abbr: 'c', help: 'Config file path');
```

### Documentation
Use `///` for public APIs with parameters and return types.

```dart
/// Creates a new worktree for the given branch.
///
/// [branch] The Git branch name
/// [createBranch] Whether to create branch if it doesn't exist
/// Returns [ExitCode] indicating success or failure
Future<ExitCode> addWorktree(String branch, {bool createBranch = false});
```

### Null Safety
```dart
String? userInput;
final name = userInput ?? 'Anonymous';
late final Config config;
```

### Testing Patterns
```dart
void main() {
  late MockGitClient mockGitClient;

  setUp(() {
    mockGitClient = MockGitClient();
    registerFallbackValue('');
  });

  group('WorktreeService', () {
    test('creates worktree successfully', () async {
      when(() => mockGitClient.branchExists('feature'))
          .thenAnswer((_) async => true);
      final result = await service.addWorktree('feature');
      expect(result, ExitCode.success);
    });
  });
}
```

### Security
- Validate all user input
- Safe file operations
- Sanitize output to prevent injection
- No execution of user-provided code

### Version Management
- Semantic versioning in `pubspec.yaml`
- Keep version constant synchronized
