import 'hook.dart';

/// Configuration for the GWT CLI tool.
///
/// Contains all settings that control GWT behavior, loaded from
/// global, repository, and local configuration files.
class Config {
  /// Configuration version for migration support
  final String version;

  /// Configuration for file and directory copying
  final CopyConfig copy;

  /// Configuration for hook execution
  final HooksConfig hooks;

  /// Configuration for shell integration features
  final ShellIntegrationConfig shellIntegration;

  const Config({
    required this.version,
    required this.copy,
    required this.hooks,
    required this.shellIntegration,
  });

  /// Creates a copy of this config with some fields updated.
  Config copyWith({
    String? version,
    CopyConfig? copy,
    HooksConfig? hooks,
    ShellIntegrationConfig? shellIntegration,
  }) {
    return Config(
      version: version ?? this.version,
      copy: copy ?? this.copy,
      hooks: hooks ?? this.hooks,
      shellIntegration: shellIntegration ?? this.shellIntegration,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Config &&
        other.version == version &&
        other.copy == copy &&
        other.hooks == hooks &&
        other.shellIntegration == shellIntegration;
  }

  @override
  int get hashCode {
    return version.hashCode ^
        copy.hashCode ^
        hooks.hashCode ^
        shellIntegration.hashCode;
  }

  @override
  String toString() {
    return 'Config(version: $version, copy: $copy, hooks: $hooks, '
        'shellIntegration: $shellIntegration)';
  }
}

/// Configuration for file and directory copying to worktrees.
class CopyConfig {
  /// List of file patterns to copy (supports glob patterns)
  final List<String> files;

  /// List of directory paths to copy recursively
  final List<String> directories;

  const CopyConfig({required this.files, required this.directories});

  /// Creates a copy of this config with some fields updated.
  CopyConfig copyWith({List<String>? files, List<String>? directories}) {
    return CopyConfig(
      files: files ?? this.files,
      directories: directories ?? this.directories,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CopyConfig &&
        _listEquals(other.files, files) &&
        _listEquals(other.directories, directories);
  }

  @override
  int get hashCode {
    return files.hashCode ^ directories.hashCode;
  }

  @override
  String toString() {
    return 'CopyConfig(files: $files, directories: $directories)';
  }
}

/// Configuration for hook execution during worktree operations.
class HooksConfig {
  /// Default timeout in seconds for hook execution
  final int timeout;

  /// Commands to run before creating a worktree
  final Hook? preAdd;

  /// Commands to run after creating a worktree
  final Hook? postAdd;

  /// Commands to run before switching worktrees
  final Hook? preSwitch;

  /// Commands to run after switching worktrees
  final Hook? postSwitch;

  /// Commands to run before cleaning a worktree
  final Hook? preClean;

  /// Commands to run after cleaning a worktree
  final Hook? postClean;

  const HooksConfig({
    required this.timeout,
    this.preAdd,
    this.postAdd,
    this.preSwitch,
    this.postSwitch,
    this.preClean,
    this.postClean,
  });

  /// Creates a copy of this config with some fields updated.
  HooksConfig copyWith({
    int? timeout,
    Hook? preAdd,
    Hook? postAdd,
    Hook? preSwitch,
    Hook? postSwitch,
    Hook? preClean,
    Hook? postClean,
  }) {
    return HooksConfig(
      timeout: timeout ?? this.timeout,
      preAdd: preAdd ?? this.preAdd,
      postAdd: postAdd ?? this.postAdd,
      preSwitch: preSwitch ?? this.preSwitch,
      postSwitch: postSwitch ?? this.postSwitch,
      preClean: preClean ?? this.preClean,
      postClean: postClean ?? this.postClean,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is HooksConfig &&
        other.timeout == timeout &&
        other.preAdd == preAdd &&
        other.postAdd == postAdd &&
        other.preSwitch == preSwitch &&
        other.postSwitch == postSwitch &&
        other.preClean == preClean &&
        other.postClean == postClean;
  }

  @override
  int get hashCode {
    return timeout.hashCode ^
        preAdd.hashCode ^
        postAdd.hashCode ^
        preSwitch.hashCode ^
        postSwitch.hashCode ^
        preClean.hashCode ^
        postClean.hashCode;
  }

  @override
  String toString() {
    return 'HooksConfig(timeout: $timeout, preAdd: $preAdd, postAdd: $postAdd, '
        'preSwitch: $preSwitch, postSwitch: $postSwitch, '
        'preClean: $preClean, postClean: $postClean)';
  }
}

/// Configuration for shell integration features.
class ShellIntegrationConfig {
  /// Whether to enable eval output for automatic directory switching
  final bool enableEvalOutput;

  const ShellIntegrationConfig({required this.enableEvalOutput});

  /// Creates a copy of this config with some fields updated.
  ShellIntegrationConfig copyWith({bool? enableEvalOutput}) {
    return ShellIntegrationConfig(
      enableEvalOutput: enableEvalOutput ?? this.enableEvalOutput,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ShellIntegrationConfig &&
        other.enableEvalOutput == enableEvalOutput;
  }

  @override
  int get hashCode => enableEvalOutput.hashCode;

  @override
  String toString() {
    return 'ShellIntegrationConfig(enableEvalOutput: $enableEvalOutput)';
  }
}

/// Helper function to compare lists for equality
bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null) return false;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
