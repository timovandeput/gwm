/// Represents a Git worktree in the GWM system.
///
/// A worktree can be either the main Git repository workspace or a linked
/// worktree created with `git worktree add`.
class Worktree {
  /// The display name of the worktree (e.g., "feature-auth")
  final String name;

  /// The Git branch associated with this worktree (e.g., "feature/auth")
  final String branch;

  /// The absolute path to the worktree directory
  final String path;

  /// Whether this is the main Git repository workspace
  final bool isMain;

  /// The current status of the worktree
  final WorktreeStatus status;

  /// The last time this worktree was modified (null if unknown)
  final DateTime? lastModified;

  const Worktree({
    required this.name,
    required this.branch,
    required this.path,
    required this.isMain,
    required this.status,
    this.lastModified,
  });

  /// Creates a copy of this worktree with some fields updated.
  Worktree copyWith({
    String? name,
    String? branch,
    String? path,
    bool? isMain,
    WorktreeStatus? status,
    DateTime? lastModified,
  }) {
    return Worktree(
      name: name ?? this.name,
      branch: branch ?? this.branch,
      path: path ?? this.path,
      isMain: isMain ?? this.isMain,
      status: status ?? this.status,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Worktree &&
        other.name == name &&
        other.branch == branch &&
        other.path == path &&
        other.isMain == isMain &&
        other.status == status &&
        other.lastModified == lastModified;
  }

  @override
  int get hashCode {
    return name.hashCode ^
        branch.hashCode ^
        path.hashCode ^
        isMain.hashCode ^
        status.hashCode ^
        lastModified.hashCode;
  }

  @override
  String toString() {
    return 'Worktree(name: $name, branch: $branch, path: $path, '
        'isMain: $isMain, status: $status, lastModified: $lastModified)';
  }
}

/// The status of a worktree's working directory and relationship to its branch.
enum WorktreeStatus {
  /// Working directory is clean (no uncommitted changes)
  clean,

  /// Working directory has uncommitted changes
  modified,

  /// Local branch is ahead of remote branch
  ahead,

  /// Local branch is behind remote branch
  behind,

  /// Local branch has diverged from remote branch
  diverged,

  /// Worktree is in detached HEAD state
  detached,
}
