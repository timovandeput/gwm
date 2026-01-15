import '../models/config.dart';
import 'completion_service.dart';

/// Service for shell integration functionality.
///
/// Provides utilities for outputting commands that can be evaluated by the shell
/// to perform actions like directory changes. All output is designed to be
/// captured by shell wrapper functions using eval.
class ShellIntegration {
  /// Configuration for shell integration features.
  final ShellIntegrationConfig config;

  /// Completion service for tab completion support.
  final CompletionService? completionService;

  /// Creates a new shell integration service with the given configuration.
  const ShellIntegration(this.config, {this.completionService});

  /// Outputs a command to change to the specified directory path.
  ///
  /// The output is formatted for shell evaluation (e.g., `cd /path/to/dir`).
  /// This allows the command to be wrapped by shell functions for automatic
  /// directory switching after worktree operations.
  void outputCdCommand(String path) {
    if (!config.enableEvalOutput) return;
    print('cd $path');
  }

  /// Outputs commands for successful worktree creation.
  ///
  /// Includes directory change command and any other shell commands needed
  /// after creating a new worktree.
  void outputWorktreeCreated(String worktreePath) {
    if (!config.enableEvalOutput) return;
    print('cd $worktreePath');
    print('echo "Worktree created and switched to: $worktreePath"');
  }

  /// Outputs commands for successful worktree switching.
  ///
  /// Includes directory change command and status information.
  void outputWorktreeSwitched(String worktreePath, String worktreeName) {
    if (!config.enableEvalOutput) return;
    print('cd $worktreePath');
    print('echo "Switched to worktree: $worktreeName"');
  }

  /// Outputs commands for worktree listing completion.
  ///
  /// Provides summary information about available worktrees.
  void outputWorktreesListed(int count) {
    if (!config.enableEvalOutput) return;
    print('echo "Found $count worktree(s)"');
  }

  /// Outputs commands for worktree deletion completion.
  ///
  /// Provides feedback about deleted worktrees.
  void outputWorktreesDeleted(List<String> deletedWorktrees) {
    if (!config.enableEvalOutput) return;
    if (deletedWorktrees.isEmpty) {
      print('echo "No worktrees needed deletion."');
    } else {
      print('echo "Deleted worktrees: ${deletedWorktrees.join(", ")}"');
    }
  }

  /// Outputs error message for failed operations.
  ///
  /// Ensures error information is displayed even with shell integration enabled.
  void outputError(String message) {
    // Always output errors regardless of eval output setting
    print('echo "Error: $message" >&2');
  }

  /// Gets completion candidates for shell completion scripts.
  ///
  /// This method is used by completion scripts to get dynamic completion data.
  /// Returns a list of completion candidates for the given command and context.
  Future<List<String>> getCompletionCandidates({
    String? command,
    String partial = '',
    int position = 0,
  }) async {
    if (completionService == null) {
      return [];
    }
    return completionService!.getCompletions(
      command: command,
      partial: partial,
      position: position,
    );
  }
}
