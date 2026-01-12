import 'dart:io';

import '../models/worktree.dart';
import 'process_wrapper.dart';
import 'process_wrapper_impl.dart';

/// Interface for prompting users to select from a list of options.
abstract class PromptSelector {
  /// Prompts the user to select a worktree from the provided list.
  ///
  /// Returns the selected worktree, or null if the selection was cancelled.
  Future<Worktree?> selectWorktree(List<Worktree> worktrees);
}

/// Factory for creating prompt selectors with appropriate implementations.
class PromptSelectorFactory {
  static const String _fzfCommand = 'fzf';

  /// Creates the most appropriate prompt selector based on available tools.
  ///
  /// Uses FZF if available, otherwise falls back to basic console input.
  static Future<PromptSelector> createAsync({
    ProcessWrapper? processWrapper,
  }) async {
    final wrapper = processWrapper ?? ProcessWrapperImpl();
    if (await _isFzfAvailableAsync(wrapper)) {
      return FzfPromptSelector(wrapper);
    }
    return PromptSelectorImpl();
  }

  /// Checks if fzf is available on the system.
  static Future<bool> _isFzfAvailableAsync(
    ProcessWrapper processWrapper,
  ) async {
    try {
      final result = await processWrapper.run(_fzfCommand, ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}

/// Default implementation of PromptSelector that uses stdin/stdout for interaction.
class PromptSelectorImpl implements PromptSelector {
  @override
  Future<Worktree?> selectWorktree(List<Worktree> worktrees) async {
    if (worktrees.isEmpty) {
      stderr.writeln('No worktrees available to switch to.');
      return null;
    }

    // Display options
    stdout.writeln('Available worktrees:');
    for (var i = 0; i < worktrees.length; i++) {
      final worktree = worktrees[i];
      final marker = worktree.isMain ? '(current)' : '';
      stdout.writeln('${i + 1}. ${worktree.name} $marker');
    }
    stdout.writeln('0. Cancel');

    // Read user input
    stdout.write('Select worktree (1-${worktrees.length}) or 0 to cancel: ');
    final input = stdin.readLineSync()?.trim();

    if (input == null || input.isEmpty) {
      stdout.writeln('Selection cancelled.');
      return null;
    }

    final choice = int.tryParse(input);
    if (choice == null) {
      stderr.writeln('Invalid input. Please enter a number.');
      return null;
    }

    if (choice == 0) {
      stdout.writeln('Selection cancelled.');
      return null;
    }

    if (choice < 1 || choice > worktrees.length) {
      stderr.writeln(
        'Invalid choice. Please select a number between 1 and ${worktrees.length}.',
      );
      return null;
    }

    return worktrees[choice - 1];
  }
}

/// FZF-based implementation of PromptSelector for enhanced interactive selection.
class FzfPromptSelector implements PromptSelector {
  final ProcessWrapper _processWrapper;

  FzfPromptSelector(this._processWrapper);

  @override
  Future<Worktree?> selectWorktree(List<Worktree> worktrees) async {
    if (worktrees.isEmpty) {
      stderr.writeln('No worktrees available to switch to.');
      return null;
    }

    try {
      // Prepare the list for fzf
      final options = <String>[];
      for (var i = 0; i < worktrees.length; i++) {
        final worktree = worktrees[i];
        final marker = worktree.isMain ? '(current)' : '';
        options.add('${worktree.name} $marker');
      }

      // Run fzf with the options
      final result = await _processWrapper.run(
        'fzf',
        [
          '--height', '40%',
          '--border',
          '--header', 'Select worktree (ESC to cancel):',
          '--with-nth', '1', // Only show the worktree name in the interface
        ],
        timeout: Duration(seconds: 300), // Allow time for user interaction
      );

      if (result.exitCode == 0) {
        final selected = result.stdout.trim();
        if (selected.isNotEmpty) {
          // Extract the worktree name (remove the marker if present)
          final worktreeName = selected.split(' ').first;
          return worktrees.firstWhere((wt) => wt.name == worktreeName);
        }
      } else if (result.exitCode == 130) {
        // fzf was cancelled (Ctrl+C or ESC)
        stdout.writeln('Selection cancelled.');
        return null;
      }

      // fzf failed or no selection made
      return null;
    } catch (e) {
      // Fallback to basic selector if fzf fails
      stderr.writeln('FZF selection failed, falling back to basic selection.');
      return await PromptSelectorImpl().selectWorktree(worktrees);
    }
  }
}
