# AGENTS.md - Development Guidelines for GWM CLI Tool

## Project Overview
GWM (Git Worktree Manager) is a Dart CLI tool that simplifies Git worktree management. It provides streamlined commands for creating, switching, and managing worktrees with automatic directory navigation, configurable hooks, and cross-platform support.

**Architecture**: Clean Architecture with Presentation, Application, Domain, and Infrastructure layers. See `docs/ARCHITECTURE.md` for details.

## Project Dependencies

**Runtime dependencies:**
- `args` (^2.7.0) - CLI argument parsing
- `yaml` (^3.1.3) - YAML configuration parsing
- `glob` (^2.1.3) - File pattern matching
- `path` (^1.9.1) - Path manipulation

**Dev dependencies:**
- `lints` (^6.0.0) - Dart linting rules
- `mocktail` (^1.0.4) - Mocking library for tests
- `test` (^1.25.6) - Testing framework

Add dependencies: `dart pub add <package>`

## Build, Lint, and Test Commands

### Build Commands
- **Run app**: `dart run bin/gwm.dart`
- **Build executable**: `dart compile exe bin/gwm.dart -o gwm`

### Lint Commands
- **Static analysis**: `dart analyze`
- **Format code**: `dart format .`
- **Check formatting**: `dart format --set-exit-if-changed .`

### Test Commands
- **All tests**: `dart test`
- **Single test file**: `dart test test/unit/commands/add_test.dart`
- **Single test by name**: `dart test -n "creates worktree with tracking"`
- **With coverage**: `dart test --coverage=coverage`
- **Verbose mode**: `dart test -v`

**Testing Guidelines**: Never invoke external tools in tests. Use mocks/fakes for all external dependencies. Tests must run fast (< 5 seconds) and be deterministic.

## Development Workflow
1. Make changes to code
2. Format: `dart format .`
3. Lint: `dart analyze`
4. Test: `dart test` (when applicable)
5. Run: `dart run bin/gwm.dart --help` to verify

## Code Style Guidelines

### General Principles
- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `package:lints/recommended.yaml` lints
- Write self-documenting code with clear names
- Prefer immutable data structures
- Use meaningful error messages

### File Organization
```
bin/gwm.dart                 # CLI entry point
lib/src/
  commands/                  # Command handlers (add, switch, delete, list)
  services/                  # Business logic (worktree, config, hooks)
  models/                    # Domain models (worktree, config, hooks)
  infrastructure/            # External integrations (git, filesystem)
  utils/                     # Utilities (path, validation, output)
test/
  unit/                      # Unit tests by component
  integration/               # End-to-end tests
  fixtures/                  # Test data
  mock_objects/              # Test doubles
```

### Naming Conventions
- **Variables/Functions**: `lowerCamelCase`
- **Classes/Types**: `UpperCamelCase`
- **Constants**: `SCREAMING_SNAKE_CASE`
- **Private members**: `_underscorePrefix`
- **Files**: `snake_case.dart`

### Imports
Organize in this order with blank lines:
1. Dart SDK (`dart:*`)
2. Third-party packages (`package:*`)
3. Relative imports (project files)

```dart
import 'dart:io';

import 'package:args/args.dart';

import '../models/config.dart';
```

### Types and Type Annotations
- Explicit types for public APIs
- `var` only when type is obvious
- `final` over `var` for immutables
- Type aliases for complex generics

```dart
// Good
final Map<String, List<int>> data = {};
final Config config;

// Avoid
var data = <String, List<int>>{};
var config;
```

### Error Handling
- Specific exception types over generic `Exception`
- Try-catch for expected errors
- Meaningful user-facing messages
- Custom exceptions in `exceptions.dart`

```dart
try {
  await processData(input);
} on GitException catch (e) {
  printSafe('Git operation failed: ${e.message}');
  return ExitCode.gitFailed;
}
```

### Argument Parsing
- Use `args` package for CLI parsing
- Dedicated parser functions
- Early validation in commands
- Descriptive help text

```dart
ArgParser buildParser() => ArgParser()
  ..addFlag('verbose', abbr: 'v', help: 'Show detailed output')
  ..addOption('config', abbr: 'c', help: 'Config file path');
```

### Code Formatting
- `dart format` handles formatting automatically
- 2-space indentation
- 80-character line limit
- Opening braces on same line

### Documentation
- `///` for public API docs
- Document parameters and return types
- Markdown in doc comments
- Keep docs current with code

```dart
/// Creates a new worktree for the given branch.
///
/// [branch] The Git branch name
/// [createBranch] Whether to create branch if it doesn't exist
/// Returns [ExitCode] indicating success or failure
Future<ExitCode> addWorktree(String branch, {bool createBranch = false});
```

### Collections
- Literals over constructors
- `const` for immutable collections
- Meaningful variable names

```dart
const commands = ['add', 'switch', 'delete'];
final Map<String, Command> commandMap = {};
```

### Null Safety
- Sound null safety enabled
- `?` for nullable types
- `!` for null assertions (rare)
- `??` operator preferred
- `late` for deferred initialization

```dart
String? userInput;
final name = userInput ?? 'Anonymous';
late final Config config;
```

### Async Programming
- `async`/`await` over raw `Future` APIs
- Proper error handling in async code
- `Future.value()` for test immediates
- Streams for data sequences

```dart
Future<void> processFile(String path) async {
  try {
    final content = await File(path).readAsString();
    await validateContent(content);
  } catch (e) {
    printSafe('File processing failed: $e');
  }
}
```

### Testing Patterns
- `package:test` for unit tests
- `package:mocktail` for mocks
- `*_test.dart` naming convention
- `group()` for related tests
- Descriptive test names
- `setUp()`/`tearDown()` for fixtures

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

### Version Management
- Semantic versioning in `pubspec.yaml`
- Keep version constant synchronized

### Security
- Validate all user input
- Safe file operations
- Sanitize output to prevent injection
- No execution of user-provided code

