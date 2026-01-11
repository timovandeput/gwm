# AGENTS.md - Development Guidelines for GWT CLI Tool

## Project Overview
GWT is a Dart command-line application that provides basic argument parsing functionality. This document outlines development practices, build commands, and coding standards for agents working on this codebase.

## Build, Lint, and Test Commands

### Build Commands
- **Run the application**: `dart run bin/gwt.dart`
- **Build executable**: `dart compile exe bin/gwt.dart -o gwt`

### Lint Commands
- **Run static analysis**: `dart analyze`
- **Format code**: `dart format .`
- **Format with changes check**: `dart format --set-exit-if-changed .`

### Test Commands
- **Run all tests**: `dart test`
- **Run specific test file**: `dart test test/file_test.dart`
- **Run single test by name**: `dart test -n "test name"`
- **Run tests with coverage**: `dart test --coverage=coverage`
- **Run tests in verbose mode**: `dart test -v`

Note: Currently no test files exist. Create tests in `test/` directory following Dart test package conventions.

### Development Workflow
1. Make changes to code
2. Format: `dart format .`
3. Lint: `dart analyze`
4. Test: `dart test` (when tests exist)
5. Run: `dart run bin/gwt.dart --help` to verify functionality

## Code Style Guidelines

### General Principles
- Follow the official [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use the recommended lints from `package:lints/recommended.yaml`
- Write self-documenting code with clear variable/function names
- Prefer immutable data structures when possible
- Use meaningful error messages for user-facing output

### File Organization
```
lib/           # Library code (if added later)
bin/           # Executable entry points
  gwt.dart     # Main CLI application
test/          # Test files (create as needed)
  *_test.dart  # Test files follow this naming convention
```

### Naming Conventions

#### Variables and Functions
- Use `lowerCamelCase` for variables, parameters, and function names
- Use `UpperCamelCase` for class names and type aliases
- Use `SCREAMING_SNAKE_CASE` for constants
- Prefix private members with underscore: `_privateVariable`

#### Files and Directories
- Use `snake_case` for file names: `argument_parser.dart`
- Use `lowerCamelCase` for library names in pubspec.yaml

### Imports and Dependencies
- Organize imports in this order:
  1. Dart SDK imports (`dart:*`)
  2. Third-party packages (`package:*`)
  3. Relative imports (project files)
- Add blank line between import groups
- Use relative imports for files within the same package
- Avoid wildcard imports (`import 'package:foo.dart' show Class1, Class2;`)

```dart
import 'dart:io';

import 'package:args/args.dart';

import 'utils.dart';
```

### Types and Type Annotations
- Use explicit types for all public APIs
- Use `var` only when type is obvious from context
- Prefer `final` over `var` for immutable variables
- Use type aliases for complex generic types

```dart
// Good
final Map<String, List<int>> data = {};

// Avoid
var data = <String, List<int>>{};
```

### Error Handling
- Use try-catch blocks for expected errors
- Prefer specific exception types over generic `Exception`
- Provide meaningful error messages to users
- Use `throw` for programming errors, not user input validation

```dart
try {
  final result = parseArguments(args);
  return result;
} on FormatException catch (e) {
  print('Invalid arguments: ${e.message}');
  printUsage();
  exit(1);
}
```

### Argument Parsing
- Use the `args` package for CLI argument handling
- Define flags and options in a dedicated parser function
- Validate arguments early in `main()`
- Use descriptive help text for all flags/options

```dart
ArgParser buildParser() {
  return ArgParser()
    ..addFlag(
      'verbose',
      abbr: 'v',
      help: 'Show additional command output.',
    )
    ..addOption(
      'output',
      abbr: 'o',
      help: 'Specify output file path.',
    );
}
```

### Code Formatting
- Let `dart format` handle indentation and spacing
- Use 2 spaces for indentation (Dart standard)
- Maximum line length: 80 characters (Dart standard)
- Place opening braces on the same line

```dart
// Correct formatting
if (condition) {
  doSomething();
} else {
  doSomethingElse();
}
```

### Documentation
- Use `///` for public API documentation
- Document parameters and return types
- Keep comments up-to-date with code changes
- Use markdown in doc comments for formatting

```dart
/// Parses command-line arguments and returns a configuration object.
///
/// [arguments] should contain the raw command-line arguments.
/// Returns a [Config] object with parsed values.
Config parseArguments(List<String> arguments) {
  // Implementation...
}
```

### Constants and Magic Numbers
- Extract magic numbers to named constants
- Group related constants in classes or at file top
- Use descriptive names for constants

```dart
const int defaultPort = 8080;
const String appName = 'gwt';
const Duration timeout = Duration(seconds: 30);
```

### String Handling
- Use single quotes for strings unless containing single quotes
- Use string interpolation over concatenation
- Prefer raw strings for regex patterns and file paths

```dart
// Good
final message = 'Hello, $name!';
final pattern = r'\d+';

// Avoid
final message = 'Hello, ' + name + '!';
```

### Collections
- Use collection literals over constructors
- Prefer `const` for immutable collections
- Use meaningful variable names for collection contents

```dart
// Good
const commands = ['help', 'version', 'run'];
final Map<String, Command> commandMap = {};

// Avoid
var list = List<String>();
var map = Map<String, String>();
```

### Null Safety
- Enable sound null safety (Dart 2.12+)
- Use `?` for nullable types, `!` for null assertions
- Prefer `??` operator over null checks
- Use `late` for variables initialized later

```dart
// Good
String? userInput;
final displayName = userInput ?? 'Anonymous';

// Avoid
String displayName;
if (userInput != null) {
  displayName = userInput;
} else {
  displayName = 'Anonymous';
}
```

### Async Programming
- Use `async`/`await` over raw `Future` APIs
- Handle errors in async code with try-catch
- Use `Future.value()` for immediate values in tests
- Prefer `Stream` for sequences of data

```dart
Future<void> processFile(String path) async {
  try {
    final content = await File(path).readAsString();
    await processContent(content);
  } catch (e) {
    print('Error processing file: $e');
  }
}
```

### Testing Guidelines
When creating tests (in `test/` directory):

- Use `package:test` for unit tests
- Follow naming convention: `*_test.dart`
- Group related tests in `group()` blocks
- Use descriptive test names: `'parses valid arguments'`
- Test both success and error cases
- Use `setUp()` and `tearDown()` for test fixtures

```dart
import 'package:test/test.dart';

void main() {
  group('ArgumentParser', () {
    test('parses help flag', () {
      final parser = buildParser();
      final result = parser.parse(['--help']);
      expect(result.flag('help'), isTrue);
    });

    test('throws on invalid arguments', () {
      final parser = buildParser();
      expect(() => parser.parse(['--invalid']),
             throwsA(isA<FormatException>()));
    });
  });
}
```

### Version Management
- Update version in `pubspec.yaml` following semantic versioning
- Update `CHANGELOG.md` with changes for each version
- Keep version constant in sync with pubspec.yaml

### Security Considerations
- Validate all user input before processing
- Avoid executing user-provided code or commands
- Use safe file operations with proper error handling
- Sanitize output to prevent injection attacks

### Performance Guidelines
- Prefer efficient algorithms for data processing
- Use lazy evaluation where appropriate
- Profile performance-critical code sections
- Consider memory usage for large data sets

Remember: This is a CLI tool focused on argument parsing. Keep the codebase simple, well-tested, and maintainable. Always run `dart analyze` and `dart format` before committing changes.