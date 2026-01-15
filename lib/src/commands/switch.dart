import 'dart:io';

import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';
import '../models/worktree.dart';
import '../infrastructure/git_client.dart';
import '../infrastructure/prompt_selector.dart';
import '../services/shell_integration.dart';
import '../services/config_service.dart';
import '../services/hook_service.dart';
import '../services/copy_service.dart';
import '../utils/eval_validator.dart';
import '../exceptions.dart';
import '../cli_utils.dart';

/// Command for switching to an existing Git worktree.
///
/// Usage: gwm switch [worktree-name]
class SwitchCommand extends BaseCommand {
  final GitClient _gitClient;
  final PromptSelector _promptSelector;
  final ConfigService _configService;
  final HookService _hookService;
  final CopyService _copyService;
  final ShellIntegration _shellIntegration;

  SwitchCommand(
    this._gitClient,
    this._promptSelector,
    this._configService,
    this._hookService,
    this._copyService,
    this._shellIntegration, {
    super.skipEvalCheck = false,
  });

  @override
  ArgParser get parser {
    return ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Print usage information for this command.',
      )
      ..addFlag(
        'reconfigure',
        abbr: 'r',
        negatable: false,
        help:
            'Reconfigure the worktree by copying files and running add hooks.',
      );
  }

  @override
  Future<ExitCode> execute(ArgResults results) async {
    if (results.flag('help')) {
      printCommandUsage(
        'switch [worktree-name] [options]',
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
      final reconfigure = results.flag('reconfigure');

      final worktrees = await _gitClient.listWorktrees();

      // Interactive selection is now supported even in shell wrapper context
      final targetWorktree = await _resolveTargetWorktree(
        worktreeName,
        worktrees,
      );

      if (targetWorktree == null) {
        if (worktreeName != null) {
          printSafe('Error: Worktree "$worktreeName" does not exist.');
          return ExitCode.generalError;
        } else {
          // Interactive selection: user cancelled or no worktrees available
          // In both cases, just return success without error
          return ExitCode.success;
        }
      }

      // Check if we're already in the target worktree
      final currentPath = Directory.current.path;
      if (targetWorktree.path == currentPath) {
        // Already in the target worktree, nothing to do
        return ExitCode.success;
      }

      // Load configuration for hooks
      final repoRoot = await _getRepoRoot();
      final config = repoRoot != null
          ? await _configService.loadConfig(repoRoot: repoRoot)
          : null;

      if (reconfigure) {
        // Reconfigure mode: copy files and run add hooks
        if (config?.copy != null) {
          try {
            await _copyService.copyFiles(
              config!.copy,
              repoRoot!,
              targetWorktree.path,
            );
          } catch (e) {
            printSafe('Warning: Failed to copy some files to worktree: $e');
            // Continue anyway
          }
        }

        // Execute pre-add hooks (for reconfiguration)
        if (config?.hooks.preAdd != null) {
          try {
            await _hookService.executePreAdd(
              config!.hooks,
              targetWorktree.path,
              repoRoot!,
              targetWorktree.branch,
            );
          } catch (e) {
            printSafe('Error: Pre-add hook failed: $e');
            return ExitCode.hookFailed;
          }
        }

        // Output the cd command for shell integration
        _shellIntegration.outputCdCommand(targetWorktree.path);

        // Execute post-add hooks (for reconfiguration)
        if (config?.hooks.postAdd != null) {
          try {
            await _hookService.executePostAdd(
              config!.hooks,
              targetWorktree.path,
              repoRoot!,
              targetWorktree.branch,
            );
          } catch (e) {
            printSafe('Error: Post-add hook failed: $e');
            return ExitCode.hookFailed;
          }
        }
      } else {
        // Normal switch mode: run switch hooks
        // Execute pre-switch hooks
        if (config?.hooks.preSwitch != null) {
          final originPath = repoRoot ?? Directory.current.path;
          final branch = targetWorktree.branch;
          try {
            await _hookService.executePreSwitch(
              config!.hooks,
              targetWorktree.path,
              originPath,
              branch,
            );
          } catch (e) {
            printSafe('Error: Pre-switch hook failed: $e');
            return ExitCode.hookFailed;
          }
        }

        // Output the cd command for shell integration
        _shellIntegration.outputCdCommand(targetWorktree.path);

        // Execute post-switch hooks
        if (config?.hooks.postSwitch != null) {
          final originPath = repoRoot ?? Directory.current.path;
          final branch = targetWorktree.branch;
          try {
            await _hookService.executePostSwitch(
              config!.hooks,
              targetWorktree.path,
              originPath,
              branch,
            );
          } catch (e) {
            printSafe('Error: Post-switch hook failed: $e');
            return ExitCode.hookFailed;
          }
        }
      }

      return ExitCode.success;
    } on ShellWrapperMissingException catch (e) {
      printSafe(e.message);
      return e.exitCode;
    } catch (e) {
      printSafe('Error: Failed to switch worktree: $e');
      return ExitCode.gitFailed;
    }
  }

  @override
  ExitCode validate(ArgResults results) {
    final args = results.rest;
    if (args.length > 1) {
      printSafe(
        'Error: Too many arguments. Expected at most one worktree name.',
      );
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
      printSafe('Error: Not in a Git repository.');
      return false;
    }

    // The command should work from main repo or existing worktrees
    // We don't restrict it further as the requirements don't specify
    return true;
  }

  /// Gets the repository root directory.
  ///
  /// Returns null if not in a git repo.
  Future<String?> _getRepoRoot() async {
    try {
      return await _gitClient.getRepoRoot();
    } catch (e) {
      // If not in a git repo, return null
      return null;
    }
  }

  /// Gets the path of the current worktree.
  ///
  /// Returns the main repo path if in main workspace, or the worktree path if in a worktree.
  Future<String> _getCurrentWorktreePath() async {
    try {
      final isWorktree = await _gitClient.isWorktree();
      if (isWorktree) {
        // In a worktree, current path is the worktree path
        return Directory.current.path;
      } else {
        // In main workspace, get the main repo path
        final repoRoot = await _getRepoRoot();
        return repoRoot ?? Directory.current.path;
      }
    } catch (e) {
      // Fallback to current directory
      return Directory.current.path;
    }
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
      // Interactive selection - filter out current worktree
      final currentPath = Directory.current.path;
      final availableWorktrees = worktrees
          .where((w) => w.path != currentPath)
          .toList();

      if (availableWorktrees.isEmpty) {
        return null;
      }

      final selected = await _promptSelector.selectWorktree(availableWorktrees);
      return selected;
    }
  }
}
