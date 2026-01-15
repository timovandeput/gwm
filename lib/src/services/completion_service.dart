import '../infrastructure/git_client.dart';

/// Service for handling tab completion of GWM commands.
///
/// Provides completion candidates for worktree names, branch names,
/// and configuration options based on the current context.
class CompletionService {
  final GitClient _gitClient;

  /// Creates a new completion service with the given Git client.
  const CompletionService(this._gitClient);

  /// Gets completion candidates for worktree names.
  ///
  /// Includes all available worktree names plus "." for the main workspace.
  /// Used for commands like `gwm switch` and `gwm list`.
  Future<List<String>> getWorktreeCompletions() async {
    try {
      final worktrees = await _gitClient.listWorktrees();
      final names = worktrees.map((w) => w.name).toList();
      // Always include "." for main workspace
      if (!names.contains('.')) {
        names.insert(0, '.');
      }
      return names;
    } catch (e) {
      // If we can't list worktrees, return just "."
      return ['.'];
    }
  }

  /// Gets completion candidates for Git branch names.
  ///
  /// Used for commands like `gwm add` where a branch name is expected.
  Future<List<String>> getBranchCompletions() async {
    try {
      final branches = await _gitClient.listBranches();
      return branches;
    } catch (e) {
      // Return empty list if we can't get branches
      return [];
    }
  }

  /// Gets completion candidates for configuration options.
  ///
  /// Currently supports basic config keys that can be set.
  /// Used for future `gwm config` command.
  List<String> getConfigCompletions() {
    // Basic config keys that might be set
    return [
      'version',
      'copy.files',
      'copy.directories',
      'hooks.timeout',
      'hooks.pre_add',
      'hooks.post_add',
      'hooks.pre_switch',
      'hooks.post_switch',
      'hooks.pre_delete',
      'hooks.post_delete',
      'shell_integration.enable_eval_output',
    ];
  }

  /// Gets completion candidates for subcommands.
  ///
  /// Returns the list of available GWM subcommands.
  List<String> getCommandCompletions() {
    return ['add', 'switch', 'delete', 'list'];
  }

  /// Gets completion candidates for a specific command and partial input.
  ///
  /// [command] is the subcommand being completed (e.g., 'add', 'switch')
  /// [partial] is the partial input being completed
  /// [position] indicates which argument position we're completing
  Future<List<String>> getCompletions({
    String? command,
    String partial = '',
    int position = 0,
  }) async {
    // Filter candidates based on partial input
    List<String> filterCandidates(List<String> candidates) {
      if (partial.isEmpty) return candidates;
      return candidates.where((c) => c.startsWith(partial)).toList();
    }

    if (command == null) {
      // Completing subcommands
      return filterCandidates(getCommandCompletions());
    }

    switch (command) {
      case 'add':
        if (position == 0) {
          // Completing branch name for add command
          return filterCandidates(await getBranchCompletions());
        }
        break;
      case 'switch':
        if (position == 0) {
          // Completing worktree name for switch command
          return filterCandidates(await getWorktreeCompletions());
        }
        break;
      case 'delete':
        // No positional arguments to complete
        break;
      case 'list':
        // No positional arguments to complete
        break;
    }

    return [];
  }
}
