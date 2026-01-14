# GWM - Git Worktree Manager PRD

## 1. Overview

GWT (Git Worktree Manager) is a command-line tool that simplifies the management of Git worktrees, enabling parallel
development sessions on the same Git repository. It is designed to support both manual worktree workflows and
AI-assisted development scenarios where multiple tool instances work in parallel on different features.

### 1.1 Problem Statement

Git worktrees allow developers to work on multiple branches simultaneously, but native `git worktree` commands are
verbose and require manual directory management. Managing multiple worktrees, especially for AI coding workflows,
becomes cumbersome without proper tooling.

### 1.2 Solution

GWT provides a streamlined interface for:

- Creating and managing worktrees with automatic directory navigation
- Switching between worktrees seamlessly
- Configurable hooks for automation (CI/CD, dependency installation, etc.)
- File/directory copying to ensure local files are available across worktrees
- Cross-platform support for Windows, Linux, and macOS

## 2. Target Users

- **Software Developers**: Working on multiple features simultaneously
- **AI-Assisted Development**: Multiple AI coding agents working in parallel on different branches
- **Code Reviewers**: Reviewing PRs while maintaining active development work
- **DevOps Engineers**: Managing parallel CI/CD environments

## 3. Core Features

### 3.1 Worktree Management

#### 3.1.1 Add Worktree

Create a new worktree with automatic directory navigation.

**Usage**: `gwm add <branch-name> [options]`

**Behavior**:

- Creates worktree in `<parent-dir>/worktrees/<repo-name>_<branch-name>/`
  - If workspace is `~/work/project`, worktree is created in `~/work/worktrees/project_feature-new-ui/`
  - The `worktrees` directory is shared across all Git repositories in the same parent directory
- Uses existing branch by default
- With `-b` flag: Creates a new Git branch with the specified name before creating the worktree
- Fails if branch doesn't exist (unless `-b` flag is used to create it)
- Fails if worktree already exists
- Copies configured files/directories from main repo
- Executes `pre_add` and `post_add` hooks
- Automatically switches to the new worktree directory
- Never creates worktrees inside a Git workspace directory

**Options**:

- `-b, --branch`: Create new branch instead of using existing
- `-h, --help`: Show help message

**Examples**:

```bash
# Create worktree from existing branch
gwm add feature/new-ui
# Uses existing "feature/new-ui" branch (fails if branch doesn't exist)

# Create worktree with new branch
gwm add -b feature/authentication
# Creates new "feature/authentication" Git branch and worktree

# Error case: worktree already exists
gwm add feature/new-ui
# Error: Worktree 'myrepo_feature_new-ui' already exists
```

#### 3.1.2 Switch Worktree

Navigate to an existing worktree with interactive selection.

**Usage**: `gwm switch [worktree-name]`

**Behavior**:

- If `worktree-name` is provided: Switch to exact match (use "." to switch to main Git workspace)
- If no `worktree-name`: Show interactive selection list (includes main Git workspace as ".")
- Executes `pre_switch` and `post_switch` hooks
- Fails if worktree doesn't exist
- Must be run from the main repository or an existing worktree

**Examples**:

```bash
# Switch to specific worktree
gwm switch feature-auth

# Switch to main Git workspace
gwm switch .

# Interactive selection
gwm switch
# Select worktree:
# 1. . (~/work/project) - main workspace
# 2. feature-auth (~/work/worktrees/project_feature-auth)
# 3. bugfix-login (~/work/worktrees/project_bugfix-login)
# 4. api-v2 (~/work/worktrees/project_api-v2)
```

#### 3.1.3 Clean Worktree

Delete current worktree and return to main repository.

**Usage**: `gwm clean [options]`

**Behavior**:

- Removes the current worktree directory
- Can only be run from within a worktree (fails if run from main Git workspace ".")
- Executes `pre_clean` and `post_clean` hooks
- Returns to main repository directory
- Checks for uncommitted changes and prompts for confirmation
- `--force` bypasses prompts and deletes regardless of uncommitted changes

**Options**:

- `-f, --force`: Bypass safety checks and delete immediately
- `-h, --help`: Show help message

**Examples**:

```bash
# Normal clean (prompts if uncommitted changes exist)
gwm clean
# Uncommitted changes detected in 'feature-auth'
# Continue? (y/N) y
# Worktree removed successfully

# Force clean (no prompts)
gwm clean --force
```

#### 3.1.4 List Worktrees

Display all available worktrees for the current repository.

**Usage**: `gwm list [options]`

**Behavior**:

- Lists all worktrees in `<parent-dir>/worktrees/` directory for the current repository
- Always includes the main Git workspace (displayed as ".")
- Shows branch name and path
- Indicates current worktree with `*` marker
- Can show additional details with flags

**Options**:

- `-v, --verbose`: Show additional information (branch status, last modified)
- `-j, --json`: Output in JSON format for scripting
- `-h, --help`: Show help message

**Examples**:

```bash
# Simple list
gwm list
# WORKTREE              BRANCH           PATH
# * .                   main             ~/work/project
#   feature-auth        feature/auth     ~/work/worktrees/project_feature-auth
#   bugfix-login        bugfix/login     ~/work/worktrees/project_bugfix-login
#   api-v2              api-v2           ~/work/worktrees/project_api-v2

# Detailed list
gwm list -v
# WORKTREE              BRANCH           STATUS          LAST MODIFIED
# * .                   main             Modified        10 minutes ago
#   feature-auth        feature/auth     Modified        5 minutes ago
#   bugfix-login        bugfix/login     Clean           2 hours ago
#   api-v2              api-v2           Ahead (3)       1 day ago

# JSON output
gwm list -j
{"worktrees":[{"name":".","branch":"main","path":"~/work/project","status":"modified","current":true},{"name":"feature-auth","branch":"feature/auth","path":"~/work/worktrees/project_feature-auth","status":"modified","current":false}]}
```

### 3.2 Configuration System

#### 3.2.1 Configuration Files

**Global Configuration**: `~/.config/gwt/config.json` (or `.yaml`)

- Applies to all repositories
- Contains default settings and shared hooks

**Per-Repository Configuration**: `.gwt.json` (or `.yaml`) in repository root

- Repository-specific overrides
- Extends global configuration
- Can be committed to Git and shared with the team
- Used for team-wide settings and shared development workflows

**Per-Repository Local Configuration**: `.gwt.local.json` (or `.yaml`) in repository root

- Optional local-only overrides that are not committed to Git
- Should be added to `.gitignore`
- Highest priority in the configuration hierarchy
- Used for developer-specific settings and personal customization

**Configuration Override Mechanism**:

Local configuration can override, prepend to, or append to settings from the per-repository configuration:

```json
// .gwt.json (shared, committed to Git)
{
  "version": "1.0",
  "copy": {
    "files": [".env", "*.env.*"],
    "directories": ["node_modules"]
  },
  "hooks": {
    "post_add": ["npm install", "npm run build"],
    "post_switch": ["npm run dev"]
  }
}

// .gwt.local.json (local-only, gitignored)
{
  "copy": {
    "files": [".env.local", ".secrets"]  // Additional files to copy
  },
  "hooks": {
    "post_add_prepend": ["echo 'Local setup starting'"],  // Run before shared hooks
    "post_add_append": ["npm run dev"]  // Run after shared hooks
  }
}

// Result when using .gwt.local.json:
// copy.files = [".env", "*.env.*", ".env.local", ".secrets"]  // Merged
// hooks.post_add = [
//   "echo 'Local setup starting'",
//   "npm install",
//   "npm run build",
//   "npm run dev"
// ]  // Prepended and appended
```

**Override Strategies**:

- **Complete Override**: Use the field name directly (e.g., `post_add = [...]`) to replace the entire value
- **Prepend Items**: Use `_prepend` suffix (e.g., `post_add_prepend = [...]`) to add items before the shared list
- **Append Items**: Use `_append` suffix (e.g., `post_add_append = [...]`) to add items after the shared list

**Configuration Hierarchy** (highest to lowest priority):

1. Per-repository local (`.gwt.local.json`) - with override strategies
2. Per-repository (`.gwt.json`)
3. Global (`~/.config/gwt/config.json`)

#### 3.2.2 Configuration Schema

**Global Configuration** (`~/.config/gwt/config.json`):

```json
{
  "version": "1.0",
  "hooks": {
    "timeout": 30
  }
}
```

**Per-Repository Configuration** (`.gwt.json` - shared, committed to Git):

```json
{
  "version": "1.0",
  "copy": {
    "files": [
      ".env",
      "*.env.*",
      "config/*.json"
    ],
    "directories": [
      "node_modules",
      ".cache",
      "build/*"
    ]
  },
  "hooks": {
    "pre_add": [
      "echo 'Creating worktree...'"
    ],
    "post_add": [
      "npm install",
      "npm run build"
    ],
    "pre_switch": [
      "echo 'Switching to $GWT_WORKTREE_PATH'"
    ],
    "post_switch": [
      "npm run dev"
    ],
    "pre_clean": [
      "git stash"
    ],
    "post_clean": [
      "echo 'Cleanup complete'"
    ]
  },
  "shell_integration": {
    "enable_eval_output": true
  }
}
```

**Per-Repository Local Configuration** (`.gwt.local.json` - local-only, gitignored):

**Per-Repository Local Configuration** (`.gwt.local.json` - local-only, gitignored):

```json
{
  "version": "1.0",
  "copy": {
    "files": [
      ".env.local",
      ".secrets"
    ]
  },
  "hooks": {
    "post_add_prepend": [
      "echo 'Local setup starting'"
    ],
    "post_add_append": [
      "npm run dev"
    ]
  }
}
```

**Merged Result** (what GWM actually uses):

```json
{
  "version": "1.0",
  "copy": {
    "files": [
      ".env",
      "*.env.*",
      "config/*.json",
      ".env.local",      // From .gwt.local.json (appended)
      ".secrets"         // From .gwt.local.json (appended)
    ],
    "directories": [
      "node_modules",
      ".cache",
      "build/*"
    ]
  },
  "hooks": {
    "pre_add": [
      "echo 'Creating worktree...'"
    ],
    "post_add": [
      "echo 'Local setup starting'",  // From .gwt.local.json (prepended)
      "npm install",
      "npm run build",
      "npm run dev"                    // From .gwt.local.json (appended)
    ],
    "pre_switch": [
      "echo 'Switching to $GWT_WORKTREE_PATH'"
    ],
    "post_switch": [
      "npm run dev"
    ],
    "pre_clean": [
      "git stash"
    ],
    "post_clean": [
      "echo 'Cleanup complete'"
    ]
  },
  "shell_integration": {
    "enable_eval_output": true
  }
}
```

**YAML Alternative**:

**Global Configuration** (`~/.config/gwt/config.yaml`):

```yaml
version: "1.0"
hooks:
  timeout: 30
```

**Per-Repository Configuration** (`.gwt.yaml` - shared, committed to Git):

```yaml
version: "1.0"
copy:
  files:
    - ".env"
    - "*.env.*"
    - "config/*.json"
  directories:
    - "node_modules"
    - ".cache"
    - "build/*"
hooks:
  pre_add:
    - "echo 'Creating worktree...'"
  post_add:
    - "npm install"
    - "npm run build"
  pre_switch:
    - "echo 'Switching to $GWT_WORKTREE_PATH'"
  post_switch:
    - "npm run dev"
  pre_clean:
    - "git stash"
  post_clean:
    - "echo 'Cleanup complete'"
shell_integration:
  enable_eval_output: true
```

**Per-Repository Local Configuration** (`.gwt.local.yaml` - local-only, gitignored):

```yaml
version: "1.0"
copy:
  files:
    - ".env.local"
    - ".secrets"
hooks:
  post_add_prepend:
    - "echo 'Local setup starting'"
  post_add_append:
    - "npm run dev"
```

### 3.3 File/Directory Copying

#### 3.3.1 Copy Configuration

The `copy` section in configuration specifies files and directories to copy from the main repository to each worktree.

**Files**:

- Supports glob patterns (`*.env`, `**/*.json`, `config/*.txt`)
- Preserves directory structure
- Copies recursively

**Directories**:

- Copies entire directories recursively
- Supports glob patterns for multiple directories
- Large directories (e.g., `node_modules`) may take time

#### 3.3.2 Copy Optimization

GWT automatically selects the best copy strategy based on the operating system and filesystem:

| Platform | Filesystem | Strategy                |
|----------|------------|-------------------------|
| macOS    | APFS       | Copy-on-Write (clone)   |
| Linux    | Btrfs/XFS  | Copy-on-Write (reflink) |
| All      | Other      | Standard copy           |
| Windows  | All        | Standard copy           |

**Copy-on-Write**: Only copies metadata, not actual data (near-instant for large directories).

**Fallback**: Automatically falls back to standard copy if CoW is unavailable.

### 3.4 Hook System

#### 3.4.1 Available Hooks

| Hook          | When Executed                          | Environment Variables                  |
|---------------|----------------------------------------|----------------------------------------|
| `pre_add`     | Before creating worktree               | `GWT_WORKTREE_PATH`, `GWT_ORIGIN_PATH` |
| `post_add`    | After creating worktree                | `GWT_WORKTREE_PATH`, `GWT_ORIGIN_PATH` |
| `pre_switch`  | Before switching worktree              | `GWT_WORKTREE_PATH`, `GWT_ORIGIN_PATH` |
| `post_switch` | After switching worktree               | `GWT_WORKTREE_PATH`, `GWT_ORIGIN_PATH` |
| `pre_clean`   | Before deleting worktree               | `GWT_WORKTREE_PATH`, `GWT_ORIGIN_PATH` |
| `post_clean`  | After deleting worktree (in main repo) | `GWT_ORIGIN_PATH`                      |

#### 3.4.2 Environment Variables

- `GWT_WORKTREE_PATH`: Absolute path to the target worktree
- `GWT_ORIGIN_PATH`: Absolute path to the main repository
- `GWT_BRANCH`: Branch name being worked with

#### 3.4.3 Hook Execution

- Hooks run as shell commands (sh/bash on Unix, cmd/PowerShell on Windows)
- Multiple hooks in an array execute sequentially
- **GWT fails immediately if any external command invoked from a hook returns a non-zero exit status**
- **Both standard output and error output from external commands are displayed to the user**
- Hook execution stops on first failure
- Failed hooks display error message and prevent the operation
- Hooks have a 30-second timeout by default (configurable in global settings)
- If a hook times out, it is terminated and marked as failed

**Error Handling Behavior**:

When an external command fails (non-zero exit status):
1. The command's error output is displayed
2. GWM stops the current operation (add, switch, or clean)
3. An error message is shown indicating which hook failed
4. GWM exits with a non-zero exit code (exit code 5 for hook failures)

**Hook Timeout Configuration**:

```json
{
  "version": "1.0",
  "hooks": {
    "timeout": 30,
    "post_add": [
      "npm install",
      "npm run build"
    ]
  }
}
```

**Per-Hook Timeout** (overrides global timeout):

```json
{
  "version": "1.0",
  "hooks": {
    "post_add": {
      "timeout": 120,
      "commands": [
        "npm install",
        "npm run build"
      ]
    }
  }
}
```

**Example Hook Usage**:

```json
{
  "hooks": {
    "post_add": [
      "npm install",
      "npm run db:migrate",
      "echo 'Setup complete for $GWT_BRANCH'"
    ]
  }
}
```

### 3.5 Shell Integration

#### 3.5.1 Automatic Directory Switching

GWT uses `eval` output to enable automatic directory switching across all supported shells.

**Implementation**:

- Commands output shell commands instead of executing directly
- Shell wrapper function captures output and evaluates it
- Works with bash, zsh, fish, PowerShell, and other shells

#### 3.5.2 Shell Wrapper Installation

**Bash** (`~/.bashrc`):

```bash
gwt() { eval "$(command gwm "$@")"; }
```

**Zsh** (`~/.zshrc`):

```bash
gwt() { eval "$(command gwm "$@")" }
```

**Fish** (`~/.config/fish/config.fish`):

```fish
function gwt
    eval (command gwm $argv)
end
```

**PowerShell** (`$PROFILE`):

```powershell
function gwm { Invoke-Expression (& gwm $args) }
```

**Nushell** (`~/.config/nushell/config.nu`):

```nu
def --env gwm [...args] {
    ^gwm ...$args | lines | each { |line| nu -c $line }
}
```

#### 3.5.3 Tab Completion

Auto-completion support for:

- Worktree names (list, switch commands) - includes "." for main workspace
- Branch names (add command)
- Configuration options (config command)

**Supported Shells**: bash, zsh, fish

## 4. Non-Functional Requirements

### 4.1 Cross-Platform Support

- **Windows**: Windows 10+ with PowerShell
- **Linux**: Ubuntu, Debian, Fedora, Arch, and other major distributions
- **macOS**: macOS 10.15+

### 4.2 Dependencies

- Git 2.5+ (for worktree support)
- Dart SDK (for running GWM)
- Optional: fzf (for enhanced interactive selection)

### 4.3 Performance

- Worktree creation: < 2 seconds (excluding dependency installation)
- Worktree switching: < 500ms
- Worktree listing: < 100ms for up to 100 worktrees
- File copying: Optimized with Copy-on-Write on supported filesystems

### 4.4 Error Handling

- Clear, actionable error messages
- **GWT fails immediately on any external command returning non-zero exit status**
  - This includes: Git commands, hook commands, and any other external tool invocations
- **All external command output (both stdout and stderr) is displayed to the user**
  - This ensures users can diagnose failures and see error messages from invoked tools
- Graceful degradation for optional features (e.g., fzf not installed)
- Proper exit codes for scripting (0 for success, non-zero for failure)
- Exit codes reflect the type of failure (see Section 10.2)

### 4.5 Security

- Configuration file validation
- Safe execution of hooks (no arbitrary code injection)
- Clear prompts for destructive operations (clean, remove)
- Support for `.gitignore`-like patterns for local config files
- `.gwt.local.json` should be added to `.gitignore` to prevent committing local-only settings to the repository

## 5. Technical Architecture

### 5.1 Technology Stack

- **Language**: Dart
- **External Dependencies**: Git CLI (required), fzf (optional)
- **Configuration Formats**: JSON (primary), YAML (alternative)
- **Shell Integration**: Eval-based wrapper functions

### 5.2 Directory Structure

```
~/work/
├── project/               # Main Git repository
│   ├── .gwt.json          # Repository-specific configuration (shared, committed)
│   ├── .gwt.local.json    # Local-only configuration (gitignored)
│   ├── .gitignore         # Should include .gwt.local.json
│   │                       # Recommended content: .gwt.local.*
│   └── ...                # Repository files
└── worktrees/             # Shared worktree directory for all repos in ~/work/
    ├── project_feature-auth/
    ├── project_bugfix-login/
    ├── project_api-v2/
    ├── otherrepo_feature-xyz/
    └── ...

~/.config/gwt/
└── config.json            # Global configuration
```

**Key Points**:
- The `worktrees` directory is created in the parent directory of the Git workspace
- Multiple Git repositories in the same parent directory share the same `worktrees` directory
- Worktree names are formatted as `<repo-name>_<branch-name>` to avoid conflicts
- Worktrees are never created inside Git workspace directories
- `.gwt.local.json` should be added to `.gitignore` to avoid committing local-only settings
- Recommended `.gitignore` entry: `.gwt.local.*` to ignore both JSON and YAML local configs

### 5.3 Git Command Integration

All Git operations use command-line invocations:

- `git worktree add`
- `git worktree list`
- `git worktree remove`
- `git branch`
- `git status`
- `git checkout`

This ensures full compatibility with Git and proper handling of all edge cases.

**Error Handling**:
- GWM fails immediately if any Git command returns a non-zero exit status
- All Git command output (both stdout and stderr) is displayed to the user
- Git errors are propagated with clear context to help users understand what went wrong
- GWM exits with exit code 7 for Git command failures

### 5.4 Cross-Platform Considerations

- **Path Separators**: Use platform-appropriate separators (`/` on Unix, `\` on Windows)
- **Shell Commands**: Detect and use appropriate shell for hooks
- **File System Operations**: Use Dart's `dart:io` for cross-platform compatibility
- **Home Directory**: Use platform-specific home directory resolution

## 6. User Workflows

### 6.1 Basic Workflow

```bash
# Start working on a new feature
gwm add -b feature/new-ui
# Creates new "feature/new-ui" Git branch and worktree,
# copies files, runs hooks, switches directory

# Work on feature...
# Directory is already switched by gwm add
# ... make changes ...

# Clean up when done
gwm clean
# Removes worktree, returns to main repo
```

### 6.2 Multi-Feature Workflow

```bash
# Create multiple worktrees
gwm add feature/auth
gwm add feature/api
gwm add bugfix/login

# Switch between worktrees
gwm switch feature-auth  # or interactive: gwm switch

# Switch back to main workspace
gwm switch .

# List all worktrees
gwm list -v

# Clean up completed features
gwm switch feature-auth
gwm clean
```

### 6.3 AI-Assisted Development Workflow

```bash
# Terminal 1: Work on authentication
gwm add feature/auth
# AI agent works in this worktree...

# Terminal 2: Work on API
gwm switch feature-api
# Different AI agent works here...

# Terminal 3: Work on bugfix
gwm switch bugfix-login
# Third AI agent works here...

# Terminal 4: Monitor or work on main branch
gwm switch .
# You're now in the main workspace

# Monitor all worktrees from any terminal
gwm list -v
```

### 6.4 Project Setup Workflow

```json
// .gwt.json (shared, committed to Git)
{
  "version": "1.0",
  "copy": {
    "files": [
      ".env",
      ".env.local"
    ],
    "directories": [
      "node_modules",
      ".next"
    ]
  },
  "hooks": {
    "post_add": [
      "npm install",
      "npm run build"
    ],
    "pre_clean": [
      "git stash"
    ],
    "post_switch": [
      "npm run dev"
    ]
  }
}
```

```json
// .gwt.local.json (local-only, gitignored)
{
  "version": "1.0",
  "hooks": {
    "post_add_prepend": [
      "echo 'Starting local setup...'"
    ],
    "post_add_append": [
      "npm run typecheck",
      "echo 'Local setup complete!'"
    ]
  }
}
```

```bash
# Create new worktree with automatic setup
gwm add feature/new-component
# Automatically:
# 1. Creates worktree in ~/work/worktrees/project_feature-new-component/
# 2. Copies .env and node_modules from main repo
# 3. Runs hooks in order:
#    - "echo 'Starting local setup...'" (from .gwt.local.json)
#    - "npm install" (from .gwt.json)
#    - "npm run build" (from .gwt.json)
#    - "npm run typecheck" (from .gwt.local.json)
#    - "echo 'Local setup complete!'" (from .gwt.local.json)
# 4. Switches to worktree directory

# If any hook command fails (e.g., npm install):
# GWM will:
# - Display the error output from npm
# - Stop the operation
# - Exit with code 5 (hook execution failed)
# - Leave the worktree in partial state
# Example error:
# ✗ Hook 'post_add' failed: Command 'npm install' exited with status 1
# npm ERR! missing script: install
```

## 7. Future Enhancements (Out of Scope for v1)

- Status dashboard with watch mode
- Remote worktree support
- Automatic worktree cleanup (prune old/inactive worktrees)
- Branch management (delete branch when removing worktree)
- Configuration validation and schema enforcement
- Hash verification for configuration files (security)
- Interactive branch selection for `gwm add`
- Configuration management commands (`gwm config get/set`)

## 8. Success Metrics

- **Adoption**: Easy to set up (single command installation)
- **Efficiency**: Reduces time to switch between worktrees by > 50%
- **Reliability**: < 1% error rate in normal operations
- **Satisfaction**: Clear error messages and helpful prompts
- **Compatibility**: Works across Windows, Linux, and macOS with consistent behavior

## 9. Design Decisions

The following decisions have been made for the implementation:

### 9.1 Interactive Selection
**Decision**: Use fzf (if available) or build a simple selector in Dart

- If fzf is installed on the system, use it for interactive worktree selection
- If fzf is not available, fall back to a simple Dart-based selector
- This provides the best user experience when possible while maintaining cross-platform compatibility

### 9.2 Hook Timeout
**Decision**: 30-second default timeout, configurable in settings

- Hooks have a default timeout of 30 seconds to prevent hanging
- Timeout is configurable via settings in the global configuration file
- Administrators can adjust the timeout based on their project needs
- Timeout configuration allows per-hook or global timeout settings

### 9.3 Configuration Migration
**Decision**: Include version field and auto-migrate when possible

- All configuration files include a `version` field
- When configuration format changes, GWM automatically migrates old configurations when possible
- Migration warnings are displayed for manual configuration updates
- Backward compatibility is maintained for at least one major version

### 9.4 Error Recovery
**Decision**: Leave partial state with clear error message

- If a hook fails during worktree creation, the worktree is left in partial state
- A clear error message is displayed indicating what failed and what cleanup is needed
- Users can manually clean up the partial state or fix the issue and retry
- This approach prevents accidental data loss while providing clear guidance for recovery

## 10. Appendix

### 10.1 Command Reference

| Command               | Description                                             |
|-----------------------|---------------------------------------------------------|
| `gwm add <branch>`    | Create worktree from existing branch                    |
| `gwm add -b <branch>` | Create new Git branch and worktree                      |
| `gwm switch [name]`   | Switch to worktree (use "." for main, interactive if no name) |
| `gwm clean [--force]` | Delete current worktree and return to main repo         |
| `gwm list [-v|-j]`    | List all worktrees (includes main workspace as ".")     |
| `gwm --help`          | Show help message                                       |
| `gwm --version`       | Show version information                                |

### 10.2 Exit Codes

| Code | Meaning                                   | Notes                                                                 |
|------|-------------------------------------------|-----------------------------------------------------------------------|
| 0    | Success                                   | Operation completed successfully                                     |
| 1    | General error                             | Unspecified error occurred                                           |
| 2    | Invalid usage (wrong arguments)           | Command-line arguments were invalid or missing                       |
| 3    | Worktree already exists                   | The requested worktree already exists                                |
| 4    | Branch not found                          | The specified Git branch does not exist                              |
| 5    | Hook execution failed                     | A hook command returned a non-zero exit status (error output shown)  |
| 6    | Configuration error                       | Invalid or malformed configuration file                               |
| 7    | Git command failed                        | A Git command returned a non-zero exit status (error output shown)   |

**Exit Code Behavior**:

- All non-zero exit codes indicate failure
- Error output from failed commands (hooks, Git, etc.) is always displayed
- Use exit codes for scripting and automation workflows

### 10.3 Example Configuration Files

**Minimal Global Configuration** (`~/.config/gwt/config.json`):

```json
{
  "version": "1.0",
  "hooks": {
    "timeout": 30
  }
}
```

**Full Per-Repository Configuration** (`.gwt.json` - committed to Git):

```json
{
  "version": "1.0",
  "copy": {
    "files": [
      ".env",
      "*.env.*"
    ],
    "directories": [
      "node_modules",
      ".cache"
    ]
  },
  "hooks": {
    "pre_add": [
      "echo 'Setting up worktree...'"
    ],
    "post_add": [
      "npm install",
      "npm run build"
    ],
    "pre_switch": [
      "echo 'Switching...'"
    ],
    "post_switch": [
      "npm run dev"
    ],
    "pre_clean": [
      "git stash"
    ],
    "post_clean": [
      "echo 'Cleaned up'"
    ]
  },
  "shell_integration": {
    "enable_eval_output": true
  }
}
```

**Per-Repository Local Configuration** (`.gwt.local.json` - gitignored):

```json
{
  "version": "1.0",
  "hooks": {
    "post_add_append": [
      "npm run typecheck"
    ]
  }
}
```

**Configuration with Per-Hook Timeout** (`.gwt.local.json`):

```json
{
  "version": "1.0",
  "hooks": {
    "post_add": {
      "timeout": 120,
      "commands": [
        "npm install",
        "npm run build"
      ]
    }
  }
}
```

### 10.4 Troubleshooting

**Issue**: Worktree creation fails with "branch not found"

- **Solution**: Use `-b` flag to create a new Git branch before creating the worktree (e.g., `gwm add -b feature/new-ui`), or ensure the branch exists locally

**Issue**: Automatic directory switching doesn't work

- **Solution**: Ensure shell wrapper is installed (see Section 3.5.2)

**Issue**: Files not copied to worktree

- **Solution**: Check `copy` configuration in `.gwt.json` and `.gwt.local.json` and verify file paths exist in main repository

**Issue**: Hook execution fails with timeout

- **Solution**: Increase hook timeout in global configuration or use per-hook timeout override for long-running commands

**Issue**: Hook execution fails with non-zero exit status

- **Solution**: GWM will display the error output from the failed command. Review the output to understand the failure, fix the issue, and retry. Example:
  ```
  gwm add feature/new-ui
  ✗ Hook 'post_add' failed: Command 'npm install' exited with status 1
  npm ERR! missing script: install
  ```

**Issue**: Git command fails

- **Solution**: GWM will display the full Git error output. Common issues:
  - Branch doesn't exist locally (use `-b` flag to create it)
  - Worktree already exists
  - Repository is in a corrupted state
  - Git is not properly installed or configured

**Issue**: Worktree left in partial state after hook failure

- **Solution**: Review the error message to understand which hook failed and why. Manually complete or fix the failed steps, then either:
  - Use the partial worktree as-is (if the failure was non-critical)
  - Run `gwm clean` from the partial worktree to remove it and retry
  - Manually run the remaining hook commands

**Issue**: Local settings not taking effect

- **Solution**: Ensure `.gwt.local.json` exists in the repository root and is not committed to Git (should be in `.gitignore`)

**Issue**: Hooks running in wrong order

- **Solution**: Check that you're using `_prepend` and `_append` suffixes correctly in `.gwt.local.json` to control hook execution order

**Issue**: Configuration format incompatible with current GWM version

- **Solution**: GWM will attempt to auto-migrate configurations. If migration fails, update the configuration manually according to the current version's schema or downgrade GWM to a compatible version

---

**Document Version**: 1.1
**Last Updated**: 2026-01-11
**Status**: Ready for Implementation
