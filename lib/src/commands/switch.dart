import 'dart:io';

import 'package:args/args.dart';

import 'base.dart';
import '../models/exit_codes.dart';
import '../models/worktree.dart';
import '../infrastructure/git_client.dart';
import '../infrastructure/git_client_impl.dart';
import '../infrastructure/process_wrapper_impl.dart';
import '../infrastructure/prompt_selector.dart';
import '../infrastructure/file_system_adapter_impl.dart';
import '../services/shell_integration.dart';
import '../services/config_service.dart';
import '../services/hook_service.dart';
import '../services/copy_service.dart';
import '../infrastructure/file_system_adapter.dart';
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
  final ConfigService _configService;
  final HookService _hookService;
  final CopyService _copyService;
  final ShellIntegration _shellIntegration;

  SwitchCommand({
    GitClient? gitClient,
    PromptSelector? promptSelector,
    ConfigService? configService,
    HookService? hookService,
    CopyService? copyService,
    FileSystemAdapter? fileSystemAdapter,
    ShellIntegration? shellIntegration,
    Config? config,
    super.skipEvalCheck = false,
  }) : _gitClient = gitClient ?? GitClientImpl(ProcessWrapperImpl()),
       _promptSelector = promptSelector ?? PromptSelectorImpl(),
       _configService = configService ?? ConfigService(),
       _hookService = hookService ?? HookService(ProcessWrapperImpl()),
       _copyService =
           copyService ??
           CopyService(fileSystemAdapter ?? FileSystemAdapterImpl()),
       _shellIntegration =
           shellIntegration ??
           ShellIntegration(
             config?.shellIntegration ??
                 ShellIntegrationConfig(enableEvalOutput: true),
           );

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

      // Check if interactive mode is requested but we're in eval context
      if (worktreeName == null && !skipEvalCheck) {
        // Filter out the current worktree from the list
        final currentPath = Directory.current.path;
        final availableWorktrees = worktrees.where(
          (w) => w.path != currentPath,
        );
        final message = availableWorktrees.isEmpty
            ? 'No worktrees available to switch to.'
            : 'Available worktrees: ${availableWorktrees.map((w) => w.name).join(', ')}\nPlease specify a worktree name: gwm switch <worktree-name>';
        printSafe(
          'Error: Interactive worktree selection is not available when using the shell wrapper.\n'
          '$message',
        );
        return ExitCode.invalidArguments;
      }
      final targetWorktree = await _resolveTargetWorktree(
        worktreeName,
        worktrees,
      );

      if (targetWorktree == null) {
        if (worktreeName != null) {
          printSafe('Error: Worktree "$worktreeName" does not exist.');
        }
        return ExitCode.generalError;
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
