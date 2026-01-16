import 'dart:io';

import '../models/worktree.dart';

/// Interface for prompting users to select from a list of options.
abstract class PromptSelector {
  /// Prompts the user to select a worktree from the provided list.
  ///
  /// Returns the selected worktree, or null if the selection was cancelled.
  Future<Worktree?> selectWorktree(List<Worktree> worktrees);
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
