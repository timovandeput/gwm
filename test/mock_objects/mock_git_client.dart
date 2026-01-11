import 'package:mocktail/mocktail.dart';

import 'package:gwt/src/infrastructure/git_client.dart';

/// Mock implementation of [GitClient] for testing.
///
/// This mock allows verification of method calls and stubbing of return values
/// using the mocktail library's fluent API.
class MockGitClient extends Mock implements GitClient {}
