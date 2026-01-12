/// Service for shell integration functionality.
///
/// Provides utilities for outputting commands that can be evaluated by the shell
/// to perform actions like directory changes.
class ShellIntegration {
  /// Outputs a command to change to the specified directory path.
  ///
  /// The output is formatted for shell evaluation (e.g., `cd /path/to/dir`).
  /// This allows the command to be wrapped by shell functions for automatic
  /// directory switching after worktree operations.
  void outputCdCommand(String path) {
    print('cd $path');
  }
}
