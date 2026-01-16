# GWM - Git Worktree Manager

GWM (Git Worktree Manager) is a command-line tool that simplifies the management of Git worktrees, enabling parallel
development sessions on the same Git repository. It's designed for both manual worktree workflows and AI-assisted
development scenarios where multiple tool instances work in parallel on different features.

I created GWM to streamline my own development process, allowing me to easily switch between multiple worktrees for
different features and bug fixes without the hassle of managing Git commands manually. GWM automates directory
navigation,
file copying, and hook execution, making it a powerful tool for developers looking to enhance their productivity.

Note that because GWM modifies the shell environment for directory switching, GWM requires shell integration via wrapper
functions. Carefully follow the Shell Integration instructions below to set it up correctly.

<a href="https://www.buymeacoffee.com/software101" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me a Coffee" height="41" width="174"></a>

## Features

- 🌳 **Simplified Worktree Management**: Create, switch, and delete worktrees with intuitive commands
- 🚀 **Automatic Directory Navigation**: Seamlessly switch between worktrees and main repository
- 🔧 **Configurable Hooks**: Automate workflows with pre/post hooks for worktree operations
- 📁 **File/Directory Copying**: Copy local files and directories to all worktrees automatically
- 💻 **Cross-Platform Support**: Works on Windows, Linux, and macOS
- 🔍 **Interactive Selection**: Use fuzzy finder (fzf) or built-in selector for worktree navigation
- ⚙️ **Configuration System**: Global, per-repository, and local configurations with JSON/YAML support

## Installation

### Prerequisites

- 📦 Git 2.5+ (for worktree support)
- 🎯 Dart SDK (for building GWM)
- 🔍 Optional: [fzf](https://github.com/junegunn/fzf) for enhanced interactive selection

### Building the Executable

1. 🔽 Clone the repository:
   ```bash
   git clone https://github.com/timovandeput/gwm.git
   cd gwm
   ```

2. 🏗️ Build the executable:
   ```bash
   dart compile exe bin/gwm.dart -o gwm
   ```

3. ➡️ Move the executable to your PATH:
   ```bash
   # Linux/macOS
   chmod +x gwm
   sudo mv gwm /usr/local/bin/

   # Windows
   # Add gwm.exe to your PATH or move to a directory in PATH
   ```

## Shell Integration

For automatic directory switching and tab completion, add the following wrapper functions to your shell configuration.

> [!IMPORTANT]
> GWM detects when it's running inside a shell `eval` context using the `GWM_EVAL` environment variable. The shell
> wrapper functions set this variable before executing `eval`, which tells GWM to enable eval output for automatic
> directory switching. Without this detection, GWM defaults to not outputting eval commands.

### Bash 🐚

Add to `~/.bashrc`:

```bash
# Wrapper for automatic directory switching
gwm() { export GWM_EVAL=1; eval "$(command gwm "$@")"; }

# Tab completion - Option 1: Source in your shell profile
source /path/to/gwm/docs/completion/gwm.bash
```

Or Option 2: Install system-wide

```bash
sudo cp gwm.bash /usr/local/share/bash-completion/completions/gwm

# or for local user:
mkdir -p ~/.local/share/bash-completion/completions
cp gwm.bash ~/.local/share/bash-completion/completions/gwm
```

After adding the wrapper, reload your shell configuration:

```bash
# Bash
source ~/.bashrc
```

### Zsh 🦓

Add to `~/.zshrc`:

```bash
# Wrapper for automatic directory switching
gwm() { export GWM_EVAL=1; eval "$(command gwm "$@")" }

# Tab completion - Create completions directory if it doesn't exist
mkdir -p ~/.zsh/completions

# Copy the completion script
cp path/to/gwm/docs/completion/gwm.zsh ~/.zsh/completions/_gwm

# Add to your fpath
fpath=(~/.zsh/completions $fpath)

# Reload completions
autoload -Uz compinit && compinit
```

After adding the wrapper, reload your shell configuration:

```bash
# Bash
source ~/.zshrc
```

### Fish 🐠

Add to `~/.config/fish/config.fish`:

```fish
# Wrapper for automatic directory switching
function gwm
    set -x GWM_EVAL 1
    eval (command gwm $argv)
end

# Tab completion
cp /path/to/gwm/docs/completion/gwm.fish ~/.config/fish/completions/gwm.fish
```

After adding the wrapper, reload your shell configuration:

```fish
source ~/.config/fish/config.fish
```

### PowerShell 💻

Add to your PowerShell profile (`$PROFILE`):

```powershell
# Wrapper for automatic directory switching
function gwm { $env:GWM_EVAL = '1'; Invoke-Expression (& gwm $args) }
```

### Nushell 🦀

Add to `~/.config/nushell/config.nu`:

```nu
# Wrapper for automatic directory switching
def --env gwm [...args] {
    $env.GWM_EVAL = '1'
    ^gwm ...$args | lines | each { |line| nu -c $line }
}
```

## Quick Start

```bash
# Create a worktree with a new branch 🌳
gwm add -b feature/new-ui

# List all worktrees 📋
gwm list -v

# Switch to an existing worktree (interactive) 🔄
gwm switch

# Switch to a named worktree 🎯
gwm switch new-ui

# Switch to the main repo 🏠
gwm switch .

# Delete current worktree and return to main repo 🧹
gwm delete

# Delete the new-ui worktree from the main workspace 🗑️
gwm delete new-ui
```

## Usage

### gwm add ➕

Create a new worktree with automatic directory navigation.

```bash
# Create worktree from existing branch
gwm add feature/new-ui

# Create worktree with new branch
gwm add -b feature/authentication

# Create worktree with new branch (long form)
gwm add --branch feature/authentication
```

**Options:**

- `-b, --branch`: Create a new Git branch instead of using an existing one
- `-h, --help`: Show help message

### gwm switch 🔄

Navigate to an existing worktree or main repository.

```bash
# Switch to specific worktree
gwm switch feature-auth

# Switch to main Git workspace
gwm switch .
```

**Options:**

- `-r, --reconfigure`: Re-apply the "add" hooks and file copies
- `-h, --help`: Show help message

### gwm delete 🧹

Delete the specified worktree, or the current worktree if no name is provided.

Can only delete worktrees from the main workspace. Cannot delete the main workspace.

```bash
# Delete current worktree (prompts if uncommitted changes exist)
gwm delete

# Delete named worktree from main workspace
gwm delete feature-branch

# Force delete (no prompts)
gwm delete --force
gwm delete feature-branch --force
```

**Options:**

- `-f, --force`: Bypass safety checks and delete immediately
- `-h, --help`: Show help message

### gwm list 📋

Display all available worktrees for current repository.

```bash
# Simple list
gwm list

# Detailed list
gwm list -v

# JSON output for scripting
gwm list -j
```

**Options:**

- `-v, --verbose`: Show additional information (branch status, last modified)
- `-j, --json`: Output in JSON format for scripting
- `-h, --help`: Show help message

## Configuration

GWM supports configuration at three levels:

### Global Configuration 🌍

Location: `~/.config/gwm/config.json` (or `.yaml`)

Applies to all repositories and contains default settings.

```json
{
  "version": "1.0",
  "hooks": {
    "timeout": 30
  }
}
```

- "version" specifies the configuration schema version
- "timeout" sets hook execution timeout in seconds

### Per-Repository Configuration 📁

Location: `.gwm.json` (or `.yaml`) in repository root

Repository-specific settings that can be committed to Git and shared with the team.

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
    "post_add": [
      "npm install",
      "npm run build"
    ],
    "post_switch": [
      "npm run dev"
    ],
    "pre_delete": [
      "git stash"
    ]
  },
  "shell_integration": {
    "enable_eval_output": true
  }
}
```

### Per-Repository Local Configuration 🔒

Location: `.gwm.local.json` (or `.yaml`) in repository root

Local-only overrides that should be added to `.gitignore`.

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
    "post_add_append": [
      "npm run typecheck"
    ]
  }
}
```

**Override Strategies:**

- 🔄 **Complete Override**: Use the field name directly (e.g., `post_add = [...]`)
- ⬆️ **Prepend Items**: Use `_prepend` suffix (e.g., `post_add_prepend = [...]`)
- ⬇️ **Append Items**: Use `_append` suffix (e.g., `post_add_append = [...]`)

## Configuration Schema

### copy 📁

Files and directories to copy from the main repository to each worktree.

```json
{
  "copy": {
    "files": [
      ".env",
      "*.env.*",
      "config/*.json"
    ],
    "directories": [
      "node_modules",
      ".cache"
    ]
  }
}
```

- Supports glob patterns for flexible file matching
- Large directories may take time to copy
- Copy-on-Write optimization on supported filesystems (APFS, Btrfs, XFS)

### hooks 🔧

Hooks are shell commands that run at specific points during worktree operations.

| Hook          | When Executed                          | Environment Variables                  |
|---------------|----------------------------------------|----------------------------------------|
| `pre_add`     | Before creating worktree               | `GWM_WORKTREE_PATH`, `GWM_ORIGIN_PATH` |
| `post_add`    | After creating worktree                | `GWM_WORKTREE_PATH`, `GWM_ORIGIN_PATH` |
| `pre_switch`  | Before switching worktree              | `GWM_WORKTREE_PATH`, `GWM_ORIGIN_PATH` |
| `post_switch` | After switching worktree               | `GWM_WORKTREE_PATH`, `GWM_ORIGIN_PATH` |
| `pre_delete`  | Before deleting worktree               | `GWM_WORKTREE_PATH`, `GWM_ORIGIN_PATH` |
| `post_delete` | After deleting worktree (in main repo) | `GWM_ORIGIN_PATH`                      |

```json
{
  "hooks": {
    "timeout": 30,
    "pre_add": [
      "echo 'Creating worktree...'"
    ],
    "post_add": [
      "npm install",
      "npm run build"
    ]
  }
}
```

**Per-Hook Timeout:**

```json
{
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

## Directory Structure 📂

GWM creates worktrees in a shared directory structure:

```
~/work/
├── project/               # Main Git repository
│   ├── .gwm.json          # Repository-specific configuration
│   ├── .gwm.local.json    # Local-only configuration (gitignored)
│   └── ...                # Repository files
└── worktrees/             # Shared worktree directory
    ├── project_feature-auth/
    ├── project_bugfix-login/
    └── project_api-v2/
```

**Key Points:**

- The `worktrees` directory is in the parent directory of the Git workspace
- Multiple Git repositories share the same `worktrees` directory
- Worktree names: `<repo-name>_<branch-name>`
- Worktrees are never created inside Git workspace directories

## Workflows

### Basic Workflow ⚡

```bash
# Create worktree with new branch 🌳
gwm add -b feature/new-ui

# Work on feature...
# Directory is already switched by gwm add

# Clean up when done 🧹
gwm delete 
```

### Multi-Feature Workflow 🔀

```bash
# Create multiple worktrees 🌳
gwm add feature/auth
gwm add feature/api
gwm add bugfix/login

# Switch between worktrees 🔄
gwm switch feature-auth

# Switch back to main workspace 🏠
gwm switch .

# List all worktrees 📋
gwm list -v
```

### AI-Assisted Development 🤖

```bash
# Terminal 1: Work on authentication 🤖
gwm add feature/auth

# Terminal 2: Work on API 🤖
gwm switch feature-api

# Terminal 3: Work on bugfix 🤖
gwm switch bugfix-login

# Terminal 4: Monitor from main workspace 👁
gwm switch .
gwm list -v
```

## Exit Codes 📊

| Code | Meaning                                             |
|------|-----------------------------------------------------|
| 0    | ✅ Success                                           |
| 1    | ❌ General error                                     |
| 2    | ❌ Invalid usage (wrong arguments)                   |
| 3    | ❌ Worktree already exists                           |
| 4    | ❌ Branch not found                                  |
| 5    | ❌ Hook execution failed                             |
| 6    | ❌ Configuration error                               |
| 7    | ❌ Git command failed                                |
| 8    | ❌ Shell wrapper missing or not configured           |
| 9    | ❌ Worktree already exists but successfully switched |

## Development

### Build Commands 🏗️

```bash
# Run application
dart run bin/gwm.dart

# Build executable
dart compile exe bin/gwm.dart -o gwm
```

### Lint Commands 🔍

```bash
# Run static analysis
dart analyze

# Format code
dart format .

# Format with changes check
dart format --set-exit-if-changed .
```

### Test Commands 🧪

```bash
# Run all tests
dart test

# Run specific test file
dart test test/file_test.dart

# Run single test by name
dart test -n "test name"

# Run tests with coverage
dart test --coverage=coverage
```

### Development Workflow 💻

1. ✏️ Make changes to code
2. 🎨 Format: `dart format .`
3. 🔍 Lint: `dart analyze`
4. 🧪 Test: `dart test`
5. ▶️ Run: `dart run bin/gwm.dart --help` to verify functionality

## Troubleshooting 🔧

### Worktree creation fails with "branch not found" ❌

Use `-b` flag to create a new Git branch before creating the worktree:

```bash
gwm add -b feature/new-ui
```

### Automatic directory switching doesn't work ⚠️

Ensure shell wrapper is installed (see Shell Integration section above).

### Files not copied to worktree 📁

Check `copy` configuration in `.gwm.json` and `.gwm.local.json` and verify file paths exist in main repository.

### Hook execution fails ❌

GWM will display the error output from the failed command. Review the output to understand the failure, fix the issue,
and retry.

## Contributing 🤝

Contributions are welcome! Please see [AGENTS.md](AGENTS.md) for development guidelines and coding standards.

## License 📄

[Specify your license here]

## Links 🔗

- [📋 PRD](PRD.md) - Product Requirements Document
- [👨‍💻 AGENTS.md](AGENTS.md) - Development Guidelines
- [🔗 GitHub Repository](https://github.com/yourusername/gwm)
