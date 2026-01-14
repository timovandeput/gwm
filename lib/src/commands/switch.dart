import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';
import '../models/worktree.dart';
import '../infrastructure/git_client.dart';
import '../infrastructure/git_client_impl.dart';
import '../infrastructure/process_wrapper_impl.dart';
import '../infrastructure/prompt_selector.dart';
import '../services/shell_integration.dart';
import '../models/config.dart';
import '../utils/eval_validator.dart';
import '../exceptions.dart';
import '../cli_utils.dart';

/// Command for switching to an existing Git worktree.
///
/// Usage: gwm switch [worktree-name]
class SwitchCommand extends BaseCommand {
  final GitClient _gitClient;
  final PromptSelector _promptSelector;
  final ShellIntegration _shellIntegration;

  SwitchCommand({
    GitClient? gitClient,
    PromptSelector? promptSelector,
    ShellIntegration? shellIntegration,
    Config? config,
    super.skipEvalCheck = false,
  }) : _gitClient = gitClient ?? GitClientImpl(ProcessWrapperImpl()),
       _promptSelector = promptSelector ?? PromptSelectorImpl(),
       _shellIntegration =
           shellIntegration ??
           ShellIntegration(
             config?.shellIntegration ??
                 ShellIntegrationConfig(enableEvalOutput: true),
           );

  @override
  ArgParser get parser {
    return ArgParser()..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print usage information for this command.',
    );
  }

  @override
  Future<ExitCode> execute(ArgResults results) async {
    if (results.flag('help')) {
      printCommandUsage(
        'switch [worktree-name]',
        'Switch to the specified worktree. If no worktree is specified,\nshows an interactive menu to select from available worktrees.\nUse "." to switch to the main workspace.',
        parser,
      );
      return ExitCode.success;
    }

    try {
      // Validate execution context
      final contextValid = await _validateExecutionContext();
      if (!contextValid) {
        return ExitCode.generalError;
      }

      // Validate we're in eval wrapper
      EvalValidator.validate(skipCheck: skipEvalCheck);

      final args = results.rest;
      final worktreeName = args.isNotEmpty ? args[0] : null;

      final worktrees = await _gitClient.listWorktrees();
      final targetWorktree = await _resolveTargetWorktree(
        worktreeName,
        worktrees,
      );

      if (targetWorktree == null) {
        if (worktreeName != null) {
          print('Error: Worktree "$worktreeName" does not exist.');
        }
        return ExitCode.generalError;
      }

      // Output the cd command for shell integration
      _shellIntegration.outputCdCommand(targetWorktree.path);

      return ExitCode.success;
    } on ShellWrapperMissingException catch (e) {
      print(e.message);
      return e.exitCode;
    } catch (e) {
      print('Error: Failed to switch worktree: $e');
      return ExitCode.gitFailed;
    }
  }

  @override
  ExitCode validate(ArgResults results) {
    final args = results.rest;
    if (args.length > 1) {
      print('Error: Too many arguments. Expected at most one worktree name.');
      return ExitCode.invalidArguments;
    }
    return ExitCode.success;
  }

  /// Validates that the command is being executed in a valid context.
  ///
  /// Must be run from the main repository or an existing worktree.
  Future<bool> _validateExecutionContext() async {
    // Check if we're in a git repository at all
    try {
      await _gitClient.getRepoRoot();
    } catch (e) {
      print('Error: Not in a Git repository.');
      return false;
    }

    // The command should work from main repo or existing worktrees
    // We don't restrict it further as the requirements don't specify
    return true;
  }

  /// Resolves the target worktree based on the provided name or interactive selection.
  ///
  /// Returns null if the worktree is not found or selection is cancelled.
  Future<Worktree?> _resolveTargetWorktree(
    String? worktreeName,
    List<Worktree> worktrees,
  ) async {
    if (worktreeName != null) {
      // Direct specification
      if (worktreeName == '.') {
        // Switch to main workspace
        final mainWorktrees = worktrees.where((w) => w.isMain);
        return mainWorktrees.isNotEmpty ? mainWorktrees.first : null;
      } else {
        // Find worktree by name
        final matchingWorktrees = worktrees.where(
          (w) => w.name == worktreeName,
        );
        return matchingWorktrees.isNotEmpty ? matchingWorktrees.first : null;
      }
    } else {
      // Interactive selection
      final selected = _promptSelector.selectWorktree(worktrees);
      return selected;
    }
  }
}
