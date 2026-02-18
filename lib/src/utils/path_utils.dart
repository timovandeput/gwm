import 'package:path/path.dart' as path;

import '../infrastructure/git_client.dart';

/// Utility class for platform-appropriate path handling.
///
/// This class provides cross-platform path operations using the `path` package
/// to ensure consistent behavior across Windows, macOS, and Linux.
class PathUtils {
  /// The path context for the current platform.
  static final _context = path.Context();

  /// Joins path segments using the platform-appropriate separator.
  static String join(List<String> parts) => _context.joinAll(parts);

  /// Gets the platform-appropriate path separator.
  static String get separator => _context.separator;

  /// Normalizes a path by resolving '..' and '.' segments.
  static String normalize(String path) => _context.normalize(path);

  /// Checks if a path is absolute.
  static bool isAbsolute(String path) => _context.isAbsolute(path);

  /// Gets the basename (last segment) of a path.
  static String basename(String path) => _context.basename(path);

  /// Gets the directory name of a path (all segments except the last).
  static String dirname(String path) => _context.dirname(path);

  /// Converts a relative path to an absolute path.
  static String absolute(String path) => _context.absolute(path);

  /// Gets the relative path from [from] to [to].
  static String relative(String to, {String? from}) =>
      _context.relative(to, from: from);

  /// Splits a path into its segments.
  static List<String> split(String path) => _context.split(path);

  /// Gets the extension of a path (including the leading dot).
  static String extension(String path) => _context.extension(path);

  /// Removes the extension from a path.
  static String withoutExtension(String path) =>
      _context.withoutExtension(path);
}

/// Gets the repository root directory, returning null if not in a git repo.
Future<String?> getRepoRootOrNull(GitClient gitClient) async {
  try {
    return await gitClient.getRepoRoot();
  } catch (e) {
    return null;
  }
}
