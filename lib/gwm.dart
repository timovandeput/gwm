/// GWM (Git Worktree Manager) - A CLI tool for streamlined Git worktree management.
///
/// This library provides the core domain models, exceptions, and utilities
/// for managing Git worktrees with automatic directory navigation,
/// configurable hooks, and cross-platform support.

library;

// Export domain models
export 'src/models/worktree.dart';
export 'src/models/config.dart';
export 'src/models/hook.dart';
export 'src/models/exit_codes.dart';

// Export commands
export 'src/commands/base.dart';
export 'src/commands/add.dart';
export 'src/commands/switch.dart';
export 'src/commands/clean.dart';
export 'src/commands/list.dart';

// Export exceptions
export 'src/exceptions.dart';
