import 'dart:async';

/// Interface for file system operations.
///
/// This abstraction allows for different implementations in production code
/// (using actual file system operations) and test code (using fake implementations).
abstract class FileSystemAdapter {
  /// Checks if a file exists at the given path.
  bool fileExists(String path);

  /// Checks if a directory exists at the given path.
  bool directoryExists(String path);

  /// Creates a directory at the given path (creates parent directories if needed).
  Future<void> createDirectory(String path);

  /// Copies a file from source to destination.
  Future<void> copyFile(String source, String destination);

  /// Copies a directory recursively from source to destination.
  Future<void> copyDirectory(String source, String destination);

  /// Lists files and directories in the given path, optionally filtered by pattern.
  ///
  /// [pattern] is a glob pattern (e.g., "*.dart", "**/*.json").
  /// If null, returns all files and directories.
  List<String> listContents(String path, {String? pattern});

  /// Reads the contents of a file as a string.
  Future<String> readFile(String path);

  /// Writes content to a file (creates parent directories if needed).
  Future<void> writeFile(String path, String content);

  /// Deletes a file.
  Future<void> deleteFile(String path);

  /// Deletes a directory recursively.
  Future<void> deleteDirectory(String path);

  /// Gets the last modified time of a file or directory.
  Future<DateTime> getLastModified(String path);

  /// Gets the size of a file in bytes.
  Future<int> getFileSize(String path);
}
