import 'dart:io';

import 'package:path/path.dart' as path;

import '../infrastructure/file_system_adapter.dart';
import '../infrastructure/platform_detector.dart';
import '../models/config.dart';

/// Service for copying files and directories to worktrees with Copy-on-Write optimization.
///
/// Supports glob pattern matching and automatic platform-specific optimization:
/// - macOS APFS: Uses clone for instant copying
/// - Linux Btrfs/XFS: Uses reflink for instant copying
/// - Other filesystems: Falls back to standard copy
class CopyService {
  final FileSystemAdapter _fileSystem;

  CopyService(this._fileSystem);

  /// Copies files and directories according to the provided configuration.
  ///
  /// [config] contains the copy patterns and directories to copy.
  /// [sourceDir] is the source directory to copy from (usually main repo).
  /// [destDir] is the destination directory to copy to (usually new worktree).
  ///
  /// Missing source files are logged as warnings but don't fail the operation.
  /// Copy errors are reported but don't stop the entire operation.
  Future<void> copyFiles(
    CopyConfig config,
    String sourceDir,
    String destDir,
  ) async {
    // Copy files matching glob patterns
    for (final pattern in config.files) {
      await _copyFilesByPattern(pattern, sourceDir, destDir);
    }

    // Copy directories recursively
    for (final dir in config.directories) {
      await _copyDirectoryByPattern(dir, sourceDir, destDir);
    }
  }

  /// Copies files matching a glob pattern from source to destination.
  Future<void> _copyFilesByPattern(
    String pattern,
    String sourceDir,
    String destDir,
  ) async {
    final sourcePath = path.join(sourceDir, pattern);

    // If pattern contains no wildcards, treat as direct file path
    if (!pattern.contains('*') &&
        !pattern.contains('?') &&
        !pattern.contains('{')) {
      await _copyFileSafe(sourcePath, path.join(destDir, pattern));
      return;
    }

    // Find matching files using file system adapter
    final matches = _fileSystem.listContents(sourceDir, pattern: pattern);
    for (final relativePath in matches) {
      final sourceFile = path.join(sourceDir, relativePath);
      if (_fileSystem.fileExists(sourceFile)) {
        final destPath = path.join(destDir, relativePath);
        await _copyFileSafe(sourceFile, destPath);
      }
    }
  }

  /// Copies a directory matching a pattern from source to destination.
  Future<void> _copyDirectoryByPattern(
    String pattern,
    String sourceDir,
    String destDir,
  ) async {
    final sourcePath = path.join(sourceDir, pattern);

    // If pattern contains wildcards, find matching directories
    if (pattern.contains('*') ||
        pattern.contains('?') ||
        pattern.contains('{')) {
      final matches = _fileSystem.listContents(sourceDir, pattern: pattern);
      for (final relativePath in matches) {
        final sourceDirPath = path.join(sourceDir, relativePath);
        if (_fileSystem.directoryExists(sourceDirPath)) {
          final destPath = path.join(destDir, relativePath);
          await _copyDirectorySafe(sourceDirPath, destPath);
        }
      }
    } else {
      // Direct directory path
      final destPath = path.join(destDir, pattern);
      await _copyDirectorySafe(sourcePath, destPath);
    }
  }

  /// Copies a file safely, attempting CoW when possible.
  ///
  /// Logs warnings for missing files but doesn't throw.
  /// Logs errors for copy failures but doesn't throw.
  Future<void> _copyFileSafe(String source, String dest) async {
    if (!_fileSystem.fileExists(source)) {
      _logWarning('Source file not found: $source');
      return;
    }

    try {
      await _copyFileWithOptimization(source, dest);
    } catch (e) {
      _logError('Failed to copy file $source to $dest: $e');
    }
  }

  /// Copies a directory safely, attempting CoW when possible.
  ///
  /// Logs warnings for missing directories but doesn't throw.
  /// Logs errors for copy failures but doesn't throw.
  Future<void> _copyDirectorySafe(String source, String dest) async {
    if (!_fileSystem.directoryExists(source)) {
      _logWarning('Source directory not found: $source');
      return;
    }

    try {
      await _copyDirectoryWithOptimization(source, dest);
    } catch (e) {
      _logError('Failed to copy directory $source to $dest: $e');
    }
  }

  /// Copies a file using the best available method for the platform.
  Future<void> _copyFileWithOptimization(String source, String dest) async {
    final platform = PlatformDetector.current;

    // Try CoW methods first
    if (platform == Platform.macos) {
      if (await _tryClone(source, dest)) return;
    } else if (platform == Platform.linux) {
      if (await _tryReflink(source, dest)) return;
    }

    // Fall back to standard copy
    await _fileSystem.copyFile(source, dest);
  }

  /// Copies a directory using the best available method for the platform.
  Future<void> _copyDirectoryWithOptimization(
    String source,
    String dest,
  ) async {
    final platform = PlatformDetector.current;

    // Try CoW methods first
    if (platform == Platform.macos) {
      if (await _tryClone(source, dest)) return;
    } else if (platform == Platform.linux) {
      if (await _tryReflink(source, dest)) return;
    }

    // Fall back to standard copy
    await _fileSystem.copyDirectory(source, dest);
  }

  /// Attempts to clone a file or directory on macOS APFS.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> _tryClone(String source, String dest) async {
    try {
      // Use cp -c (clone) for macOS APFS
      final result = await Process.run('cp', ['-c', source, dest]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Attempts to reflink a file or directory on Linux Btrfs/XFS.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> _tryReflink(String source, String dest) async {
    try {
      // Use cp --reflink for Linux Btrfs/XFS
      final result = await Process.run('cp', ['--reflink', source, dest]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Logs a warning message.
  ///
  /// In production, this would integrate with the output formatter.
  void _logWarning(String message) {
    print('Warning: $message');
  }

  /// Logs an error message.
  ///
  /// In production, this would integrate with the output formatter.
  void _logError(String message) {
    print('Error: $message');
  }
}
