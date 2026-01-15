# GWM Implementation Plan

## Overview

This document outlines the incremental implementation plan for GWM (Git Worktree Manager). Each increment delivers an
end-to-end feature or addresses a critical technical constraint, with clear acceptance criteria.

## Implementation Philosophy

- **Each increment is demonstrable**: Every step produces a working feature that can be tested
- **Test-driven**: All code is accompanied by comprehensive tests using test doubles
- **Incremental value**: Each increment provides user value, not just technical foundation
- **No external tool invocation in tests**: All tests use mocks/fakes for Git, file system, and processes

---

## Increment 1: Project Foundation & Core Models

### Description

Establish the project structure, domain models, and exception hierarchy. This creates the foundation for all subsequent
features.

### Deliverables

- Complete directory structure as specified in ARCHITECTURE.md
- Domain models: `Worktree`, `Config`, `Hook`, `ExitCodes`
- Exception hierarchy: `GwmException` and all subclasses
- Basic library entry point

### Files Created

```
lib/src/models/worktree.dart
lib/src/models/config.dart
lib/src/models/hook.dart
lib/src/models/exit_codes.dart
lib/src/exceptions.dart
lib/gwm.dart
```

### Acceptance Criteria

1. [ ] All models compile without errors
2. [ ] `dart analyze` passes with zero issues
3. [ ] Exit codes match PRD specification (0, 1, 2, 3, 4, 5, 6, 7)
4. [ ] All exceptions include `exitCode` and `message` properties
5. [ ] `Worktree` model includes: name, branch, path, isMain, status, lastModified
6. [ ] `Config` model includes: version, copy, hooks, shellIntegration
7. [ ] `Hook` model supports both array format and object format with timeout
8. [ ] Configuration override mechanism models supported (_prepend, _append)

### Test Coverage

- [ ] Unit tests for all model constructors and properties
- [ ] Unit tests for exception classes
- [ ] 100% coverage for models and exceptions

---

## Increment 2: Infrastructure Interfaces & Test Doubles

### Description

Create the infrastructure layer interfaces and implement test doubles. This addresses the critical technical constraint
of testability without external tool invocation.

### Deliverables

- Interfaces for: `ProcessWrapper`, `FileSystemAdapter`, `GitClient`
- Platform detection utilities
- Path utilities
- Test double implementations for all interfaces

### Files Created

```
lib/src/infrastructure/process_wrapper.dart
lib/src/infrastructure/file_system_adapter.dart
lib/src/infrastructure/git_client.dart
lib/src/infrastructure/platform_detector.dart
lib/src/utils/path_utils.dart
test/mock_objects/fake_process_wrapper.dart
test/mock_objects/fake_file_system_adapter.dart
test/mock_objects/mock_git_client.dart
```

### Acceptance Criteria

1. [ ] `ProcessWrapper` interface supports `run()` and `runStreamed()` with timeout
2. [ ] `FileSystemAdapter` interface supports file/directory operations with glob matching
3. [ ] `GitClient` interface declares all Git operations from PRD
4. [ ] `PlatformDetector` correctly identifies Windows, macOS, Linux
5. [ ] `PathUtils` handles platform-appropriate path separators
6. [ ] `FakeProcessWrapper` can be configured with canned responses
7. [ ] `FakeFileSystemAdapter` can simulate file operations
8. [ ] `MockGitClient` (using mockito) can verify method calls
9. [ ] All test doubles throw descriptive errors when unexpected calls are made

### Test Coverage

- [ ] Unit tests for platform detection on all supported platforms
- [ ] Unit tests for path utilities
- [ ] Unit tests for test double behavior (response matching, error cases)
- [ ] 95%+ coverage for infrastructure interfaces and utils

---

## Increment 3: Configuration System

### Description

Implement the complete configuration loading system with 3-tier hierarchy and override strategies. This is foundational
for all commands.

### Deliverables

- `ConfigService` for loading and merging configurations
- Support for JSON and YAML formats
- Configuration validation
- Per-hook timeout support

### Files Created

```
lib/src/services/config_service.dart
lib/src/utils/validation.dart
test/unit/services/config_service_test.dart
```

### Acceptance Criteria

1. [ ] Loads global config from `~/.config/gwm/config.{json,yaml}`
2. [ ] Loads repo config from `.gwm.{json,yaml}` in repository root
3. [ ] Loads local config from `.gwm.local.{json,yaml}` in repository root
4. [ ] Merges configs with correct priority: local > repo > global
5. [ ] Implements complete override: local field replaces repo field
6. [ ] Implements prepend: `post_add_prepend` adds commands before repo list
7. [ ] Implements append: `post_add_append` adds commands after repo list
8. [ ] Supports both array and object format for hooks with per-hook timeout
9. [ ] Validates configuration (version, timeout range, safe glob patterns)
10. [ ] Returns `Config` object with all fields populated
11. [ ] Returns appropriate `ConfigException` on errors with exit code 6

### Test Coverage

- [ ] Tests loading global config only
- [ ] Tests merging global + repo config
- [ ] Tests merging global + repo + local config
- [ ] Tests complete override (local replaces repo)
- [ ] Tests prepend and append override strategies
- [ ] Tests per-hook timeout override
- [ ] Tests both JSON and YAML formats
- [ ] Tests missing config files (returns defaults)
- [ ] Tests invalid JSON/YAML with clear error messages
- [ ] Tests configuration validation errors
- [ ] 95%+ coverage for ConfigService

---

## Increment 4: CLI Framework & Command Routing

### Description

Implement the CLI argument parsing framework and command routing system. This provides the user interface foundation.

### Deliverables

- `ArgParser` setup for all commands
- Command routing in main entry point
- Help command implementation
- Version command implementation
- Base command class

### Files Created

```
bin/gwm.dart
lib/src/commands/base.dart
lib/src/commands/help.dart
lib/src/commands/version.dart
test/unit/commands/help_test.dart
test/unit/commands/version_test.dart
```

### Acceptance Criteria

1. [ ] `gwm --help` displays help message for all commands
2. [ ] `gwm --version` displays version information
3. [ ] `gwm add --help` shows help for add command with all options
4. [ ] `gwm switch --help` shows help for switch command
5. [ ] `gwm delete --help` shows help for delete command with force flag
6. [ ] `gwm list --help` shows help for list command with verbose/json flags
7. [ ] Invalid commands display error message and exit with code 2
8. [ ] Missing required arguments display error and exit with code 2
9. [ ] Command parser matches PRD specification exactly

### Test Coverage

- [ ] Tests for argument parsing for all commands
- [ ] Tests for invalid arguments
- [ ] Tests for missing required arguments
- [ ] Tests for help and version commands
- [ ] 90%+ coverage for command routing

---

## Increment 5: Git Client Implementation

### Description

Implement the real GitClient wrapper and all Git operations. This provides the core Git integration.

### Deliverables

- `GitClient` implementation using `ProcessWrapper`
- All Git operations: branch creation, worktree operations, status checking
- Proper error handling with exit code 7
- Git command output display to user

### Files Created

```
lib/src/infrastructure/git_client_impl.dart
test/unit/infrastructure/git_client_test.dart
```

### Acceptance Criteria

1. [ ] `createBranch(name)` creates new Git branch
2. [ ] `createWorktree(path, branch)` creates worktree directory
3. [ ] `listWorktrees()` returns list of all worktrees including main repo
4. [ ] `removeWorktree(path)` removes worktree via Git
5. [ ] `getCurrentBranch()` returns current branch name
6. [ ] `branchExists(branch)` checks if branch exists locally
7. [ ] `hasUncommittedChanges()` detects modified files
8. [ ] All commands return exit code 7 on Git failure
9. [ ] All Git command output (stdout + stderr) is displayed to user
10. [ ] Error messages include the specific Git command that failed

### Test Coverage

- [ ] Tests for each Git operation with fake ProcessWrapper
- [ ] Tests for Git command failures (exit code 7)
- [ ] Tests for malformed Git output
- [ ] Tests verify correct Git command arguments
- [ ] Tests verify Git output is captured and displayed
- [ ] 90%+ coverage for GitClient

---

## Increment 6: List Command (First End-to-End Feature)

### Description

Implement the list command as the first fully functional command. This provides immediate user value and validates the
entire stack.

### Deliverables

- `ListCommand` implementation
- Output formatters for table and JSON
- Integration with ConfigService and GitClient
- Main workspace (".") included in output

### Files Created

```
lib/src/commands/list.dart
lib/src/utils/output_formatter.dart
test/unit/commands/list_test.dart
test/integration/list_command_test.dart
```

### Acceptance Criteria

1. [ ] `gwm list` displays table with worktree, branch, path columns
2. [ ] `gwm list -v` displays table with status and last modified
3. [ ] `gwm list -j` outputs JSON format
4. [ ] Main workspace always included as "."
5. [ ] Current worktree marked with "*" in table output
6. [ ] Lists only worktrees for current repository
7. [ ] JSON output matches schema with current flag
8. [ ] Verbose mode shows branch status (clean, modified, ahead, detached)
9. [ ] Handles repositories with no worktrees (only shows main)
10. [ ] Handles errors gracefully (exit code 1 or 6 or 7)

### Test Coverage

- [ ] Unit tests for list command with mocked services
- [ ] Integration test with all fake dependencies
- [ ] Tests for table output formatting
- [ ] Tests for JSON output formatting
- [ ] Tests for verbose mode
- [ ] Tests for current worktree marker
- [ ] Tests for empty worktree list
- [ ] 90%+ coverage for ListCommand

---

## Increment 7: Add Command (Basic)

### Description

Implement the add command for creating worktrees from existing branches, without hooks or file copying. This provides
core worktree creation functionality.

### Deliverables

- `AddCommand` implementation
- `WorktreeService` for worktree operations
- Path resolution for worktree directory
- Basic validation (branch exists, worktree doesn't exist)

### Files Created

```
lib/src/commands/add.dart
lib/src/services/worktree_service.dart
test/unit/services/worktree_service_test.dart
test/unit/commands/add_test.dart
test/integration/add_command_test.dart
```

### Acceptance Criteria

1. [ ] `gwm add feature/auth` creates worktree from existing branch
2. [ ] `gwm add -b feature/auth` creates new branch then worktree
3. [ ] Creates worktree in `<parent-dir>/worktrees/<repo-name>_<branch-name>/`
4. [ ] Fails with exit code 3 if worktree already exists
5. [ ] Fails with exit code 4 if branch doesn't exist (without -b flag)
6. [ ] Fails with exit code 7 if Git command fails
7. [ ] Creates worktree directory successfully
8. [ ] Validates that worktree was created
9. [ ] Runs from main Git repository only
10. [ ] Never creates worktree inside Git workspace directory

### Test Coverage

- [ ] Unit tests for WorktreeService with all fake dependencies
- [ ] Unit tests for AddCommand with mocked services
- [ ] Integration test for successful add with existing branch
- [ ] Integration test for add with -b flag (new branch)
- [ ] Tests for error cases (branch not found, worktree exists)
- [ ] Tests for Git command failures
- [ ] Tests verify worktree path calculation
- [ ] 90%+ coverage for AddCommand and WorktreeService

---

## Increment 8: Switch Command

### Description

Implement the switch command for navigating between worktrees. This enables the core workflow of switching between
parallel development sessions.

### Deliverables

- `SwitchCommand` implementation
- Interactive selection using simple Dart selector
- Shell integration for eval output
- Support for "." to switch to main workspace

### Files Created

```
lib/src/commands/switch.dart
lib/src/infrastructure/prompt_selector.dart
lib/src/services/shell_integration.dart
test/unit/commands/switch_test.dart
test/unit/infrastructure/prompt_selector_test.dart
test/unit/services/shell_integration_test.dart
test/integration/switch_command_test.dart
```

### Acceptance Criteria

1. [ ] `gwm switch feature-auth` switches to specific worktree
2. [ ] `gwm switch .` switches to main Git workspace
3. [ ] `gwm switch` shows interactive selection menu
4. [ ] Interactive menu includes main workspace as "."
5. [ ] Fails with exit code 3 if worktree doesn't exist
6. [ ] Only works from main repo or existing worktree
7. [ ] Outputs eval command for directory switching: `cd <path>`
8. [ ] Output can be wrapped by shell function for automatic CD
9. [ ] Handles selection cancellation gracefully
10. [ ] Validates worktree exists before switching

### Test Coverage

- [ ] Unit tests for SwitchCommand with mocked services
- [ ] Unit tests for interactive selector
- [ ] Unit tests for shell integration output
- [ ] Integration test for direct worktree switch
- [ ] Integration test for switch to main workspace
- [ ] Integration test for interactive selection
- [ ] Tests for error cases (worktree not found)
- [ ] Tests verify eval output format
- [ ] 90%+ coverage for SwitchCommand

---

## Increment 9: Delete Command

### Description

Implement the delete command for deleting worktrees and returning to main repository. This completes the core worktree
lifecycle.

### Deliverables

- `DeleteCommand` implementation
- Confirmation prompts for uncommitted changes
- Force flag to bypass safety checks
- Hook execution placeholders (pre_delete, post_delete)

### Files Created

```
lib/src/commands/delete.dart
test/unit/commands/delete_test.dart
test/integration/delete_command_test.dart
```

### Acceptance Criteria

1. [ ] `gwm delete` deletes current worktree and returns to main repo
2. [ ] Prompts for confirmation if uncommitted changes exist
3. [ ] `gwm delete --force` deletes without prompts
4. [ ] Fails with exit code 2 if run from main workspace (not a worktree)
5. [ ] Uses Git to remove worktree (proper delete)
6. [ ] Returns to main repository directory after deletion
7. [ ] Executes pre_delete hooks (placeholder for now)
8. [ ] Executes post_delete hooks (placeholder for now)
9. [ ] Validates current directory is a worktree before proceeding
10. [ ] Handles worktree removal failures with exit code 7

### Test Coverage

- [ ] Unit tests for DeleteCommand with mocked services
- [ ] Integration test for successful delete
- [ ] Integration test for delete with uncommitted changes (prompt)
- [ ] Integration test for force delete (no prompts)
- [ ] Tests for error case (running from main workspace)
- [ ] Tests for Git removal failures
- [ ] Tests verify return to main repo
- [ ] 90%+ coverage for DeleteCommand

---

## Increment 10: Copy Service

### Description

Implement the file/directory copying service with Copy-on-Write optimization. This enables sharing local files across
worktrees.

### Deliverables

- `CopyService` implementation
- Copy-on-Write detection for macOS APFS and Linux Btrfs/XFS
- Glob pattern matching for files and directories
- Integration with AddCommand

### Files Created

```
lib/src/services/copy_service.dart
test/unit/services/copy_service_test.dart
test/integration/copy_service_test.dart
```

### Acceptance Criteria

1. [ ] Copies files matching glob patterns from config
2. [ ] Copies directories recursively from config
3. [ ] Attempts CoW (clone) on macOS APFS filesystem
4. [ ] Attempts reflink on Linux Btrfs/XFS filesystem
5. [ ] Falls back to standard copy if CoW unavailable
6. [ ] Preserves directory structure when copying
7. [ ] Handles missing source files gracefully (warning only)
8. [ ] Supports glob patterns: `*.env`, `**/*.json`, `config/*`
9. [ ] Integrates with AddCommand (copies files after worktree creation)
10. [ ] Reports copy errors but doesn't fail the entire operation

### Test Coverage

- [ ] Unit tests for CopyService with fake file system
- [ ] Tests for glob pattern matching
- [ ] Tests for file copying
- [ ] Tests for directory copying
- [ ] Tests for CoW detection logic
- [ ] Tests for fallback to standard copy
- [ ] Integration test with AddCommand
- [ ] Tests for missing source files
- [ ] 95%+ coverage for CopyService

---

## Increment 11: Hook Service

### Description

Implement the hook execution system with timeout, error handling, and environment variable expansion. This enables
automation and custom workflows.

### Deliverables

- `HookService` implementation
- Environment variable expansion ($GWM_WORKTREE_PATH, $GWM_ORIGIN_PATH, $GWM_BRANCH)
- Timeout handling with configurable global and per-hook timeouts
- Sequential execution with immediate failure on error
- Integration with all commands

### Files Created

```
lib/src/services/hook_service.dart
test/unit/services/hook_service_test.dart
test/integration/hook_service_test.dart
```

### Acceptance Criteria

1. [ ] Executes hooks sequentially in order
2. [ ] Expands environment variables in hook commands
3. [ ] Sets GWM_WORKTREE_PATH, GWM_ORIGIN_PATH, GWM_BRANCH for hooks
4. [ ] Displays all hook output (stdout + stderr) to user
5. [ ] Fails immediately on first hook failure (exit code 5)
6. [ ] Displays error output from failed hook command
7. [ ] Implements global timeout (default 30 seconds)
8. [ ] Implements per-hook timeout override
9. [ ] Terminates hook execution on timeout
10. [ ] Hooks configured in merged config (global + repo + local)

### Test Coverage

- [ ] Unit tests for HookService with fake ProcessWrapper
- [ ] Tests for sequential execution
- [ ] Tests for environment variable expansion
- [ ] Tests for timeout handling
- [ ] Tests for hook failure propagation
- [ ] Tests for per-hook timeout vs global timeout
- [ ] Integration tests with AddCommand
- [ ] Integration tests with SwitchCommand
- [ ] Integration tests with DeleteCommand
- [ ] 95%+ coverage for HookService

---

## Increment 12: Shell Integration Enhancement

### Description

Enhance shell integration with eval-output for all commands and fzf support for interactive selection. This provides
seamless directory switching.

### Deliverables

- Enhanced shell integration for all commands
- fzf detection and integration for interactive selection
- Shell wrapper documentation
- Tab completion support (bash, zsh, fish)

### Files Created/Modified

```
lib/src/services/shell_integration.dart (enhanced)
lib/src/infrastructure/prompt_selector.dart (enhanced with fzf)
docs/INSTALLATION.md (shell wrapper instructions)
docs/completion/gwm.bash
docs/completion/gwm.zsh
docs/completion/gwm.fish
test/unit/services/shell_integration_test.dart (enhanced)
```

### Acceptance Criteria

1. [ ] All commands output eval commands where appropriate
2. [ ] Shell wrapper functions provided for bash, zsh, fish, PowerShell, nushell
3. [ ] fzf detected automatically if available
4. [ ] Interactive selection uses fzf when available, falls back to Dart selector
5. [ ] Tab completion for worktree names in list/switch commands
6. [ ] Tab completion for branch names in add command
7. [ ] Tab completion includes "." for main workspace
8. [ ] Installation instructions for shell wrappers documented
9. [ ] Graceful degradation if fzf not installed
10. [ ] Shell integration can be disabled via config

### Test Coverage

- [ ] Tests for fzf detection
- [ ] Tests for fzf integration
- [ ] Tests for fallback selector
- [ ] Tests for shell integration output format
- [ ] Tests for tab completion scripts (manual verification)
- [ ] 90%+ coverage for enhanced shell integration

---

## Increment 13: Complete Feature Integration

### Description

Integrate all services together and ensure complete feature parity with PRD. This delivers the fully functional GWM
tool.

### Deliverables

- Full integration of all commands with all services
- Configuration override mechanism fully implemented
- All error paths tested and validated
- Performance optimizations verified
- Cross-platform testing completed

### Files Modified

```
lib/src/commands/add.dart (full integration)
lib/src/commands/switch.dart (full integration)
lib/src/commands/delete.dart (full integration)
lib/src/commands/list.dart (final polish)
test/integration/ (comprehensive integration tests)
```

### Acceptance Criteria

1. [ ] `gwm add` supports: existing branches, new branches (-b), hooks, file copying
2. [ ] `gwm switch` supports: direct switch, interactive selection, hooks, shell integration
3. [ ] `gwm delete` supports: normal mode, force mode, hooks, uncommitted changes detection
4. [ ] `gwm list` supports: simple, verbose, JSON output, current worktree marker
5. [ ] Configuration hierarchy works correctly (global + repo + local with override strategies)
6. [ ] All hooks execute in correct order (pre/post for add/switch/delete)
7. [ ] All exit codes match PRD specification
8. [ ] All error messages are clear and actionable
9. [ ] File copying works with glob patterns and CoW optimization
10. [ ] Shell integration enables automatic directory switching
11. [ ] fzf integration works for interactive selection
12. [ ] Tool works on Windows, Linux, macOS with consistent behavior
13. [ ] Performance targets met (< 2s add, < 500ms switch, < 100ms list)

### Test Coverage

- [ ] Comprehensive integration tests for all commands
- [ ] Integration tests for all error scenarios
- [ ] Integration tests for configuration merging
- [ ] Integration tests for hook execution
- [ ] Integration tests for file copying
- [ ] Integration tests for shell integration
- [ ] Cross-platform tests (mocked for Windows, Linux, macOS)
- [ ] Overall code coverage 90%+

---

## Increment 14: Documentation & Polish

### Description

Complete all documentation and polish the user experience. This ensures the tool is production-ready.

### Deliverables

- Complete README with installation and usage instructions
- Comprehensive troubleshooting guide
- Shell integration installation guide
- Tab completion installation guide
- Example configuration files
- CHANGELOG.md
- Contributing guidelines

### Files Created

```
README.md
CHANGELOG.md
CONTRIBUTING.md
docs/INSTALLATION.md
docs/TROUBLESHOOTING.md
docs/SHELL_INTEGRATION.md
docs/EXAMPLES.md
examples/basic/.gwm.json
examples/advanced/.gwm.json
examples/advanced/.gwm.local.json
examples/minimal/.gwm.json
```

### Acceptance Criteria

1. [ ] README includes: project description, features, installation, quick start
2. [ ] Installation guide covers: Dart SDK, shell wrappers, tab completion
3. [ ] Usage examples for all commands
4. [ ] Troubleshooting guide covers common issues
5. [ ] Shell integration guide for all supported shells
6. [ ] Example configurations demonstrate all features
7. [ ] CHANGELOG documents all changes
8. [ ] Contributing guidelines for developers
9. [ ] All PRD requirements documented in user-facing docs
10. [ ] Documentation is clear, accurate, and up-to-date

---

## Increment 15: Final Quality Assurance

### Description

Perform final quality assurance, performance testing, and cross-platform validation. This ensures the tool is ready for
production release.

### Deliverables

- Performance benchmarks
- Cross-platform testing results
- Security audit validation
- End-to-end user acceptance testing
- Release preparation

### Acceptance Criteria

1. [ ] All tests pass (dart test)
2. [ ] Code analysis passes (dart analyze)
3. [ ] Code formatted (dart format .)
4. [ ] Performance targets verified:
    - Worktree creation: < 2 seconds (excluding dependency installation)
    - Worktree switching: < 500ms
    - Worktree listing: < 100ms for up to 100 worktrees
5. [ ] Cross-platform testing completed on Windows, Linux, macOS
6. [ ] Security audit: command injection prevention, path validation, config validation
7. [ ] User acceptance testing completed
8. [ ] All PRD requirements met
9. [ ] All ARCHITECTURE principles followed
10. [ ] Ready for v1.0.0 release

---

## Development Workflow

### Starting Each Increment

1. Create a feature branch: `git checkout -b increment/<number>-<short-name>`
2. Read the increment description and acceptance criteria
3. Implement the increment following TDD: write tests first, then implement
4. Run `dart analyze` and `dart format .` before committing
5. Ensure all tests pass: `dart test`
6. Commit with descriptive message following project conventions

### Completing Each Increment

1. Run full test suite: `dart test --coverage=coverage`
2. Verify coverage meets targets (90%+ overall, higher for critical components)
3. Run manual testing on your machine if applicable
4. Create pull request with increment description
5. Include test coverage report
6. Reference this implementation plan

### Testing Guidelines

- **Never invoke external tools in tests** - always use test doubles
- Test both success and error paths
- Test edge cases (empty lists, missing files, invalid input)
- Verify exit codes match PRD specification
- Verify error messages are clear and actionable

### Code Quality Gates

Each increment must pass:

1. `dart format .` - code formatting
2. `dart analyze` - static analysis
3. `dart test` - all tests pass
4. Coverage requirements for the increment

---

## Timeline Estimation

| Increment                    | Estimated Effort | Dependencies        |
|------------------------------|------------------|---------------------|
| 1: Project Foundation        | 2 hours          | None                |
| 2: Infrastructure Interfaces | 4 hours          | 1                   |
| 3: Configuration System      | 6 hours          | 1, 2                |
| 4: CLI Framework             | 3 hours          | 1                   |
| 5: Git Client                | 4 hours          | 2                   |
| 6: List Command              | 4 hours          | 3, 5                |
| 7: Add Command (Basic)       | 6 hours          | 3, 5, 6             |
| 8: Switch Command            | 5 hours          | 3, 5, 6             |
| 9: Delete Command            | 4 hours          | 3, 5                |
| 10: Copy Service             | 5 hours          | 2, 3                |
| 11: Hook Service             | 6 hours          | 2, 3                |
| 12: Shell Integration        | 4 hours          | 8, 11               |
| 13: Full Integration         | 8 hours          | 7, 8, 9, 10, 11, 12 |
| 14: Documentation            | 4 hours          | All previous        |
| 15: Final QA                 | 4 hours          | All previous        |
| **Total**                    | **~69 hours**    |                     |

---

## Success Metrics

By the end of Increment 15, the following metrics should be achieved:

- **Code Coverage**: 90%+ overall, 95%+ for services, 100% for models
- **Performance**: All PRD performance targets met
- **Test Execution Time**: < 5 seconds for full test suite
- **Cross-Platform**: Verified on Windows, Linux, macOS
- **Documentation**: Complete and accurate
- **User Experience**: Intuitive, clear error messages, helpful prompts
- **PRD Compliance**: 100% of PRD requirements implemented
- **Architecture Compliance**: 100% of ARCHITECTURE principles followed

---

## Notes

- Increments can be adjusted based on actual development progress
- Each increment should be completed and tested before moving to the next
- Revisit this plan regularly and update based on lessons learned
- Prioritize test coverage and code quality over speed
- The plan is flexible - if an increment reveals technical debt, adjust accordingly

---

**Document Version**: 1.0
**Last Updated**: 2026-01-11
**Status**: Ready for Implementation