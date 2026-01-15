import 'package:args/args.dart';

import '../infrastructure/git_client.dart';

/// Service for handling tab completion of GWM commands.
///
/// Provides completion candidates for worktree names, branch names,
/// and configuration options based on the current context.
class CompletionService {
  final GitClient _gitClient;
  final ArgParser _argParser;

  /// Creates a new completion service with the given Git client and argument parser.
  const CompletionService(this._gitClient, this._argParser);

  /// Gets completion candidates for worktree names.
  ///
  /// Includes all available worktree names plus "." for the main workspace.
  /// Used for commands like `gwm switch` and `gwm list`.
  Future<List<String>> getWorktreeCompletions() async {
    try {
      final worktrees = await _gitClient.listWorktrees();
      final names = worktrees.map((w) => w.isMain ? '.' : w.name).toList();
      // Always include "." for main workspace if not already present
      if (!names.contains('.')) {
        names.insert(0, '.');
      }
      return names;
    } catch (e) {
      // If we can't list worktrees, return just "."
      return ['.'];
    }
  }

  /// Gets completion candidates for worktree names, excluding the current worktree.
  ///
  /// Used for commands like `gwm switch` and `gwm delete` where you shouldn't
  /// be able to switch to or delete the worktree you're currently in.
  Future<List<String>> getWorktreeCompletionsExcludingCurrent() async {
    final allWorktrees = await getWorktreeCompletions();
    final currentWorktree = await _getCurrentWorktreeName();

    // When in main workspace (currentWorktree == '.'), exclude '.' since you can't switch to main from main
    // When in a worktree, exclude the current worktree name since you can't switch to yourself
    return allWorktrees.where((name) => name != currentWorktree).toList();
  }

  /// Gets the name of the current worktree.
  ///
  /// Returns "." for the main workspace, or the worktree name if in a worktree.
  Future<String> _getCurrentWorktreeName() async {
    try {
      final isWorktree = await _gitClient.isWorktree();
      if (isWorktree) {
        final branch = await _gitClient.getCurrentBranch();
        // Extract worktree name from branch (same logic as in GitClientImpl)
        return branch.split('/').last;
      } else {
        // In main workspace
        return '.';
      }
    } catch (e) {
      // If we can't determine current worktree, assume main workspace
      return '.';
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

  /// Gets completion candidates for flags/options.
  ///
  /// If [command] is null, returns global flags. Otherwise, returns flags for the specified command.
  List<String> getFlagCompletions([String? command]) {
    final options = (command == null || command.isEmpty)
        ? _argParser.options
        : _argParser.commands[command]?.options;
    if (options == null) return [];

    return options.values
        .where((option) => option.isFlag)
        .map((flag) => '--${flag.name}')
        .toList();
  }

  /// Gets completion candidates for a specific command and partial input.
  ///
  /// [command] is the subcommand being completed (e.g., 'add', 'switch')
  /// [partial] is the partial input being completed
  /// [position] indicates which argument position we're completing (0-based)
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

    // If partial starts with '-', complete flags
    if (partial.startsWith('-')) {
      return filterCandidates(getFlagCompletions(command));
    }

    if (command == null || command.isEmpty) {
      // Completing subcommands or global flags
      if (partial.startsWith('-')) {
        return filterCandidates(getFlagCompletions(null));
      } else {
        return filterCandidates(getCommandCompletions());
      }
    }

    // For commands, try to complete positional args first, then flags
    final positionalCompletions = await _getPositionalCompletions(
      command,
      position,
    );
    if (positionalCompletions.isNotEmpty) {
      return filterCandidates(positionalCompletions);
    }

    // If no positional completions, complete flags
    return filterCandidates(getFlagCompletions(command));
  }

  /// Gets positional argument completions for a command at the given position.
  Future<List<String>> _getPositionalCompletions(
    String command,
    int position,
  ) async {
    if (position != 0) return []; // Only position 0 has positional args for now

    switch (command) {
      case 'add':
        return await getBranchCompletions();
      case 'switch':
        return await getWorktreeCompletionsExcludingCurrent();
      case 'delete':
        // Check if we're in a worktree - if so, no completion suggestions
        // because delete from worktree only works without arguments (deletes current)
        // or with arguments from main workspace only
        try {
          final isInWorktree = await _gitClient.isWorktree();
          if (isInWorktree) {
            return [];
          }
        } catch (e) {
          // If we can't determine location, err on the side of caution
          return [];
        }

        // Completing worktree name for delete command from main workspace
        // Exclude the main workspace since it cannot be deleted, and exclude current worktree
        return (await getWorktreeCompletionsExcludingCurrent())
            .where((name) => name != '.')
            .toList();
      case 'list':
        return []; // No positional arguments
      default:
        return [];
    }
  }
}
