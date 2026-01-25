import 'hook.dart';

/// Configuration for the GWM CLI tool.
///
/// Contains all settings that control GWM behavior, loaded from
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
  final Hook? preCreate;

  /// Commands to run after creating a worktree
  final Hook? postCreate;

  /// Commands to run before switching worktrees
  final Hook? preSwitch;

  /// Commands to run after switching worktrees
  final Hook? postSwitch;

  /// Commands to run before deleting a worktree
  final Hook? preDelete;

  /// Commands to run after deleting a worktree
  final Hook? postDelete;

  const HooksConfig({
    required this.timeout,
    this.preCreate,
    this.postCreate,
    this.preSwitch,
    this.postSwitch,
    this.preDelete,
    this.postDelete,
  });

  /// Creates a copy of this config with some fields updated.
  HooksConfig copyWith({
    int? timeout,
    Hook? preCreate,
    Hook? postCreate,
    Hook? preSwitch,
    Hook? postSwitch,
    Hook? preDelete,
    Hook? postDelete,
  }) {
    return HooksConfig(
      timeout: timeout ?? this.timeout,
      preCreate: preCreate ?? this.preCreate,
      postCreate: postCreate ?? this.postCreate,
      preSwitch: preSwitch ?? this.preSwitch,
      postSwitch: postSwitch ?? this.postSwitch,
      preDelete: preDelete ?? this.preDelete,
      postDelete: postDelete ?? this.postDelete,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is HooksConfig &&
        other.timeout == timeout &&
        other.preCreate == preCreate &&
        other.postCreate == postCreate &&
        other.preSwitch == preSwitch &&
        other.postSwitch == postSwitch &&
        other.preDelete == preDelete &&
        other.postDelete == postDelete;
  }

  @override
  int get hashCode {
    return timeout.hashCode ^
        preCreate.hashCode ^
        postCreate.hashCode ^
        preSwitch.hashCode ^
        postSwitch.hashCode ^
        preDelete.hashCode ^
        postDelete.hashCode;
  }

  @override
  String toString() {
    return 'HooksConfig(timeout: $timeout, preCreate: $preCreate, postCreate: $postCreate, '
        'preSwitch: $preSwitch, postSwitch: $postSwitch, '
        'preDelete: $preDelete, postDelete: $postDelete)';
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
